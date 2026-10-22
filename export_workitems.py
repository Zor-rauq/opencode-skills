#!/usr/bin/env python3
"""Export CSV des work items GitLab (GitLab 19.4, API GraphQL).

Exporte les work items d'un groupe (sous-groupes et projets inclus),
ou d'un seul projet de ce groupe avec --projet-id.

    export GITLAB_URL=https://gitlab.example.com
    export GITLAB_TOKEN=glpat-xxxx              # scope read_api suffisant
    ./export_workitems.py --group-id 42 [--projet-id 1337] [--output wi.csv] [--delimiter ';']

Bibliothèque standard uniquement (Python >= 3.8).
Certificat signé par une autorité interne : SSL_CERT_FILE=/chemin/ca.pem ./export_workitems.py ...
"""
import argparse
import contextlib
import csv
import getpass
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

PAGE_SIZE = 50  # work items par requête (max GitLab : 100)
SEP = ", "      # séparateur des valeurs multiples dans une cellule

COLUMNS = ["id", "iid", "reference", "type", "titre", "description", "labels", "status",
           "iteration", "milestone", "parent", "related_to", "blocks", "is_blocked_by", "children"]

QUERY = """
query($path: ID!, $after: String) {
  ns: %(scope)s(fullPath: $path) {
    workItems(first: %(page)d, after: $after%(extra)s) {
      pageInfo { hasNextPage endCursor }
      nodes {
        id iid title description state reference(full: true)
        workItemType { name }
        widgets(onlyTypes: [LABELS, STATUS, ITERATION, MILESTONE, HIERARCHY, LINKED_ITEMS]) {
          ... on WorkItemWidgetLabels { labels(first: 100) { pageInfo { hasNextPage } nodes { title } } }
          ... on WorkItemWidgetStatus { status { name } }
          ... on WorkItemWidgetIteration { iteration { title startDate dueDate iterationCadence { title } } }
          ... on WorkItemWidgetMilestone { milestone { title } }
          ... on WorkItemWidgetHierarchy {
            parent { reference(full: true) }
            children(first: 100) { pageInfo { hasNextPage } nodes { reference(full: true) } }
          }
          ... on WorkItemWidgetLinkedItems {
            linkedItems(first: 100) {
              pageInfo { hasNextPage }
              nodes { linkType workItem { reference(full: true) } }
            }
          }
        }
      }
    }
  }
}
"""


class GitLab:
    def __init__(self, url, token):
        self.base = url.rstrip("/")
        if self.base.endswith("/api/v4"):
            self.base = self.base[: -len("/api/v4")]
        self.headers = {"Authorization": "Bearer " + token, "Content-Type": "application/json"}

    def _call(self, path, payload=None):
        data = None if payload is None else json.dumps(payload).encode()
        req = urllib.request.Request(self.base + path, data=data, headers=self.headers)
        try:
            with urllib.request.urlopen(req, timeout=120) as resp:
                body = resp.read()
        except urllib.error.HTTPError as e:
            sys.exit(f"Erreur HTTP {e.code} sur {path} : {e.read().decode(errors='replace')[:300]}")
        except OSError as e:  # connexion, DNS, TLS, timeout
            sys.exit(f"Erreur : impossible de joindre {self.base} ({getattr(e, 'reason', e)})")
        try:
            return json.loads(body)
        except ValueError:
            sys.exit(f"Erreur : réponse non JSON sur {path} (GITLAB_URL correcte ?)")

    def rest(self, path):
        return self._call("/api/v4" + path)

    def graphql(self, query, variables):
        res = self._call("/api/graphql", {"query": query, "variables": variables})
        if res.get("errors"):
            sys.exit("Erreur GraphQL : " + " | ".join(e.get("message", str(e)) for e in res["errors"]))
        return res["data"]


def fetch_work_items(gl, scope, path):
    """Récupère tous les work items du groupe ou du projet (pagination par curseur)."""
    extra = ", includeDescendants: true" if scope == "group" else ""  # sous-groupes + projets
    query = QUERY % {"scope": scope, "page": PAGE_SIZE, "extra": extra}
    items, after = [], None
    while True:
        ns = gl.graphql(query, {"path": path, "after": after})["ns"]
        if ns is None:
            sys.exit(f"\nErreur : {path} introuvable ou inaccessible avec ce token.")
        page = ns["workItems"]
        items += page["nodes"]
        print(f"\r{len(items)} work items récupérés", end="", file=sys.stderr, flush=True)
        if not page["pageInfo"]["hasNextPage"]:
            print(file=sys.stderr)
            return items
        after = page["pageInfo"]["endCursor"]


def to_row(wi):
    """Aplatit un work item GraphQL en ligne CSV."""
    w = {k: v for widget in wi["widgets"] or [] for k, v in widget.items()}  # fusion des widgets
    ref = wi["reference"]

    def nodes(key, what):
        conn = w.get(key) or {}
        if (conn.get("pageInfo") or {}).get("hasNextPage"):
            print(f"Attention : {ref} a plus de 100 {what}, liste tronquée.", file=sys.stderr)
        return [n for n in conn.get("nodes") or [] if n]

    links = nodes("linkedItems", "liens")

    def linked(kind):  # relates_to | blocks | is_blocked_by
        return SEP.join(lk["workItem"]["reference"] for lk in links if lk["linkType"] == kind and lk["workItem"])

    it = w.get("iteration")
    iteration = ""
    if it:  # les itérations auto-planifiées n'ont pas de titre : on affiche alors les dates
        label = it["title"] or f"{(it['startDate'] or '')[:10]} → {(it['dueDate'] or '')[:10]}"
        iteration = f"{it['iterationCadence']['title']} : {label}"

    return {
        "id": wi["id"].rsplit("/", 1)[-1],  # gid://gitlab/WorkItem/123 -> 123
        "iid": wi["iid"],
        "reference": ref,
        "type": wi["workItemType"]["name"],
        "titre": wi["title"],
        "description": wi["description"] or "",
        "labels": SEP.join(lb["title"] for lb in nodes("labels", "labels")),
        # Status (widget) ; à défaut (type sans statut), l'état OPEN/CLOSED
        "status": (w.get("status") or {}).get("name") or wi["state"],
        "iteration": iteration,
        "milestone": (w.get("milestone") or {}).get("title", ""),
        "parent": (w.get("parent") or {}).get("reference", ""),
        "related_to": linked("relates_to"),
        "blocks": linked("blocks"),
        "is_blocked_by": linked("is_blocked_by"),
        "children": SEP.join(c["reference"] for c in nodes("children", "enfants")),
    }


def main():
    p = argparse.ArgumentParser(description="Exporte en CSV les work items GitLab d'un groupe (ou d'un de ses projets).")
    p.add_argument("--url", default=os.environ.get("GITLAB_URL"),
                   help="URL de l'instance GitLab (défaut : $GITLAB_URL)")
    p.add_argument("--token", default=os.environ.get("GITLAB_TOKEN"),
                   help="token d'accès, scope read_api (défaut : $GITLAB_TOKEN, sinon demandé)")
    p.add_argument("--group-id", required=True, help="ID (ou chemin complet) du groupe")
    p.add_argument("--projet-id", "--project-id", dest="project_id",
                   help="ID (ou chemin complet) d'un projet du groupe, pour restreindre l'export")
    p.add_argument("--output", "-o", default="workitems.csv",
                   help="fichier CSV de sortie, '-' pour stdout (défaut : workitems.csv)")
    p.add_argument("--delimiter", "-d", default=",", help="séparateur CSV, ex. ';' ou '\\t' (défaut : ',')")
    args = p.parse_args()

    if not args.url:
        sys.exit("Erreur : GITLAB_URL n'est pas configurée (export GITLAB_URL=https://... ou --url).")
    token = args.token
    if not token and sys.stdin.isatty():
        token = getpass.getpass("GITLAB_TOKEN non configuré. Token GitLab : ").strip()
    if not token:
        sys.exit("Erreur : GITLAB_TOKEN n'est pas configuré (export GITLAB_TOKEN=... ou --token).")
    delimiter = "\t" if args.delimiter in ("\\t", "tab") else args.delimiter
    if len(delimiter) != 1:
        sys.exit("Erreur : --delimiter doit être un seul caractère.")

    gl = GitLab(args.url, token)
    group = gl.rest(f"/groups/{urllib.parse.quote(args.group_id, safe='')}?with_projects=false")
    scope, path = "group", group["full_path"]
    if args.project_id:
        project = gl.rest(f"/projects/{urllib.parse.quote(args.project_id, safe='')}")
        scope, path = "project", project["path_with_namespace"]
        if not path.lower().startswith(group["full_path"].lower() + "/"):
            sys.exit(f"Erreur : le projet {path} n'appartient pas au groupe {group['full_path']}.")

    rows = [to_row(wi) for wi in fetch_work_items(gl, scope, path)]

    if args.output == "-":
        out = contextlib.nullcontext(sys.stdout)
    else:  # BOM UTF-8 pour qu'Excel affiche correctement les accents
        out = open(args.output, "w", newline="", encoding="utf-8-sig")
    with out as f:
        writer = csv.DictWriter(f, fieldnames=COLUMNS, delimiter=delimiter, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(rows)
    print(f"{len(rows)} work items exportés vers {args.output}", file=sys.stderr)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        sys.exit("\nInterrompu.")
