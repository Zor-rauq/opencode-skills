#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
gitlab_export_pi.py - Export CSV des work items GitLab, sans service mail.

Une execution :
  1. lit TOUS les work items du groupe racine (epics, stories, enablers, spikes,
     taches, objectifs PI, risques...) par l'API GraphQL, en s'adaptant au
     schema de l'instance (introspection) ;
  2. reconstruit la hierarchie (Fonction de service > Feature > story) et
     calcule l'avancement, le WSJF, les dependances et la predictibilite ;
  3. ecrit un CSV complet, des CSV de synthese, un CSV par vue de vues.json et,
     en option, un CSV par bloc GLQL d'un fichier Markdown ;
  4. ecrit MANIFEST.txt et SHA256SUMS (comptes et empreintes) pour le sas.

Aucune dependance : Python 3.6 ou plus, bibliotheque standard uniquement.

Variables d'environnement :
  GITLAB_URL     URL de l'instance (a defaut : CI_SERVER_URL en pipeline)
  GITLAB_TOKEN   jeton avec le scope read_api (nom modifiable : --token-env)
  GROUPE_RACINE  chemin du groupe racine (a defaut de --groupe)

Exemple :
  GITLAB_URL=https://gitlab.enclave.local GITLAB_TOKEN=... \\
  python3 gitlab_export_pi.py --groupe ldp --config vues.json \\
          --glql vues_glql.md --sortie export
"""

from __future__ import print_function

import argparse
import collections
import csv
import datetime
import hashlib
import io
import json
import os
import re
import ssl
import sys
import time
import unicodedata

try:  # Python 3
    import urllib.request as urlrequest
    import urllib.error as urlerror
except ImportError:  # pragma: no cover
    sys.stderr.write("Python 3.6 ou plus est requis.\n")
    sys.exit(1)

VERSION = "1.0.0"

# --------------------------------------------------------------------------
# Catalogue des colonnes (cle -> intitule CSV)
# --------------------------------------------------------------------------

COLONNES = [
    ("ref", "Référence"),
    ("id", "ID"),
    ("niveau", "Niveau SAFe"),
    ("type", "Type"),
    ("titre", "Titre"),
    ("etat", "État"),
    ("statut", "Statut"),
    ("fs_ref", "Réf. FS"),
    ("fs", "Fonction de service"),
    ("feature_ref", "Réf. Feature"),
    ("feature", "Feature"),
    ("parent", "Parent"),
    ("chemin", "Chemin"),
    ("espace", "Groupe / projet"),
    ("jalon", "Jalon (PI)"),
    ("iteration", "Itération"),
    ("iteration_debut", "Début itération"),
    ("iteration_fin", "Fin itération"),
    ("cadence", "Cadence"),
    ("poids", "Poids"),
    ("sante", "Santé"),
    ("date_debut", "Début"),
    ("date_echeance", "Échéance"),
    ("assignes", "Assignés"),
    ("labels", "Labels"),
    ("bloque", "Bloqué"),
    ("bloque_par", "Bloqué par"),
    ("bloque_quoi", "Bloque"),
    ("lie_a", "Lié à"),
    ("desc_total", "Éléments"),
    ("desc_termines", "Éléments terminés"),
    ("desc_poids_total", "Points"),
    ("desc_poids_termines", "Points terminés"),
    ("desc_sans_poids", "Éléments sans poids"),
    ("avancement_pct", "Avancement %"),
    ("wsjf", "WSJF"),
    ("cree_le", "Créé le"),
    ("maj_le", "Mis à jour le"),
    ("ferme_le", "Fermé le"),
    ("url", "URL"),
    ("description", "Description"),
]
LIBELLES = dict(COLONNES)

COLONNES_VUE_PAR_DEFAUT = [
    "ref", "niveau", "titre", "etat", "statut", "fs", "feature",
    "jalon", "iteration", "poids", "avancement_pct", "espace",
]

CONFIG_PAR_DEFAUT = {
    "classification": [
        {"label": "niveau::fonction-service", "niveau": "Fonction de service"},
        {"label": "niveau::feature", "niveau": "Feature"},
        {"type": "Epic", "niveau": "Épic non classé"},
        {"type": "User Story", "niveau": "User Story"},
        {"type": "Enabler", "niveau": "Enabler"},
        {"type": "Spike", "niveau": "Spike"},
        {"type": "Task", "niveau": "Tâche"},
        {"type": "Objectif PI", "niveau": "Objectif PI"},
        {"type": "Risque", "niveau": "Risque"},
    ],
    "niveau_fs": "Fonction de service",
    "niveau_feature": "Feature",
    "rollup_niveaux": ["User Story", "Enabler", "Spike"],
    "statuts_annules": ["Abandonné", "Abandonnée", "Doublon",
                        "Won't do", "Duplicate"],
    "wsjf": {
        "valeur_metier": "Valeur métier",
        "criticite_temporelle": "Criticité temporelle",
        "reduction_risque": "Réduction risque / opportunité",
        "taille": "Taille",
    },
    "objectifs": {
        "niveau": "Objectif PI",
        "vm_planifiee": "VM planifiée",
        "vm_realisee": "VM réalisée",
        "engagement": "Engagement",
        "valeur_engage": "Engagé",
    },
    "vues": [],
}

CLES_FILTRE = {
    "niveau", "type", "etat", "statut", "jalon", "iteration", "cadence",
    "labels_tous", "labels_un_de", "labels_aucun", "espace_commence_par",
    "descendants_de", "champs", "bloque", "texte",
}

SANTE = {
    "onTrack": "En bonne voie",
    "needsAttention": "Attention requise",
    "atRisk": "À risque",
    "ON_TRACK": "En bonne voie",
    "NEEDS_ATTENTION": "Attention requise",
    "AT_RISK": "À risque",
}

# Types interroges a l'introspection (alias GraphQL -> nom de type)
TYPES_SONDES = [
    ("t_wi", "WorkItem"),
    ("t_grp", "Group"),
    ("t_hier", "WorkItemWidgetHierarchy"),
    ("t_lbl", "WorkItemWidgetLabels"),
    ("t_asg", "WorkItemWidgetAssignees"),
    ("t_desc", "WorkItemWidgetDescription"),
    ("t_msw", "WorkItemWidgetMilestone"),
    ("t_ms", "Milestone"),
    ("t_itw", "WorkItemWidgetIteration"),
    ("t_it", "Iteration"),
    ("t_wt", "WorkItemWidgetWeight"),
    ("t_hs", "WorkItemWidgetHealthStatus"),
    ("t_dt", "WorkItemWidgetStartAndDueDate"),
    ("t_st", "WorkItemWidgetStatus"),
    ("t_sto", "WorkItemStatus"),
    ("t_cf", "WorkItemWidgetCustomFields"),
    ("t_cfsel", "WorkItemSelectFieldValue"),
    ("t_cfnum", "WorkItemNumberFieldValue"),
    ("t_cftxt", "WorkItemTextFieldValue"),
    ("t_lnk", "WorkItemWidgetLinkedItems"),
]

# Arguments de Group.workItems utilises s'ils existent dans le schema
ARGS_OPTIONNELS = [
    ("includeDescendants", "true"),   # sous-groupes et projets
    ("excludeProjects", "false"),     # garder les elements des projets
    ("state", "all"),                 # ouverts et fermes
]

RE_COMPLEXITE = re.compile(
    r"complexity of (\d+)\D+max(?:imum)? complexity of (\d+)", re.I)
RE_NOMBRE = re.compile(r"^-?\d+(?:[.,]\d+)?$")
DEBUT_FORMULE = ("=", "+", "-", "@", "\t", "\r")

# --------------------------------------------------------------------------
# Outils
# --------------------------------------------------------------------------

AVERTISSEMENTS = []


def journal(message):
    horodatage = datetime.datetime.now().strftime("%H:%M:%S")
    sys.stderr.write("[%s] %s\n" % (horodatage, message))
    sys.stderr.flush()


def avertir(message):
    AVERTISSEMENTS.append(message)
    journal("ATTENTION : " + message)


def arreter(message, code=1):
    journal("ERREUR : " + message)
    sys.exit(code)


def cle_naturelle(texte):
    """Tri naturel : 'S2' < 'S10', '#9' < '#12'."""
    morceaux = re.split(r"(\d+)", texte or "")
    return [(0, int(m), "") if m.isdigit() else (1, 0, m.lower())
            for m in morceaux if m != ""]


def date_seule(valeur):
    if not valeur:
        return ""
    return str(valeur)[:10]


def date_heure(valeur):
    """'2026-10-14T08:05:12Z' -> '2026-10-14 08:05' (UTC)."""
    if not valeur:
        return ""
    texte = str(valeur)
    if len(texte) >= 16 and texte[10] == "T":
        return texte[:10] + " " + texte[11:16]
    return texte


def en_nombre(valeur):
    if valeur is None:
        return None
    if isinstance(valeur, (int, float)) and not isinstance(valeur, bool):
        return valeur
    texte = str(valeur).strip().replace(",", ".")
    if not texte:
        return None
    try:
        nombre = float(texte)
    except ValueError:
        return None
    return int(nombre) if nombre.is_integer() else nombre


def noeuds(valeur):
    """Accepte une liste, une connexion {nodes: [...]} ou None."""
    if valeur is None:
        return []
    if isinstance(valeur, dict):
        return valeur.get("nodes") or []
    if isinstance(valeur, list):
        return valeur
    return []


def nom_fichier(texte):
    """Nom de fichier ASCII (sans accents) pour passer tout sas ou archive."""
    texte = unicodedata.normalize("NFKD", texte or "")
    texte = "".join(c for c in texte if not unicodedata.combining(c))
    texte = re.sub(r"[^A-Za-z0-9\-]+", "_", texte).strip("_")
    return (texte or "sans_nom")[:80]


# --------------------------------------------------------------------------
# Client HTTP (GraphQL + REST)
# --------------------------------------------------------------------------

class ErreurGraphQL(Exception):
    pass


class ErreurHTTP(Exception):
    def __init__(self, code, message):
        Exception.__init__(self, message)
        self.code = code


class Client(object):
    def __init__(self, url, jeton, ca=None, insecure=False, sans_proxy=False,
                 timeout=60, debug=False):
        self.url = url.rstrip("/")
        self.jeton = jeton
        self.timeout = timeout
        self.debug = debug
        if self.url.startswith("https://"):
            if insecure:
                contexte = ssl._create_unverified_context()
            else:
                contexte = ssl.create_default_context(cafile=ca) if ca \
                    else ssl.create_default_context()
            gestionnaires = [urlrequest.HTTPSHandler(context=contexte)]
        else:
            gestionnaires = []
        if sans_proxy:
            gestionnaires.append(urlrequest.ProxyHandler({}))
        self.ouvreur = urlrequest.build_opener(*gestionnaires)

    def _requete(self, methode, chemin, corps=None, entetes=None):
        url = self.url + chemin
        donnees = None
        if corps is not None:
            donnees = json.dumps(corps).encode("utf-8")
        attente = 2
        for essai in range(1, 5):
            requete = urlrequest.Request(url, data=donnees, method=methode)
            requete.add_header("Accept", "application/json")
            requete.add_header("User-Agent", "gitlab-export-pi/" + VERSION)
            if donnees is not None:
                requete.add_header("Content-Type", "application/json")
            for nom, valeur in (entetes or {}).items():
                requete.add_header(nom, valeur)
            try:
                reponse = self.ouvreur.open(requete, timeout=self.timeout)
                brut = reponse.read().decode("utf-8")
                return json.loads(brut) if brut else {}
            except urlerror.HTTPError as erreur:
                code = erreur.code
                try:
                    detail = erreur.read().decode("utf-8", "replace")[:500]
                except Exception:
                    detail = ""
                if code in (401, 403):
                    raise ErreurHTTP(code, "accès refusé (%s) sur %s : vérifier le "
                                     "jeton et son scope read_api. %s"
                                     % (code, chemin, detail))
                if code in (429, 500, 502, 503, 504) and essai < 4:
                    pause = attente
                    reessai = erreur.headers.get("Retry-After") \
                        if erreur.headers else None
                    if reessai and reessai.isdigit():
                        pause = max(pause, int(reessai))
                    journal("HTTP %s sur %s, nouvel essai dans %ss"
                            % (code, chemin, pause))
                    time.sleep(pause)
                    attente *= 2
                    continue
                raise ErreurHTTP(code, "HTTP %s sur %s : %s"
                                 % (code, chemin, detail))
            except (urlerror.URLError, OSError) as erreur:
                if essai < 4:
                    journal("connexion impossible (%s), nouvel essai dans %ss"
                            % (getattr(erreur, "reason", erreur), attente))
                    time.sleep(attente)
                    attente *= 2
                    continue
                raise ErreurHTTP(0, "connexion impossible à %s : %s"
                                 % (url, getattr(erreur, "reason", erreur)))
        raise ErreurHTTP(0, "échec de la requête %s" % chemin)

    def graphql(self, requete, variables=None):
        if self.debug:
            journal("GraphQL >>> " + re.sub(r"\s+", " ", requete)[:2000])
        reponse = self._requete(
            "POST", "/api/graphql",
            {"query": requete, "variables": variables or {}},
            {"Authorization": "Bearer " + self.jeton})
        erreurs = reponse.get("errors") or []
        donnees = reponse.get("data")
        if erreurs and not donnees:
            raise ErreurGraphQL(" | ".join(
                e.get("message", str(e)) for e in erreurs))
        if erreurs:
            for e in erreurs:
                avertir("GraphQL (partiel) : %s" % e.get("message", e))
        return donnees or {}

    def rest_get(self, chemin):
        return self._requete("GET", "/api/v4" + chemin, None,
                             {"PRIVATE-TOKEN": self.jeton})

    def rest_post(self, chemin, corps):
        return self._requete("POST", "/api/v4" + chemin, corps,
                             {"PRIVATE-TOKEN": self.jeton})


# --------------------------------------------------------------------------
# Introspection : ce que l'instance sait faire
# --------------------------------------------------------------------------

class Schema(object):
    def __init__(self, brut):
        self.champs = {}     # type -> {champ: (nom_type_deroule, est_liste)}
        self.args = {}       # (type, champ) -> set(args)
        for nom_type, description in brut.items():
            if not description:
                continue
            champs = {}
            for champ in description.get("fields") or []:
                nom_def, liste = self._derouler(champ.get("type"))
                champs[champ["name"]] = (nom_def, liste)
                self.args[(nom_type, champ["name"])] = set(
                    a["name"] for a in champ.get("args") or [])
            self.champs[nom_type] = champs

    @staticmethod
    def _derouler(t):
        liste = False
        while t and t.get("kind") in ("NON_NULL", "LIST"):
            if t.get("kind") == "LIST":
                liste = True
            t = t.get("ofType")
        return (t or {}).get("name"), liste

    def existe(self, nom_type):
        return nom_type in self.champs

    def a(self, nom_type, champ):
        return champ in self.champs.get(nom_type, {})

    def est_connexion(self, nom_type, champ):
        nom_def, liste = self.champs.get(nom_type, {}).get(champ, (None, False))
        return bool(nom_def) and nom_def.endswith("Connection") and not liste

    def arguments(self, nom_type, champ):
        return self.args.get((nom_type, champ), set())


def sonder_schema(client):
    morceau = ("{ name fields(includeDeprecated: true) { name args { name } "
               "type { kind name ofType { kind name ofType { kind name ofType "
               "{ kind name } } } } } }")
    requete = "query { " + " ".join(
        '%s: __type(name: "%s") %s' % (alias, nom, morceau)
        for alias, nom in TYPES_SONDES) + " }"
    donnees = client.graphql(requete)
    brut = {}
    for alias, nom in TYPES_SONDES:
        brut[nom] = donnees.get(alias)
    schema = Schema(brut)
    absents = [nom for _, nom in TYPES_SONDES if not schema.existe(nom)]
    if not schema.existe("WorkItem") or not schema.existe("Group"):
        arreter("le schéma GraphQL ne présente pas WorkItem/Group : "
                "instance trop ancienne ou introspection refusée.", 2)
    if not schema.a("Group", "workItems"):
        arreter("le champ Group.workItems est absent : GitLab 17 ou plus "
                "est nécessaire.", 2)
    if absents:
        journal("types absents de cette instance (colonnes vides) : "
                + ", ".join(absents))
    return schema


# --------------------------------------------------------------------------
# Construction de la requete work items
# --------------------------------------------------------------------------

def selection(schema, nom_type, champ, contenu, arguments=""):
    """'champ { contenu }' ou 'champ { nodes { contenu } }' selon le schema."""
    if schema.est_connexion(nom_type, champ):
        return "%s%s { nodes { %s } }" % (champ, arguments, contenu)
    return "%s { %s }" % (champ, contenu)


def construire_requete(schema, avec_liens, avec_description, args_exclus=()):
    s = schema
    wi = "WorkItem"
    champs = [c for c in ("id", "iid", "title", "state", "confidential",
                          "createdAt", "updatedAt", "closedAt", "webUrl")
              if s.a(wi, c)]
    reference = "reference(full: true)" \
        if "full" in s.arguments(wi, "reference") else "reference"
    if s.a(wi, "reference"):
        champs.append(reference)
    if s.a(wi, "namespace"):
        champs.append("namespace { fullPath }")
    if s.a(wi, "workItemType"):
        champs.append("workItemType { id name }")

    w = ["__typename"]
    if s.a("WorkItemWidgetHierarchy", "parent"):
        parent = ["id", "iid", "title"]
        if s.a(wi, "reference"):
            parent.append(reference)
        if s.a(wi, "workItemType"):
            parent.append("workItemType { name }")
        w.append("... on WorkItemWidgetHierarchy { parent { %s } }"
                 % " ".join(parent))
    if s.a("WorkItemWidgetLabels", "labels"):
        w.append("... on WorkItemWidgetLabels { %s }" % selection(
            s, "WorkItemWidgetLabels", "labels", "title", "(first: 100)"))
    if s.a("WorkItemWidgetAssignees", "assignees"):
        w.append("... on WorkItemWidgetAssignees { %s }" % selection(
            s, "WorkItemWidgetAssignees", "assignees", "username name",
            "(first: 50)"))
    if avec_description and s.a("WorkItemWidgetDescription", "description"):
        w.append("... on WorkItemWidgetDescription { description }")
    if s.a("WorkItemWidgetMilestone", "milestone"):
        ms = [c for c in ("title", "startDate", "dueDate")
              if s.a("Milestone", c)] or ["title"]
        w.append("... on WorkItemWidgetMilestone { milestone { %s } }"
                 % " ".join(ms))
    if s.a("WorkItemWidgetIteration", "iteration"):
        it = [c for c in ("title", "startDate", "dueDate")
              if s.a("Iteration", c)] or ["id"]
        if s.a("Iteration", "iterationCadence"):
            it.append("iterationCadence { title }")
        w.append("... on WorkItemWidgetIteration { iteration { %s } }"
                 % " ".join(it))
    if s.a("WorkItemWidgetWeight", "weight"):
        w.append("... on WorkItemWidgetWeight { weight }")
    if s.a("WorkItemWidgetHealthStatus", "healthStatus"):
        w.append("... on WorkItemWidgetHealthStatus { healthStatus }")
    if s.existe("WorkItemWidgetStartAndDueDate"):
        dt = [c for c in ("startDate", "dueDate")
              if s.a("WorkItemWidgetStartAndDueDate", c)]
        if dt:
            w.append("... on WorkItemWidgetStartAndDueDate { %s }"
                     % " ".join(dt))
    if s.a("WorkItemWidgetStatus", "status"):
        st = ["name"]
        if s.a("WorkItemStatus", "category"):
            st.append("category")
        w.append("... on WorkItemWidgetStatus { status { %s } }"
                 % " ".join(st))
    if s.a("WorkItemWidgetCustomFields", "customFieldValues"):
        # Alias obligatoires : 'value' est Float pour un nombre et String
        # pour un texte ; GraphQL refuse deux types sous le meme nom.
        valeurs = ["customField { name }"]
        if s.a("WorkItemSelectFieldValue", "selectedOptions"):
            valeurs.append("... on WorkItemSelectFieldValue "
                           "{ selectedOptions { value } }")
        if s.a("WorkItemNumberFieldValue", "value"):
            valeurs.append("... on WorkItemNumberFieldValue "
                           "{ numberValue: value }")
        if s.a("WorkItemTextFieldValue", "value"):
            valeurs.append("... on WorkItemTextFieldValue "
                           "{ textValue: value }")
        w.append("... on WorkItemWidgetCustomFields { %s }" % selection(
            s, "WorkItemWidgetCustomFields", "customFieldValues",
            " ".join(valeurs)))
    if avec_liens and s.a("WorkItemWidgetLinkedItems", "linkedItems"):
        w.append("... on WorkItemWidgetLinkedItems { %s }" % selection(
            s, "WorkItemWidgetLinkedItems", "linkedItems",
            "linkType workItem { id }", "(first: 100)"))

    args = ["first: $first", "after: $after"]
    possibles = s.arguments("Group", "workItems")
    for nom, valeur in ARGS_OPTIONNELS:
        if nom in possibles and nom not in args_exclus:
            args.append("%s: %s" % (nom, valeur))

    return ("query($fullPath: ID!, $first: Int, $after: String) { "
            "group(fullPath: $fullPath) { workItems(%s) { "
            "pageInfo { hasNextPage endCursor } "
            "nodes { %s widgets { %s } } } } }"
            % (", ".join(args), " ".join(champs), " ".join(w)))


def lire_work_items(client, schema, groupe, taille_page, avec_liens,
                    avec_description):
    if "includeDescendants" not in schema.arguments("Group", "workItems"):
        avertir("Group.workItems n'accepte pas includeDescendants : seuls les "
                "éléments du groupe lui-même seront lus.")
    page = max(5, min(100, taille_page))
    curseur = None
    elements = []
    numero = 0
    args_exclus = set()
    while True:
        requete = construire_requete(schema, avec_liens, avec_description,
                                     args_exclus)
        try:
            donnees = client.graphql(requete, {
                "fullPath": groupe, "first": page, "after": curseur})
        except ErreurGraphQL as erreur:
            message = str(erreur)
            fautif = [nom for nom, _ in ARGS_OPTIONNELS
                      if nom in message and nom not in args_exclus]
            if fautif and "complexity" not in message.lower():
                avertir("argument %s refusé par cette version : retiré."
                        % fautif[0])
                args_exclus.add(fautif[0])
                continue
            if "complexity" not in message.lower():
                raise
            m = RE_COMPLEXITE.search(message)
            if m:
                score, limite = int(m.group(1)), int(m.group(2))
                nouvelle = min(page - 1, int(page * limite / float(score) * 0.9))
            else:
                nouvelle = page // 2
            if nouvelle >= 5:
                journal("requête trop complexe, taille de page %d -> %d"
                        % (page, nouvelle))
                page = nouvelle
                continue
            if avec_liens:
                avertir("requête trop complexe : dépendances (liens) "
                        "abandonnées pour cette exécution.")
                avec_liens = False
                continue
            if avec_description:
                avertir("requête trop complexe : descriptions abandonnées.")
                avec_description = False
                continue
            raise
        groupe_gql = donnees.get("group")
        if groupe_gql is None:
            arreter("groupe « %s » introuvable ou invisible pour ce jeton."
                    % groupe, 2)
        connexion = groupe_gql.get("workItems") or {}
        lot = connexion.get("nodes") or []
        elements.extend(lot)
        numero += 1
        journal("page %d : %d éléments (total %d)"
                % (numero, len(lot), len(elements)))
        info = connexion.get("pageInfo") or {}
        if not info.get("hasNextPage"):
            break
        curseur = info.get("endCursor")
        if not curseur:
            break
    return elements, avec_liens, avec_description


# --------------------------------------------------------------------------
# Normalisation et calculs
# --------------------------------------------------------------------------

def normaliser(noeud):
    r = {
        "gid": noeud.get("id") or "", "iid": noeud.get("iid") or "",
        "titre": noeud.get("title") or "",
        "type": (noeud.get("workItemType") or {}).get("name") or "",
        "espace": (noeud.get("namespace") or {}).get("fullPath") or "",
        "url": noeud.get("webUrl") or "",
        "cree_le": date_heure(noeud.get("createdAt")),
        "maj_le": date_heure(noeud.get("updatedAt")),
        "ferme_le": date_heure(noeud.get("closedAt")),
        "parent_gid": "", "parent_ref_brut": "", "parent_titre_brut": "",
        "labels_liste": [], "assignes_liste": [], "description": "",
        "jalon": "", "jalon_debut": "", "jalon_fin": "",
        "iteration": "", "iteration_debut": "", "iteration_fin": "",
        "cadence": "", "poids": None, "sante": "", "date_debut": "",
        "date_echeance": "", "statut": "", "statut_categorie": "",
        "cf": collections.OrderedDict(), "liens": [],
    }
    r["id"] = r["gid"].rsplit("/", 1)[-1] if r["gid"] else ""
    r["ferme"] = (noeud.get("state") or "").upper() == "CLOSED"
    r["etat"] = "Fermé" if r["ferme"] else "Ouvert"
    reference = noeud.get("reference") or ""
    if not reference and r["espace"]:
        separateur = "&" if r["type"].lower() == "epic" else "#"
        reference = "%s%s%s" % (r["espace"], separateur, r["iid"])
    r["ref"] = reference

    for widget in noeud.get("widgets") or []:
        if not isinstance(widget, dict):
            continue
        nom = widget.get("__typename")
        if nom == "WorkItemWidgetHierarchy":
            parent = widget.get("parent") or {}
            r["parent_gid"] = parent.get("id") or ""
            r["parent_ref_brut"] = parent.get("reference") or ""
            r["parent_titre_brut"] = parent.get("title") or ""
        elif nom == "WorkItemWidgetLabels":
            r["labels_liste"] = [n.get("title") for n in
                                 noeuds(widget.get("labels")) if n.get("title")]
        elif nom == "WorkItemWidgetAssignees":
            r["assignes_liste"] = [n.get("username") or n.get("name") for n in
                                   noeuds(widget.get("assignees"))]
        elif nom == "WorkItemWidgetDescription":
            r["description"] = widget.get("description") or ""
        elif nom == "WorkItemWidgetMilestone":
            jalon = widget.get("milestone") or {}
            r["jalon"] = jalon.get("title") or ""
            r["jalon_debut"] = date_seule(jalon.get("startDate"))
            r["jalon_fin"] = date_seule(jalon.get("dueDate"))
        elif nom == "WorkItemWidgetIteration":
            iteration = widget.get("iteration") or {}
            if iteration:
                r["iteration_debut"] = date_seule(iteration.get("startDate"))
                r["iteration_fin"] = date_seule(iteration.get("dueDate"))
                r["cadence"] = (iteration.get("iterationCadence") or {}).get(
                    "title") or ""
                r["iteration"] = iteration.get("title") or (
                    "%s → %s" % (r["iteration_debut"], r["iteration_fin"]))
        elif nom == "WorkItemWidgetWeight":
            r["poids"] = en_nombre(widget.get("weight"))
        elif nom == "WorkItemWidgetHealthStatus":
            valeur = widget.get("healthStatus")
            r["sante"] = SANTE.get(valeur, valeur or "")
        elif nom == "WorkItemWidgetStartAndDueDate":
            r["date_debut"] = date_seule(widget.get("startDate"))
            r["date_echeance"] = date_seule(widget.get("dueDate"))
        elif nom == "WorkItemWidgetStatus":
            statut = widget.get("status") or {}
            r["statut"] = statut.get("name") or ""
            r["statut_categorie"] = str(statut.get("category") or "")
        elif nom == "WorkItemWidgetCustomFields":
            for valeur in noeuds(widget.get("customFieldValues")):
                nom_champ = (valeur.get("customField") or {}).get("name")
                if not nom_champ:
                    continue
                if valeur.get("selectedOptions") is not None:
                    vals = [o.get("value") for o in valeur["selectedOptions"]
                            if o and o.get("value")]
                elif valeur.get("numberValue") is not None:
                    vals = [en_nombre(valeur["numberValue"])]
                elif valeur.get("textValue"):
                    vals = [valeur["textValue"]]
                else:
                    vals = []
                r["cf"][nom_champ] = vals
        elif nom == "WorkItemWidgetLinkedItems":
            for lien in noeuds(widget.get("linkedItems")):
                cible = (lien.get("workItem") or {}).get("id")
                if cible:
                    r["liens"].append(((lien.get("linkType") or "").lower(),
                                       cible))
    return r


def classer(elements, config):
    regles = config["classification"]
    for r in elements:
        labels = set(l.lower() for l in r["labels_liste"])
        r["niveau"] = r["type"] or "?"
        for regle in regles:
            if "type" in regle and \
                    regle["type"].lower() != r["type"].lower():
                continue
            if "label" in regle and regle["label"].lower() not in labels:
                continue
            r["niveau"] = regle["niveau"]
            break


def est_annule(r, config):
    if r["statut_categorie"]:
        return "CANCEL" in r["statut_categorie"].upper()
    annules = set(s.lower() for s in config.get("statuts_annules") or [])
    return r["statut"].lower() in annules


class Index(object):
    def __init__(self, elements):
        self.par_gid = collections.OrderedDict(
            (r["gid"], r) for r in elements)
        self.par_ref = {}
        for r in elements:
            if r["ref"]:
                self.par_ref[r["ref"].lower()] = r
        self.enfants = collections.defaultdict(list)
        for r in elements:
            if r["parent_gid"] in self.par_gid:
                self.enfants[r["parent_gid"]].append(r)

    def ancetres(self, r):
        chaine, vus, courant = [], set([r["gid"]]), r["parent_gid"]
        while courant and courant in self.par_gid and courant not in vus:
            vus.add(courant)
            ancetre = self.par_gid[courant]
            chaine.append(ancetre)
            courant = ancetre["parent_gid"]
        return chaine  # du plus proche au plus lointain

    def descendants(self, r):
        resultat, vus, pile = [], set([r["gid"]]), list(self.enfants[r["gid"]])
        while pile:
            e = pile.pop()
            if e["gid"] in vus:
                continue
            vus.add(e["gid"])
            resultat.append(e)
            pile.extend(self.enfants[e["gid"]])
        return resultat


def enrichir(elements, index, config):
    niveau_fs = config.get("niveau_fs")
    niveau_feature = config.get("niveau_feature")
    for r in elements:
        ancetres = index.ancetres(r)
        parent = index.par_gid.get(r["parent_gid"])
        r["parent"] = parent["ref"] if parent else r["parent_ref_brut"]
        r["chemin"] = " › ".join(a["titre"] for a in reversed(ancetres))
        r["fs"] = r["fs_ref"] = r["feature"] = r["feature_ref"] = ""
        for a in [r] + ancetres:
            if not r["fs"] and a["niveau"] == niveau_fs:
                r["fs"], r["fs_ref"] = a["titre"], a["ref"]
            if not r["feature"] and a["niveau"] == niveau_feature:
                r["feature"], r["feature_ref"] = a["titre"], a["ref"]
        r["labels"] = ", ".join(r["labels_liste"])
        r["assignes"] = ", ".join(x for x in r["assignes_liste"] if x)


def calculer_dependances(elements, index):
    paires = collections.OrderedDict()   # (bloquant, bloque) -> True
    lies = collections.defaultdict(set)
    for r in elements:
        for type_lien, cible in r["liens"]:
            if type_lien == "blocks":
                paires[(r["gid"], cible)] = True
            elif type_lien in ("is_blocked_by", "blocked_by"):
                paires[(cible, r["gid"])] = True
            elif type_lien in ("relates_to", "related", "related_to"):
                lies[r["gid"]].add(cible)
                lies[cible].add(r["gid"])

    def ref_de(gid):
        e = index.par_gid.get(gid)
        return e["ref"] if e else gid

    bloque_par = collections.defaultdict(list)
    bloque_quoi = collections.defaultdict(list)
    for (a, b) in paires:
        bloque_par[b].append(a)
        bloque_quoi[a].append(b)
    for r in elements:
        r["bloque_par"] = ", ".join(sorted((ref_de(g) for g in bloque_par[r["gid"]]),
                                           key=cle_naturelle))
        r["bloque_quoi"] = ", ".join(sorted((ref_de(g) for g in bloque_quoi[r["gid"]]),
                                            key=cle_naturelle))
        r["lie_a"] = ", ".join(sorted((ref_de(g) for g in lies[r["gid"]]),
                                      key=cle_naturelle))
        ouverts = [g for g in bloque_par[r["gid"]]
                   if not (index.par_gid.get(g) or {}).get("ferme", False)]
        r["bloque"] = "Oui" if ouverts else ""

    lignes = []
    for (a, b) in paires:
        A = index.par_gid.get(a)
        B = index.par_gid.get(b)
        if A is None or B is None:
            alerte = "Élément hors du groupe exporté"
        elif A["ferme"]:
            alerte = "Levée"
        elif B["ferme"]:
            alerte = "Sans objet (bloqué fermé)"
        elif not A["iteration_fin"]:
            alerte = "Bloquant non planifié"
        elif not B["iteration_debut"]:
            alerte = "Bloqué non planifié"
        elif A["iteration"] == B["iteration"]:
            alerte = "Même sprint"
        elif A["iteration_fin"] >= B["iteration_debut"]:
            alerte = "Bloquant planifié trop tard"
        else:
            alerte = "OK"
        lignes.append([
            (A or {}).get("ref", a), (A or {}).get("titre", ""),
            (A or {}).get("espace", ""), (A or {}).get("iteration", ""),
            (A or {}).get("iteration_fin", ""), (A or {}).get("etat", ""),
            (B or {}).get("ref", b), (B or {}).get("titre", ""),
            (B or {}).get("espace", ""), (B or {}).get("iteration", ""),
            (B or {}).get("iteration_debut", ""), alerte,
        ])
    return lignes


def calculer_avancement(elements, index, config):
    niveaux = set(config.get("rollup_niveaux") or [])
    for r in elements:
        for cle in ("desc_total", "desc_termines", "desc_poids_total",
                    "desc_poids_termines", "desc_sans_poids", "avancement_pct"):
            r[cle] = None
        descendants = [d for d in index.descendants(r)
                       if d["niveau"] in niveaux and not est_annule(d, config)]
        if not descendants:
            continue
        total = len(descendants)
        termines = sum(1 for d in descendants if d["ferme"])
        points = sum(d["poids"] for d in descendants if d["poids"] is not None)
        points_ok = sum(d["poids"] for d in descendants
                        if d["poids"] is not None and d["ferme"])
        sans_poids = sum(1 for d in descendants if d["poids"] is None)
        r["desc_total"], r["desc_termines"] = total, termines
        r["desc_poids_total"], r["desc_poids_termines"] = points, points_ok
        r["desc_sans_poids"] = sans_poids
        if points:
            r["avancement_pct"] = int(round(100.0 * points_ok / points))
        else:
            r["avancement_pct"] = int(round(100.0 * termines / total))


def valeur_champ(r, nom):
    valeurs = r["cf"].get(nom) or []
    return valeurs[0] if valeurs else None


def calculer_wsjf(elements, config):
    w = config.get("wsjf") or {}
    noms = [w.get("valeur_metier"), w.get("criticite_temporelle"),
            w.get("reduction_risque"), w.get("taille")]
    for r in elements:
        r["wsjf"] = None
        if not all(noms):
            continue
        valeurs = [en_nombre(valeur_champ(r, n)) for n in noms]
        if any(v is None for v in valeurs) or not valeurs[3]:
            continue
        r["wsjf"] = round(float(valeurs[0] + valeurs[1] + valeurs[2])
                          / valeurs[3], 2)


def synthese_iterations(elements, config):
    niveaux = set(config.get("rollup_niveaux") or [])
    groupes = collections.OrderedDict()
    for r in elements:
        if not r["iteration"] or r["niveau"] not in niveaux \
                or est_annule(r, config):
            continue
        for espace in (r["espace"], "(toutes équipes)"):
            cle = (r["iteration_debut"], r["iteration"], r["iteration_fin"],
                   espace)
            g = groupes.setdefault(cle, [0, 0, 0, 0, 0])
            g[0] += 1
            g[1] += 1 if r["ferme"] else 0
            if r["poids"] is None:
                g[4] += 1
            else:
                g[2] += r["poids"]
                g[3] += r["poids"] if r["ferme"] else 0
    lignes = []
    for cle in sorted(groupes, key=lambda c: (c[0], cle_naturelle(c[1]),
                                              c[3] == "(toutes équipes)",
                                              c[3])):
        debut, titre, fin, espace = cle
        g = groupes[cle]
        lignes.append([titre, debut, fin, espace] + g)
    return lignes


def synthese_objectifs(elements, config):
    o = config.get("objectifs") or {}
    if not o.get("niveau"):
        return []
    groupes = collections.OrderedDict()
    engage = (o.get("valeur_engage") or "").lower()
    for r in elements:
        if r["niveau"] != o["niveau"]:
            continue
        planifiee = en_nombre(valeur_champ(r, o.get("vm_planifiee"))) or 0
        brute = en_nombre(valeur_champ(r, o.get("vm_realisee")))
        realisee = brute or 0
        est_engage = (str(valeur_champ(r, o.get("engagement")) or "")
                      .lower() == engage)
        for espace in (r["espace"], "(ART)"):
            g = groupes.setdefault((r["jalon"], espace), [0, 0, 0, 0, 0, 0])
            g[0] += 1
            if est_engage:
                g[1] += 1
                g[2] += planifiee
            g[3] += realisee
            g[4] += planifiee
            g[5] += 0 if brute is None else 1
    lignes = []
    for (jalon, espace) in sorted(groupes, key=lambda c: (
            cle_naturelle(c[0]), c[1] == "(ART)", c[1])):
        nb, nb_engages, vm_eng, vm_real, vm_plan, evalues = \
            groupes[(jalon, espace)]
        # Vide tant qu'aucun objectif n'est evalue (PI a venir)
        predictibilite = int(round(100.0 * vm_real / vm_eng)) \
            if vm_eng and evalues else None
        lignes.append([jalon, espace, nb, nb_engages, vm_plan, vm_eng,
                       vm_real, predictibilite])
    return lignes


# --------------------------------------------------------------------------
# Vues (filtres de vues.json)
# --------------------------------------------------------------------------

def _min(liste):
    return set(str(x).lower() for x in liste)


def _liste(valeur, cle, nom_vue):
    if isinstance(valeur, list):
        return valeur
    if isinstance(valeur, str):
        return [valeur]
    arreter("vue « %s » : « %s » attend une liste." % (nom_vue, cle))


def preparer_filtre(vue, index):
    nom = vue.get("nom", "?")
    filtre = vue.get("filtre") or {}
    inconnues = set(filtre) - CLES_FILTRE
    if inconnues:
        arreter("vue « %s » : filtre(s) inconnu(s) %s. Filtres possibles : %s"
                % (nom, ", ".join(sorted(inconnues)),
                   ", ".join(sorted(CLES_FILTRE))))
    prepare = dict(filtre)
    if "descendants_de" in filtre:
        gids = set()
        for ref in _liste(filtre["descendants_de"], "descendants_de", nom):
            racine = index.par_ref.get(str(ref).lower())
            if racine is None:
                avertir("vue « %s » : référence %s introuvable." % (nom, ref))
                continue
            gids.update(d["gid"] for d in index.descendants(racine))
        prepare["_descendants"] = gids
    return prepare


def correspond(r, f, aujourdhui):
    if "niveau" in f and r["niveau"].lower() not in _min(f["niveau"]):
        return False
    if "type" in f and r["type"].lower() not in _min(f["type"]):
        return False
    etat = str(f.get("etat", "tous")).lower()
    if etat.startswith("ouv") and r["ferme"]:
        return False
    if etat.startswith("ferm") and not r["ferme"]:
        return False
    if "statut" in f and r["statut"].lower() not in _min(f["statut"]):
        return False
    if "jalon" in f:
        voulus = _min(f["jalon"])
        if not ((r["jalon"].lower() in voulus) or
                ("aucun" in voulus and not r["jalon"])):
            return False
    if "iteration" in f:
        voulus = _min(f["iteration"])
        ok = r["iteration"].lower() in voulus
        if "aucune" in voulus and not r["iteration"]:
            ok = True
        if "courante" in voulus and r["iteration_debut"] and \
                r["iteration_debut"] <= aujourdhui <= r["iteration_fin"]:
            ok = True
        if not ok:
            return False
    if "cadence" in f and r["cadence"].lower() not in _min(f["cadence"]):
        return False
    labels = set(l.lower() for l in r["labels_liste"])
    if "labels_tous" in f and not _min(f["labels_tous"]) <= labels:
        return False
    if "labels_un_de" in f and not (_min(f["labels_un_de"]) & labels):
        return False
    if "labels_aucun" in f and (_min(f["labels_aucun"]) & labels):
        return False
    if "espace_commence_par" in f:
        espace = r["espace"].lower()
        if not any(espace.startswith(p) for p in _min(f["espace_commence_par"])):
            return False
    if "_descendants" in f and r["gid"] not in f["_descendants"]:
        return False
    if "champs" in f:
        for nom_champ, voulus in f["champs"].items():
            voulus = _min(voulus if isinstance(voulus, list) else [voulus])
            presents = set(str(v).lower() for v in r["cf"].get(nom_champ) or [])
            if "*" in voulus and presents:
                continue
            if "aucun" in voulus and not presents:
                continue
            if not (voulus & presents):
                return False
    if "bloque" in f and bool(f["bloque"]) != (r["bloque"] == "Oui"):
        return False
    if "texte" in f and str(f["texte"]).lower() not in r["titre"].lower():
        return False
    return True


# --------------------------------------------------------------------------
# Ecriture CSV
# --------------------------------------------------------------------------

class Ecrivain(object):
    def __init__(self, dossier, separateur, decimale):
        self.dossier = dossier
        self.separateur = separateur
        self.decimale = decimale
        self.fichiers = []   # (nom, nb lignes)

    def nombre(self, valeur):
        if valeur is None:
            return ""
        if isinstance(valeur, float):
            texte = ("%.2f" % valeur).rstrip("0").rstrip(".")
        else:
            texte = str(valeur)
        return texte.replace(".", self.decimale)

    def cellule(self, valeur):
        if valeur is None:
            return ""
        if isinstance(valeur, bool):
            return "Oui" if valeur else "Non"
        if isinstance(valeur, (int, float)):
            return self.nombre(valeur)
        if isinstance(valeur, list):
            return ", ".join(self.cellule(v) for v in valeur if v not in (None, ""))
        texte = str(valeur)
        # Neutralise les formules (=, +, -, @) a l'ouverture dans un tableur
        if texte[:1] in DEBUT_FORMULE and not RE_NOMBRE.match(texte):
            texte = "'" + texte
        return texte

    def ecrire(self, nom, entetes, lignes):
        chemin = os.path.join(self.dossier, nom)
        with io.open(chemin, "w", encoding="utf-8-sig", newline="") as f:
            sortie = csv_writer(f, self.separateur)
            sortie.writerow(entetes)
            for ligne in lignes:
                sortie.writerow([self.cellule(v) for v in ligne])
        self.fichiers.append((nom, len(lignes)))
        journal("écrit %s (%d lignes)" % (nom, len(lignes)))


def csv_writer(fichier, separateur):
    return csv.writer(fichier, delimiter=separateur, quotechar='"',
                      quoting=csv.QUOTE_MINIMAL, lineterminator="\r\n")


def valeur_colonne(r, cle):
    if cle.startswith("cf:"):
        return r["cf"].get(cle[3:]) or []
    return r.get(cle)


def entete_colonne(cle):
    return cle[3:] if cle.startswith("cf:") else LIBELLES.get(cle, cle)


def trier(elements, cles):
    resultat = list(elements)
    for cle in reversed(cles or []):
        descendant = cle.startswith("-")
        nom = cle[1:] if descendant else cle

        def cle_tri(r, nom=nom):
            v = valeur_colonne(r, nom)
            if isinstance(v, list):
                v = ", ".join(str(x) for x in v)
            if v is None or v == "":
                return (1, [])
            if isinstance(v, (int, float)) and not isinstance(v, bool):
                return (0, [(0, v, "")])
            return (0, cle_naturelle(str(v)))
        vides = [r for r in resultat if cle_tri(r)[0] == 1]
        pleins = sorted((r for r in resultat if cle_tri(r)[0] == 0),
                        key=cle_tri, reverse=descendant)
        resultat = pleins + vides
    return resultat


# --------------------------------------------------------------------------
# GLQL (blocs ```glql d'un fichier Markdown)
# --------------------------------------------------------------------------

CLES_PRESENTATION = ("display", "title", "description", "collapsed",
                     "displayConfig")


def lire_blocs_glql(texte):
    blocs = []
    for m in re.finditer(r"^```glql[ \t]*\r?\n(.*?)^```[ \t]*$", texte,
                         re.M | re.S):
        blocs.append(m.group(1))
    return blocs


def preparer_glql(bloc, groupe):
    titre = None
    m = re.search(r"^title:\s*(.+?)\s*$", bloc, re.M)
    if m:
        titre = m.group(1).strip().strip("'\"")
    lignes, ignorer = [], False
    for ligne in bloc.splitlines():
        if ignorer and (ligne.startswith(" ") or ligne.startswith("\t")):
            continue
        ignorer = False
        cle = ligne.split(":", 1)[0].strip()
        if not ligne.startswith((" ", "\t")) and cle in CLES_PRESENTATION:
            ignorer = True
            continue
        lignes.append(ligne)
    yaml = "\n".join(lignes).strip() + "\n"
    requete = re.search(r"^query:\s*(.*)$", yaml, re.M)
    texte_requete = requete.group(1) if requete else ""
    if not re.search(r"^(group|project)\s*:", yaml, re.M) and \
            not re.search(r"\b(group|project)\s*(=|in\b)", texte_requete):
        yaml = "group: %s\n" % groupe + yaml
    if not re.search(r"^limit\s*:", yaml, re.M):
        yaml = "limit: 100\n" + yaml
    return titre, yaml


ALIAS_GLQL = {"type": ["workItemType"], "health": ["healthStatus"],
              "healthStatus": ["health"], "assignee": ["assignees"],
              "label": ["labels"], "due": ["dueDate"], "start": ["startDate"]}


def aplatir(valeur):
    if valeur is None:
        return ""
    if isinstance(valeur, bool):
        return "Oui" if valeur else "Non"
    if isinstance(valeur, (int, float)):
        return valeur
    if isinstance(valeur, str):
        if re.match(r"^\d{4}-\d{2}-\d{2}T", valeur):
            return date_heure(valeur)
        return valeur
    if isinstance(valeur, list):
        morceaux = [aplatir(v) for v in valeur]
        return ", ".join(str(m) for m in morceaux if m not in ("", None))
    if isinstance(valeur, dict):
        if "nodes" in valeur:
            return aplatir(valeur["nodes"])
        for cle in ("title", "name", "username", "value", "reference",
                    "fullPath", "text"):
            if valeur.get(cle) not in (None, ""):
                return aplatir(valeur[cle])
        if valeur.get("startDate") or valeur.get("dueDate"):
            return "%s → %s" % (date_seule(valeur.get("startDate")),
                                date_seule(valeur.get("dueDate")))
        return ""
    return str(valeur)


def valeur_glql(noeud, champ):
    for cle in [champ.get("key"), champ.get("name"), champ.get("field")] + \
            ALIAS_GLQL.get(champ.get("key") or "", []):
        if cle and cle in noeud:
            valeur = aplatir(noeud[cle])
            if (champ.get("field") or champ.get("key")) == "state":
                valeur = {"OPEN": "Ouvert", "OPENED": "Ouvert",
                          "CLOSED": "Fermé", "MERGED": "Fusionné"}.get(
                              str(valeur).upper(), valeur)
            if (champ.get("field") or champ.get("key")) in ("health",
                                                            "healthStatus"):
                valeur = SANTE.get(valeur, valeur)
            return valeur
    return ""


def exporter_glql(client, chemin, groupe, ecrivain):
    try:
        with io.open(chemin, "r", encoding="utf-8-sig") as f:
            blocs = lire_blocs_glql(f.read())
    except (IOError, OSError) as erreur:
        avertir("fichier GLQL illisible (%s) : %s" % (chemin, erreur))
        return
    if not blocs:
        avertir("aucun bloc ```glql dans %s" % chemin)
        return
    for numero, bloc in enumerate(blocs, 1):
        titre, yaml = preparer_glql(bloc, groupe)
        nom = "glql_%02d_%s.csv" % (numero, nom_fichier(titre or "vue"))
        if len(yaml.encode("utf-8")) > 10000:
            avertir("bloc GLQL %d trop long (10 Ko max) : ignoré" % numero)
            continue
        curseur, champs, lignes, pages = None, None, [], 0
        try:
            while True:
                corps = {"glql_yaml": yaml}
                if curseur:
                    corps["after"] = curseur
                reponse = client.rest_post("/glql", corps)
                if reponse.get("success") is False or reponse.get("error"):
                    raise ErreurHTTP(0, reponse.get("error") or "échec GLQL")
                if champs is None:
                    champs = reponse.get("fields") or []
                donnees = reponse.get("data") or {}
                for noeud in donnees.get("nodes") or []:
                    lignes.append([valeur_glql(noeud, c) for c in champs])
                pages += 1
                info = donnees.get("pageInfo") or {}
                if not info.get("hasNextPage") or pages >= 500:
                    break
                curseur = info.get("endCursor")
                if not curseur:
                    break
        except ErreurHTTP as erreur:
            avertir("bloc GLQL %d (« %s ») : %s" % (numero, titre or "", erreur))
            continue
        entetes = [c.get("label") or c.get("key") for c in (champs or [])]
        ecrivain.ecrire(nom, entetes, lignes)


# --------------------------------------------------------------------------
# Programme principal
# --------------------------------------------------------------------------

def charger_config(chemin):
    config = json.loads(json.dumps(CONFIG_PAR_DEFAUT))
    if not chemin:
        return config
    try:
        with io.open(chemin, "r", encoding="utf-8-sig") as f:
            lue = json.load(f)
    except (IOError, OSError) as erreur:
        arreter("configuration illisible (%s) : %s" % (chemin, erreur))
    except ValueError as erreur:
        arreter("JSON invalide dans %s : %s" % (chemin, erreur))
    for cle, valeur in lue.items():
        if not cle.startswith("_"):
            config[cle] = valeur
    noms = set()
    for vue in config.get("vues") or []:
        if not vue.get("nom"):
            arreter("chaque vue de %s doit avoir un « nom »." % chemin)
        if vue["nom"] in noms:
            arreter("vue « %s » définie deux fois." % vue["nom"])
        noms.add(vue["nom"])
        for cle in vue.get("colonnes") or []:
            if not cle.startswith("cf:") and cle not in LIBELLES:
                arreter("vue « %s » : colonne inconnue « %s ». Colonnes : %s, "
                        "ou cf:<nom du champ personnalisé>."
                        % (vue["nom"], cle, ", ".join(c for c, _ in COLONNES)))
    return config


def analyser_arguments(argv):
    p = argparse.ArgumentParser(
        description="Export CSV des work items GitLab sans service mail "
                    "(snapshot, vues, avancement SAFe).")
    p.add_argument("--groupe", default=os.environ.get("GROUPE_RACINE"),
                   help="chemin complet du groupe racine (ex. ldp)")
    p.add_argument("--url", default=None,
                   help="URL de l'instance (défaut : $GITLAB_URL ou $CI_SERVER_URL)")
    p.add_argument("--token-env", default="GITLAB_TOKEN",
                   help="variable d'environnement contenant le jeton")
    p.add_argument("--config", default=None, help="fichier des vues (vues.json)")
    p.add_argument("--vue", action="append",
                   help="n'exporter que cette vue (répétable ; 'aucune' : aucune)")
    p.add_argument("--glql", default=None,
                   help="fichier Markdown dont chaque bloc ```glql devient un CSV")
    p.add_argument("--sortie", default="export", help="dossier de sortie")
    p.add_argument("--horodater", action="store_true",
                   help="écrire dans un sous-dossier daté AAAA-MM-JJ_HHMM (UTC)")
    p.add_argument("--separateur", default=";", help="séparateur CSV (défaut ;)")
    p.add_argument("--decimale", default=None,
                   help="séparateur décimal (défaut : ',' si séparateur ';')")
    p.add_argument("--avec-description", action="store_true",
                   help="inclure les descriptions (à valider avant sortie)")
    p.add_argument("--avec-url", action="store_true",
                   help="inclure les URL internes")
    p.add_argument("--sans-noms", action="store_true",
                   help="retirer les noms d'utilisateurs (colonne Assignés)")
    p.add_argument("--sans-liens", action="store_true",
                   help="ne pas lire les liens (dépendances)")
    p.add_argument("--taille-page", type=int, default=50,
                   help="éléments par requête GraphQL (5 à 100, défaut 50)")
    p.add_argument("--ca", default=os.environ.get("GITLAB_CA_FILE") or
                   os.environ.get("CI_SERVER_TLS_CA_FILE"),
                   help="certificat de l'autorité interne (PEM) ; défaut : "
                        "$GITLAB_CA_FILE ou $CI_SERVER_TLS_CA_FILE")
    p.add_argument("--insecure", action="store_true",
                   help="ne pas vérifier le certificat TLS (déconseillé)")
    p.add_argument("--sans-proxy", action="store_true",
                   help="ignorer les variables http(s)_proxy")
    p.add_argument("--timeout", type=int, default=60,
                   help="délai réseau en secondes")
    p.add_argument("--debug", action="store_true",
                   help="afficher les requêtes GraphQL (jamais le jeton)")
    p.add_argument("--version", action="version", version=VERSION)
    return p.parse_args(argv)


def main(argv=None):
    args = analyser_arguments(argv)
    if not args.groupe:
        arreter("préciser le groupe racine : --groupe ou $GROUPE_RACINE.")
    url = args.url or os.environ.get("GITLAB_URL") or \
        os.environ.get("CI_SERVER_URL")
    if not url:
        arreter("préciser l'URL : --url, $GITLAB_URL ou $CI_SERVER_URL.")
    jeton = os.environ.get(args.token_env)
    if not jeton:
        arreter("jeton absent : définir la variable $%s." % args.token_env)
    if args.separateur in ("\\t", "tab"):
        args.separateur = "\t"
    decimale = args.decimale or ("," if args.separateur == ";" else ".")
    config = charger_config(args.config)

    debut = datetime.datetime.now(datetime.timezone.utc)
    dossier = args.sortie
    if args.horodater:
        dossier = os.path.join(dossier, debut.strftime("%Y-%m-%d_%H%M"))
    if not os.path.isdir(dossier):
        os.makedirs(dossier)

    client = Client(url, jeton, ca=args.ca, insecure=args.insecure,
                    sans_proxy=args.sans_proxy, timeout=args.timeout,
                    debug=args.debug)
    journal("gitlab_export_pi %s : groupe %s" % (VERSION, args.groupe))
    try:
        version_gitlab = client.rest_get("/version").get("version", "?")
    except ErreurHTTP as erreur:
        if erreur.code in (401, 403):
            arreter(str(erreur), 2)
        version_gitlab = "inconnue"
    journal("version GitLab : %s" % version_gitlab)

    try:
        schema = sonder_schema(client)
        noeuds_bruts, avec_liens, avec_desc = lire_work_items(
            client, schema, args.groupe, args.taille_page,
            not args.sans_liens, args.avec_description)
    except (ErreurGraphQL, ErreurHTTP) as erreur:
        arreter("lecture GraphQL impossible : %s" % erreur, 2)

    elements = [normaliser(n) for n in noeuds_bruts]
    classer(elements, config)
    index = Index(elements)
    enrichir(elements, index, config)
    lignes_dependances = calculer_dependances(elements, index)
    calculer_avancement(elements, index, config)
    calculer_wsjf(elements, config)

    exclues = set()
    if not args.avec_url:
        exclues.add("url")
    if not avec_desc:
        exclues.add("description")
    if args.sans_noms:
        exclues.add("assignes")

    noms_cf = []
    for r in elements:
        for nom in r["cf"]:
            if nom not in noms_cf:
                noms_cf.append(nom)
    noms_cf.sort(key=lambda n: n.lower())

    ecrivain = Ecrivain(dossier, args.separateur, decimale)

    # 1. Snapshot complet
    base = [c for c, _ in COLONNES if c not in ("url", "description")]
    colonnes = [c for c in base if c not in exclues] + \
        ["cf:" + n for n in noms_cf] + \
        [c for c in ("url", "description") if c not in exclues]
    tries = trier(elements, ["niveau", "fs_ref", "feature_ref", "ref"])
    ecrivain.ecrire("00_workitems_complet.csv",
                    [entete_colonne(c) for c in colonnes],
                    [[valeur_colonne(r, c) for c in colonnes] for r in tries])

    # 2. Charge et realise par iteration et par equipe
    ecrivain.ecrire("10_avancement_par_iteration.csv",
                    ["Itération", "Début", "Fin", "Groupe / projet",
                     "Éléments", "Terminés", "Points", "Points terminés",
                     "Éléments sans poids"],
                    synthese_iterations(elements, config))

    # 3. Dependances et alertes de planification
    if avec_liens:
        ecrivain.ecrire("11_dependances.csv",
                        ["Bloquant", "Titre bloquant", "Équipe bloquante",
                         "Itération bloquant", "Fin itération bloquant",
                         "État bloquant", "Bloqué", "Titre bloqué",
                         "Équipe bloquée", "Itération bloqué",
                         "Début itération bloqué", "Alerte"],
                        lignes_dependances)

    # 4. Predictibilite des objectifs PI
    lignes_objectifs = synthese_objectifs(elements, config)
    if lignes_objectifs:
        ecrivain.ecrire("12_predictibilite_objectifs.csv",
                        ["Jalon (PI)", "Groupe / projet", "Objectifs",
                         "Objectifs engagés", "VM planifiée (tous)",
                         "VM planifiée (engagés)", "VM réalisée",
                         "Prédictibilité %"],
                        lignes_objectifs)

    # 5. Vues de vues.json
    selection_vues = args.vue or []
    vues = config.get("vues") or []
    if "aucune" in selection_vues:
        vues = []
    elif selection_vues and "toutes" not in selection_vues:
        connues = set(v["nom"] for v in vues)
        for nom in selection_vues:
            if nom not in connues:
                arreter("vue « %s » absente de la configuration." % nom)
        vues = [v for v in vues if v["nom"] in selection_vues]
    aujourdhui = datetime.date.today().isoformat()
    for vue in vues:
        filtre = preparer_filtre(vue, index)
        retenus = [r for r in elements if correspond(r, filtre, aujourdhui)]
        cols = [c for c in (vue.get("colonnes") or COLONNES_VUE_PAR_DEFAUT)
                if c not in exclues]
        retenus = trier(retenus, vue.get("tri") or ["ref"])
        ecrivain.ecrire("vue_%s.csv" % nom_fichier(vue["nom"]),
                        [entete_colonne(c) for c in cols],
                        [[valeur_colonne(r, c) for c in cols] for r in retenus])

    # 6. Blocs GLQL
    if args.glql:
        exporter_glql(client, args.glql, args.groupe, ecrivain)

    # 7. Manifeste et empreintes
    empreintes = []
    for nom, _ in ecrivain.fichiers:
        h = hashlib.sha256()
        with open(os.path.join(dossier, nom), "rb") as f:
            for bloc in iter(lambda: f.read(65536), b""):
                h.update(bloc)
        empreintes.append((nom, h.hexdigest()))
    with io.open(os.path.join(dossier, "SHA256SUMS"), "w", encoding="utf-8",
                 newline="\n") as f:
        for nom, empreinte in empreintes:
            f.write("%s  %s\n" % (empreinte, nom))
    comptes = dict(ecrivain.fichiers)
    par_niveau = collections.Counter(r["niveau"] for r in elements)
    with io.open(os.path.join(dossier, "MANIFEST.txt"), "w", encoding="utf-8",
                 newline="\r\n") as f:
        f.write("EXPORT GITLAB - WORK ITEMS\n")
        f.write("Outil              : gitlab_export_pi.py %s\n" % VERSION)
        f.write("Extraction (UTC)   : %s\n" % debut.strftime("%Y-%m-%dT%H:%M:%SZ"))
        f.write("Groupe racine      : %s\n" % args.groupe)
        f.write("Version GitLab     : %s\n" % version_gitlab)
        f.write("Options            : descriptions=%s, url=%s, noms=%s, liens=%s\n"
                % ("oui" if avec_desc else "non",
                   "oui" if args.avec_url else "non",
                   "non" if args.sans_noms else "oui",
                   "oui" if avec_liens else "non"))
        f.write("Éléments lus       : %d\n" % len(elements))
        for niveau, nombre in sorted(par_niveau.items()):
            f.write("    %-28s %d\n" % (niveau, nombre))
        f.write("\nFichiers (lignes hors en-tête, SHA-256) :\n")
        for nom, empreinte in empreintes:
            f.write("  %-48s %6d  %s\n" % (nom, comptes.get(nom, 0), empreinte))
        f.write("\nContrôle : sha256sum -c SHA256SUMS (Linux) ou "
                "Get-FileHash -Algorithm SHA256 <fichier> (Windows).\n")
        if AVERTISSEMENTS:
            f.write("\nAvertissements :\n")
            for message in AVERTISSEMENTS:
                f.write("  - %s\n" % message)

    journal("terminé : %d éléments, %d fichiers dans %s"
            % (len(elements), len(ecrivain.fichiers), dossier))
    return 3 if AVERTISSEMENTS else 0


if __name__ == "__main__":
    sys.exit(main())
