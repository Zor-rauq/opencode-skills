#!/usr/bin/env node
// =============================================================================
// Outil unique du depot. Tout part de grappes.yaml.
//
//   grappes.mjs valider                  lint du fichier declaratif
//   grappes.mjs liste                    numeros de grappes (boucles shell)
//   grappes.mjs pipeline                 pipeline enfant GitLab sur stdout
//   grappes.mjs render <entree> <sortie> rapport markdown depuis les JSON tofu
//
// =============================================================================
import { readFileSync, readdirSync, mkdirSync, writeFileSync, existsSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import yaml from "js-yaml";
import { rendreGrappe, rendreIndex } from "./rendu.mjs";

const RACINE = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const FICHIER = process.env.FICHIER_GRAPPES ?? join(RACINE, "grappes.yaml");

export function charger(chemin = FICHIER) {
  return yaml.load(readFileSync(chemin, "utf8"));
}

// -----------------------------------------------------------------------------
// ATTENTION : formule dupliquee avec tofu/locals.tf. OpenTofu reste l'autorite ;
// on ne la reproduit ici que pour detecter les collisions SANS init tofu.
// Si le plan d'adressage change, les deux endroits changent ensemble.
// -----------------------------------------------------------------------------
function ipsDe(conf, g) {
  const x = conf.reseau.subnets[g.subnet];
  return conf.roles.map((r) => ({
    role: r.id,
    ip: `${conf.reseau.prefixe}.${x}.${g.numero * 10 + r.suffixe}`,
  }));
}

// --- valider -----------------------------------------------------------------
function valider(conf) {
  const erreurs = [];
  const vus = new Map();

  const suffixes = conf.roles.map((r) => r.suffixe);
  if (new Set(suffixes).size !== suffixes.length) {
    erreurs.push("roles : deux roles partagent le meme suffixe.");
  }
  if (suffixes.some((s) => s < 0 || s > 9)) {
    erreurs.push("roles : un suffixe sort de l'intervalle 0-9.");
  }

  const numeros = conf.grappes.map((g) => g.numero);
  if (new Set(numeros).size !== numeros.length) {
    erreurs.push("grappes : deux grappes portent le meme numero.");
  }

  for (const g of conf.grappes) {
    if (g.numero < 1 || g.numero > 25) {
      erreurs.push(`grappe ${g.numero} : numero hors de l'intervalle 1-25.`);
    }
    if (!(g.subnet in conf.reseau.subnets)) {
      erreurs.push(`grappe ${g.numero} : subnet "${g.subnet}" inconnu.`);
    }
    if (!g.version_composant) {
      erreurs.push(`grappe ${g.numero} : version_composant manquante.`);
    }
    for (const r of Object.keys(g.gabarits ?? {})) {
      if (!conf.roles.some((x) => x.id === r)) {
        erreurs.push(`grappe ${g.numero} : surcharge de gabarit sur un role inconnu "${r}".`);
      }
    }
    for (const { role, ip } of ipsDe(conf, g)) {
      if (vus.has(ip)) {
        erreurs.push(`collision d'IP ${ip} : ${vus.get(ip)} et grappe ${g.numero}/${role}.`);
      }
      vus.set(ip, `grappe ${g.numero}/${role}`);
    }
  }

  if (erreurs.length) {
    console.error("grappes.yaml invalide :");
    for (const e of erreurs) console.error("  - " + e);
    process.exit(1);
  }
  console.error(`grappes.yaml valide : ${conf.grappes.length} grappes, ${vus.size} VM.`);
}

// --- pipeline ----------------------------------------------------------------
// Une pipeline enfant generee = les environnements ne sont declares qu'une fois,
// dans grappes.yaml. Ajouter une grappe ne touche aucun fichier de CI.
function pipeline(conf) {
  const jobs = {
    include: [{ local: "ci/tofu.yml" }],
    stages: ["plan", "apply"],
  };

  for (const g of conf.grappes) {
    const variables = {
      GRAPPE_NUMERO: String(g.numero),
      ENVIRONNEMENT: g.env,
      TF_STATE_NAME: `grappe-${g.numero}`,
    };

    jobs[`plan:${g.env}`] = {
      extends: ".tofu:plan",
      variables,
    };

    jobs[`apply:${g.env}`] = {
      extends: ".tofu:apply",
      variables,
      needs: [`plan:${g.env}`],
      // `when` doit vivre dans la regle : au niveau du job il serait ignore.
      rules: [
        {
          if: "$CI_COMMIT_REF_NAME == $CI_DEFAULT_BRANCH",
          when: g.validation_manuelle ? "manual" : "on_success",
          allow_failure: false,
        },
      ],
      environment: {
        name: g.env,
        // Fait apparaitre la grappe dans Operate > Environments, avec
        // l'historique des deploiements (commit, auteur, date) gratuitement.
        url: `https://${conf.reseau.prefixe}.${conf.reseau.subnets[g.subnet]}.${g.numero * 10}`,
      },
    };
  }

  process.stdout.write(yaml.dump(jobs, { lineWidth: 120, noRefs: true }));
}

// --- render ------------------------------------------------------------------
async function dernierDeploiement(env) {
  const api = process.env.CI_API_V4_URL;
  const projet = process.env.CI_PROJECT_ID;
  const jeton = process.env.GITLAB_API_TOKEN;
  if (!api || !projet || !jeton) return null;

  try {
    const r = await fetch(
      `${api}/projects/${projet}/environments?name=${encodeURIComponent(env)}`,
      { headers: { "PRIVATE-TOKEN": jeton } },
    );
    if (!r.ok) return null;
    const [e] = await r.json();
    const d = e?.last_deployment;
    if (!d) return null;
    return {
      pipeline: d.deployable?.pipeline?.id ?? null,
      url: d.deployable?.pipeline?.web_url ?? null,
      commit: d.sha?.slice(0, 8) ?? null,
      ref: d.ref ?? null,
      auteur: d.user?.name ?? null,
      date: d.created_at ?? null,
    };
  } catch {
    return null; // la doc se genere meme sans API : les champs restent vides.
  }
}

async function render(conf, entree, sortie) {
  mkdirSync(sortie, { recursive: true });

  const fichiers = readdirSync(entree).filter((f) => f.endsWith(".inventaire.json"));
  if (!fichiers.length) {
    console.error(`Aucun inventaire trouve dans ${entree}. Rien a generer.`);
    process.exit(1);
  }

  const grappes = [];
  for (const f of fichiers.sort()) {
    const inventaire = JSON.parse(readFileSync(join(entree, f), "utf8"));
    const n = inventaire.grappe.numero;

    const cheminDerive = join(entree, `grappe-${n}.derive.json`);
    const derive = existsSync(cheminDerive)
      ? JSON.parse(readFileSync(cheminDerive, "utf8"))
      : { statut: "inconnu" };

    // Le texte du plan reste dans un fichier a part : pas d'echappement JSON a
    // bricoler en shell, et on garde la sortie tofu telle quelle.
    const cheminPlan = join(entree, `grappe-${n}.plan.txt`);
    if (derive.statut !== "conforme" && existsSync(cheminPlan)) {
      derive.resume = readFileSync(cheminPlan, "utf8").split("\n").slice(-40).join("\n");
    }

    const deploiement = await dernierDeploiement(inventaire.grappe.env);
    const donnees = { inventaire, derive, deploiement };

    writeFileSync(join(sortie, `${inventaire.grappe.env}.md`), rendreGrappe(donnees, conf));
    grappes.push(donnees);
  }

  writeFileSync(join(sortie, "index.md"), rendreIndex(grappes, conf));
  console.error(`${grappes.length} pages generees dans ${sortie}.`);
}

// --- dispatch ----------------------------------------------------------------
const [commande, ...args] = process.argv.slice(2);
const conf = charger();

switch (commande) {
  case "valider":
    valider(conf);
    break;
  case "liste":
    console.log(conf.grappes.map((g) => g.numero).join(" "));
    break;
  case "pipeline":
    valider(conf);
    pipeline(conf);
    break;
  case "render":
    valider(conf);
    await render(conf, args[0] ?? "out", args[1] ?? "site/docs/etat");
    break;
  default:
    console.error("Usage : grappes.mjs valider|liste|pipeline|render <entree> <sortie>");
    process.exit(2);
}
