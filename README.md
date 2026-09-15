# Parc de VM IAAS

Deploiement des grappes de VM avec OpenTofu, et rapport d'etat genere
automatiquement a chaque pipeline.

**Regle unique du depot : l'etat ne s'ecrit pas a la main.** `grappes.yaml`
decrit ce qu'on veut, OpenTofu le deploie, la doc est un sous-produit.

---

## La chaine

```
grappes.yaml ──┬─> tools/grappes.mjs pipeline ─> pipeline enfant GitLab
               │                                   └─> plan / apply par grappe
               └─> tofu/locals.tf ─> deploiement ─> output "inventaire"
                                                          │
                          plan nocturne (derive) ─────────┤
                          API GitLab (deploiements) ──────┤
                                                          v
                                          tools/grappes.mjs render
                                                          │
                                              site/docs/etat/*.md
                                                          │
                                                   GitLab Pages
```

Quatre proprietes en decoulent :

- **Un seul endroit a editer.** Ajouter une grappe = une entree dans
  `grappes.yaml`. La pipeline, les jobs, les IP, les pages se regenerent.
- **Impossible de documenter faux.** Le rapport est lu depuis le state, pas
  recopie.
- **La derive est visible.** Un `tofu plan` nocturne distingue "ce qu'on a
  demande" de "ce qui tourne".
- **Le site est interchangeable.** Le generateur sort du markdown standard :
  Docusaurus, MkDocs ou le rendu GitLab natif consomment la meme sortie.

---

## Arborescence

```
grappes.yaml              source de verite : subnets, roles, gabarits, grappes
.gitlab-ci.yml            pipeline parent (verif, deploiement, rapport, pages)
ci/
  backend.sh              init du backend HTTP GitLab, un state par grappe
  tofu.yml                modeles de jobs plan / apply
tofu/
  locals.tf               plan d'adressage : SEULE autorite sur les IP
  outputs.tf              output "inventaire" = contrat avec la doc
  modules/vm/main.tf      seul fichier specifique au provider IaaS
tools/
  grappes.mjs             valider | liste | pipeline | render
  rendu.mjs               generation du markdown
site/                     Docusaurus ; site/docs/etat/ est genere
```

---

## Mise en place

### 1. Adapter ce qui est propre a votre IaaS

Trois endroits, et rien d'autre :

| Quoi | Ou |
| --- | --- |
| Valeurs de `X` par subnet, roles, gabarits, grappes | `grappes.yaml` |
| Provider et ressource VM | `tofu/versions.tf`, `tofu/modules/vm/main.tf` |
| Images et flavors du catalogue | `grappes.yaml` (`gabarits`, `defauts.image`) |

Le module VM est ecrit pour OpenStack. Pour Proxmox, vSphere ou libvirt, seul
`tofu/modules/vm/main.tf` change : les contrats d'entree et de sortie du module
ne bougent pas, donc ni l'adressage ni la doc ne bougent.

### 2. Variables CI

`Settings > CI/CD > Variables`, toutes masquees :

| Variable | Contenu |
| --- | --- |
| `TF_VAR_network_id` | ID du reseau IaaS |
| `TF_VAR_subnet_ids` | JSON : `{"steeris":"<uuid>","akkodis":"<uuid>"}` |
| `TF_VAR_cle_ssh` | Nom de la paire de cles |
| credentials IaaS | selon le provider (`OS_*` pour OpenStack) |
| `GITLAB_API_TOKEN` | scope `read_api`, pour l'historique des deploiements |

Le state n'a besoin d'aucun secret : `ci/backend.sh` utilise `CI_JOB_TOKEN`.

### 3. Le site

```bash
npx create-docusaurus@latest site classic
```

puis remplacer `site/docusaurus.config.js` et `site/sidebars.js` par ceux
fournis, supprimer `site/docs/*` d'exemple, et garder `conventions.md`.
`site/docs/etat/` est genere : le laisser dans `.gitignore`.

Activer GitLab Pages (`Deploy > Pages`).

### 4. Le controle de derive

`Build > Pipeline schedules` : une planification quotidienne, par exemple
`0 3 * * *`, sur la branche par defaut. Elle saute le deploiement et joue
uniquement le plan de comparaison, qui alimente la colonne "Etat" du rapport.

### 5. Verrouiller la branche par defaut

`Settings > Repository > Protected branches` : pas de push direct. C'est ce qui
garantit que le contenu du depot decrit reellement le parc.

---

## Au quotidien

**Changer la version du composant sur la pre-prod**

```yaml
- numero: 8
  env: preprod
  version_composant: "2.6.0"   # <- la seule ligne a toucher
```

MR, relecture du plan affiche dans la MR, fusion, puis le job `apply:preprod`
attend un clic. La page se regenere.

**Ajouter une grappe** : une entree dans `grappes.yaml`. La pipeline enfant
gagne ses jobs toute seule.

**Comprendre un 🟠** : la page de la grappe contient l'extrait du plan qui
montre l'ecart. Soit quelqu'un a modifie une VM a la main, soit une MR fusionnee
n'a pas encore ete appliquee.

---

## Verifications locales

```bash
cd tools && npm ci

node grappes.mjs valider    # collisions d'IP, numeros, subnets inconnus
node grappes.mjs pipeline   # inspecter la pipeline enfant generee
node grappes.mjs liste
```

`valider` tourne aussi en CI et bloque la MR.

---

## Points de vigilance

- **Ne jamais mettre de metadonnee de CI dans l'output `inventaire`.** Pipeline,
  date ou commit dans l'output feraient sortir `tofu plan -detailed-exitcode`
  en code 2 a chaque execution, et la detection de derive ne vaudrait plus rien.
- **La formule d'adressage existe a deux endroits** : `tofu/locals.tf` (autorite)
  et `tools/grappes.mjs` (lint de collisions hors tofu). Les changer ensemble.
- **`for_each` est indexe par role**, pas par position : renumeroter une grappe
  ne detruit pas les VM des autres roles.
- **Un state par grappe.** Un incident sur la grappe de dev ne peut pas verrouiller
  ni corrompre l'etat de la prod.
- **`ignore_changes = [image_name]`** empeche une nouvelle image du catalogue de
  recreer les VM sans decision explicite. A retirer si vous voulez l'inverse.

---

## Et Netbox ?

Netbox reste le bon outil le jour ou l'IPAM depasse ces grappes : plusieurs
equipes, adressage non deterministe, materiel physique a inventorier. Il se
branche sur cette chaine sans la remplacer — un job supplementaire qui pousse
`out/*.inventaire.json` via son API, avec la meme source. Ce qu'il ne faut pas
faire, c'est le remplir a la main : un inventaire saisi manuellement est faux
plus vite qu'une page de documentation.
