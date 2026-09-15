// =============================================================================
// Rendu markdown. Volontairement sans moteur de template : la sortie est du
// markdown standard, donc le site (Docusaurus, MkDocs, ou le rendu GitLab tout
// court) est interchangeable sans toucher a la chaine.
// =============================================================================

const BANDEAU =
  "<!-- FICHIER GENERE PAR tools/grappes.mjs - NE PAS EDITER A LA MAIN -->\n" +
  "<!-- Pour changer le parc : modifier grappes.yaml et ouvrir une MR. -->\n";

const ETATS = {
  conforme: { icone: "🟢", libelle: "Conforme au code" },
  derive: { icone: "🟠", libelle: "Derive detectee" },
  erreur: { icone: "🔴", libelle: "Verification en echec" },
  inconnu: { icone: "⚪", libelle: "Non verifie" },
};

const dateFr = (iso) =>
  iso
    ? new Date(iso).toLocaleString("fr-FR", {
        dateStyle: "short",
        timeStyle: "short",
        timeZone: "Europe/Paris",
      })
    : "—";

function tableau(entetes, lignes) {
  return [
    `| ${entetes.join(" | ")} |`,
    `| ${entetes.map(() => "---").join(" | ")} |`,
    ...lignes.map((l) => `| ${l.join(" | ")} |`),
  ].join("\n");
}

function etat(derive) {
  const e = ETATS[derive.statut] ?? ETATS.inconnu;
  const quand = derive.verifie_le ? ` (verifie le ${dateFr(derive.verifie_le)})` : "";
  return `${e.icone} ${e.libelle}${quand}`;
}

function deploiementCourt(d) {
  if (!d) return "—";
  const lien = d.url && d.pipeline ? `[#${d.pipeline}](${d.url})` : d.pipeline ? `#${d.pipeline}` : "—";
  return `${lien} · \`${d.commit ?? "?"}\` · ${dateFr(d.date)}`;
}

export function rendreGrappe({ inventaire, derive, deploiement }, conf) {
  const g = inventaire.grappe;

  const resume = tableau(
    ["Propriete", "Valeur"],
    [
      ["Environnement", `**${g.env}**`],
      ["Grappe", `n° ${g.numero}`],
      ["Subnet", `${g.subnet} — \`${g.cidr}\``],
      ["Version du composant", `\`${g.version_composant}\``],
      ["Etat", etat(derive)],
      ["Dernier deploiement", deploiementCourt(deploiement)],
      ["Validation manuelle", conf.grappes.find((x) => x.numero === g.numero)?.validation_manuelle ? "oui" : "non"],
    ],
  );

  const vms = tableau(
    ["Role", "Hostname", "IP", "Gabarit", "vCPU", "RAM", "Disque", "Image"],
    inventaire.vms.map((v) => [
      `**${v.role}**<br/><sub>${v.description}</sub>`,
      `\`${v.hostname}\``,
      `\`${v.ip}\``,
      v.gabarit,
      v.vcpu,
      `${v.ram_go} Go`,
      `${v.disque_go} Go`,
      `\`${v.image}\``,
    ]),
  );

  const detailDerive =
    derive.statut === "derive" && derive.resume
      ? `\n## Derive constatee\n\nLe dernier plan signale un ecart entre le code et l'IaaS :\n\n\`\`\`\n${derive.resume.trim()}\n\`\`\`\n\nRelancer un deploiement pour realigner, ou corriger \`grappes.yaml\` si l'ecart est voulu.\n`
      : "";

  return `---
title: ${g.env}
sidebar_label: ${g.env} (grappe ${g.numero})
---

${BANDEAU}
# ${g.env} — grappe ${g.numero}

${resume}

## VM de la grappe

${vms}

Acces : tunnel WireGuard puis SSH sur l'IP de la VM.
${detailDerive}
## Modifier cette grappe

1. Editer l'entree \`numero: ${g.numero}\` dans \`grappes.yaml\`.
2. Ouvrir une MR : la pipeline joue \`tofu plan\` et affiche l'ecart.
3. Apres fusion, ${conf.grappes.find((x) => x.numero === g.numero)?.validation_manuelle ? "declencher le job `apply` manuellement" : "le deploiement part automatiquement"}.
4. Cette page se regenere seule.
`;
}

export function rendreIndex(grappes, conf) {
  const lignes = grappes
    .sort((a, b) => a.inventaire.grappe.numero - b.inventaire.grappe.numero)
    .map(({ inventaire, derive, deploiement }) => {
      const g = inventaire.grappe;
      return [
        `[${g.env}](./${g.env}.md)`,
        g.numero,
        g.subnet,
        `\`${g.version_composant}\``,
        inventaire.vms.length,
        etat(derive),
        deploiementCourt(deploiement),
      ];
    });

  const roles = tableau(
    ["Suffixe", "Role", "Fonction", "Adresse"],
    conf.roles.map((r) => [
      `\`${r.suffixe}\``,
      `**${r.id}**`,
      r.description,
      `\`${conf.reseau.prefixe}.X.Y${r.suffixe}\``,
    ]),
  );

  return `---
title: Etat du parc
slug: /etat
sidebar_position: 1
---

${BANDEAU}
# Etat du parc IAAS seanergy

Genere le ${dateFr(new Date().toISOString())} depuis l'etat OpenTofu.
Cette page n'est jamais editee a la main : la source est \`grappes.yaml\`.

${tableau(
  ["Environnement", "Grappe", "Subnet", "Version composant", "VM", "Etat", "Dernier deploiement"],
  lignes,
)}

## Plan d'adressage

\`${conf.reseau.prefixe}.X.YZ\` — **X** = subnet, **Y** = numero de grappe, **Z** = role.

${roles}

Subnets : ${Object.entries(conf.reseau.subnets)
    .map(([nom, x]) => `${nom} = \`${x}\``)
    .join(", ")}.

## Legende des etats

${tableau(
  ["Icone", "Signification"],
  Object.values(ETATS).map((e) => [e.icone, e.libelle]),
)}

L'etat est calcule chaque nuit par un \`tofu plan\` sur chaque grappe : il compare
l'IaaS reel au code. Un etat 🟠 signifie que quelqu'un a modifie une VM en dehors
de la pipeline, ou qu'une MR fusionnee n'a pas encore ete deployee.
`;
}
