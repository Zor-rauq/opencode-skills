# Kit d'export des work items GitLab, sans mail

Une exécution lit tous les work items du groupe racine (Fonctions de service,
Features, stories, enablers, spikes, tâches, objectifs PI, risques) et produit
des CSV prêts à sortir de l'enclave : un instantané complet, des synthèses
d'avancement, une vue par filtre pré-défini, avec un manifeste d'empreintes.

L'export CSV natif de GitLab envoie le fichier par e-mail : ce kit passe par
l'API et dépose les fichiers en artefacts de pipeline.

## Contenu

| Fichier | Rôle |
| --- | --- |
| `gitlab_export_pi.py` | Script d'export. Python 3.6 ou plus, bibliothèque standard seule. |
| `vues.json` | Classification SAFe, champs WSJF et objectifs, vues pré-filtrées. |
| `vues_glql.md` | Vues GLQL : tableau de bord affiché par GitLab et export CSV. |
| `.gitlab-ci.yml` | Pipeline : export à la demande ou planifié, CSV en artefacts. |
| `modeles/.gitlab/issue_templates/` | Modèles de description : Feature, FS, User Story, Enabler, Spike, Objectif PI, Risque. |

## Mise en place (une fois)

1. Créer le projet `ldp/00-pilotage/export-avancement` et y pousser
   `gitlab_export_pi.py`, `vues.json`, `vues_glql.md` et `.gitlab-ci.yml`.
2. Sur le groupe racine `ldp` : Paramètres > Jetons d'accès > jeton de groupe,
   rôle Reporter, scope `read_api`, expiration selon votre politique.
3. Dans le projet d'export : Paramètres > CI/CD > Variables, ajouter
   `GITLAB_TOKEN` (masquée). Si l'autorité de certification interne n'est pas
   dans l'image : `GITLAB_CA_FILE`, variable de type Fichier contenant le PEM.
4. Adapter `.gitlab-ci.yml` : `GROUPE_RACINE`, `PYTHON_IMAGE` (image de votre
   registre interne) et `tags` du runner.
5. Copier `modeles/.gitlab/issue_templates/` dans le projet `ldp/modeles`
   (enfant direct du groupe racine), puis le choisir dans Paramètres > Général >
   Modèles du groupe `ldp`.

## Lancer un export

- À la demande : Build > Pipelines > Run pipeline, choisir `VUE`.
- Planifié : Build > Pipeline schedules, par exemple chaque vendredi en fin de
  journée. Chaque artefact est un instantané daté : leur suite donne les
  burnups hors enclave.
- Depuis un poste de l'enclave (ne jamais passer le jeton en argument) :

```bash
export GITLAB_URL=https://gitlab.enclave.local
export GITLAB_TOKEN=...
python3 gitlab_export_pi.py --groupe ldp --config vues.json \
        --glql vues_glql.md --sortie export --horodater
```

Code retour : 0 = succès, 3 = export produit avec avertissements (détail dans
`MANIFEST.txt`), 1 = configuration, 2 = accès GitLab.

## Fichiers produits

| Fichier | Contenu |
| --- | --- |
| `00_workitems_complet.csv` | Un élément par ligne : niveau SAFe, type, statut, FS et Feature d'appartenance, chemin, jalon, itération, poids, dépendances, champs personnalisés, avancement, WSJF. |
| `10_avancement_par_iteration.csv` | Par sprint et par équipe : éléments et points planifiés, terminés, sans poids. |
| `11_dependances.csv` | Chaque lien « bloque », avec une alerte de planification. |
| `12_predictibilite_objectifs.csv` | Par PI et par équipe : VM planifiée des objectifs engagés, VM réalisée, prédictibilité. |
| `vue_<nom>.csv` | Une vue de `vues.json`. |
| `glql_NN_<titre>.csv` | Un bloc de `vues_glql.md`. |
| `MANIFEST.txt`, `SHA256SUMS` | Date, version GitLab, options, comptes, empreintes SHA-256. |

Règles de calcul :

- **Avancement d'un épic** : points terminés ÷ points totaux de ses User
  Stories, Enablers et Spikes descendants (à défaut de poids : nombre
  d'éléments). Les tâches ne comptent pas ; les éléments Abandonné ou Doublon
  sont exclus.
- **WSJF** : (Valeur métier + Criticité temporelle + Réduction risque /
  opportunité) ÷ Taille.
- **Alertes de dépendance** : Levée (bloquant fermé), Bloquant non planifié,
  Bloqué non planifié, Même sprint, Bloquant planifié trop tard (le bloquant
  finit après le début du bloqué), OK.
- **Prédictibilité** : VM réalisée de tous les objectifs ÷ VM planifiée des
  objectifs engagés ; vide tant qu'aucune VM réalisée n'est saisie.

Les noms (niveaux, champs, statuts) se règlent en tête de `vues.json` :
`classification`, `rollup_niveaux`, `statuts_annules`, `wsjf`, `objectifs`.

## Écrire une vue

```json
{
  "nom": "equipe_a_pi1",
  "description": "Backlog de l'équipe A au PI 1",
  "filtre": {"espace_commence_par": ["ldp/10-equipes/equipe-a"], "jalon": ["PI-1"]},
  "colonnes": ["iteration", "ref", "niveau", "titre", "statut", "poids", "feature"],
  "tri": ["iteration_debut", "-poids"]
}
```

Les filtres se combinent en ET ; dans une liste, une seule valeur suffit.

| Filtre | Exemple | Retient |
| --- | --- | --- |
| `niveau` | `["Feature"]` | Niveau SAFe issu de `classification` |
| `type` | `["Spike"]` | Type GitLab |
| `etat` | `"ouvert"`, `"ferme"`, `"tous"` | État ouvert ou fermé |
| `statut` | `["En cours"]` | Statut |
| `jalon` | `["PI-1"]`, `["aucun"]` | Jalon (milestone) |
| `iteration` | `["PI1-S2"]`, `["courante"]`, `["aucune"]` | Itération |
| `cadence` | `["Sprints"]` | Cadence d'itération |
| `labels_tous`, `labels_un_de`, `labels_aucun` | `["dependance::externe"]` | Labels |
| `espace_commence_par` | `["ldp/10-equipes/equipe-a"]` | Une équipe, un sous-groupe |
| `descendants_de` | `["ldp&12"]` | Tout ce qui est sous une FS ou une Feature |
| `champs` | `{"Programmes": ["Programme A"]}` | Champ personnalisé ; `"*"` = renseigné, `"aucun"` = vide |
| `bloque` | `true` | Bloqué par un élément ouvert |
| `texte` | `"radar"` | Mot dans le titre |

Colonnes disponibles : `ref`, `id`, `niveau`, `type`, `titre`, `etat`,
`statut`, `fs_ref`, `fs`, `feature_ref`, `feature`, `parent`, `chemin`,
`espace`, `jalon`, `iteration`, `iteration_debut`, `iteration_fin`, `cadence`,
`poids`, `sante`, `date_debut`, `date_echeance`, `assignes`, `labels`,
`bloque`, `bloque_par`, `bloque_quoi`, `lie_a`, `desc_total`, `desc_termines`,
`desc_poids_total`, `desc_poids_termines`, `desc_sans_poids`,
`avancement_pct`, `wsjf`, `cree_le`, `maj_le`, `ferme_le`, `url`,
`description`, et `cf:<Nom du champ>` pour un champ personnalisé.
Tri : liste de colonnes, préfixe `-` pour décroissant.

## Vues GLQL

Chaque bloc ` ```glql ` de `vues_glql.md` devient un CSV dont les colonnes
sont les `fields` du bloc. Le même fichier s'affiche en tables à jour quand on
l'ouvre dans GitLab. API GLQL requise : GitLab 18.7 ou plus. Limites : 10 Ko
par bloc ; le script suit la pagination (100 lignes par page).

## Sortie de l'enclave

- Par défaut, ni descriptions ni URL internes. `--avec-description` et
  `--avec-url` les ajoutent ; `--sans-noms` retire les noms d'utilisateurs.
- Les cellules commençant par `=`, `+`, `-` ou `@` sont préfixées d'une
  apostrophe : aucune formule ne s'exécute à l'ouverture dans un tableur.
- Fichiers en UTF-8 avec BOM, séparateur `;`, décimales à virgule : ouverture
  directe dans Excel en français. `--separateur ,` passe au format anglo-saxon.
- Noms de fichiers en ASCII. Vérifier l'intégrité des deux côtés du sas :
  `sha256sum -c SHA256SUMS` (Linux) ou `Get-FileHash -Algorithm SHA256`
  (Windows).
- Le jeu de colonnes de chaque vue est fixe : l'officier de sécurité le
  valide une fois, pas à chaque export.

## Options

| Option | Effet |
| --- | --- |
| `--groupe ldp` | Groupe racine (défaut : `$GROUPE_RACINE`) |
| `--url` | URL de l'instance (défaut : `$GITLAB_URL` ou `$CI_SERVER_URL`) |
| `--token-env NOM` | Variable contenant le jeton (défaut : `GITLAB_TOKEN`) |
| `--config vues.json` | Configuration et vues |
| `--vue NOM` | N'exporter que cette vue (répétable) ; `aucune` : aucune vue |
| `--glql fichier.md` | Exporter les blocs GLQL |
| `--sortie dossier`, `--horodater` | Dossier de sortie, sous-dossier daté (heure UTC) |
| `--separateur`, `--decimale` | Format CSV |
| `--avec-description`, `--avec-url`, `--sans-noms` | Contenu exporté |
| `--sans-liens` | Ne pas lire les liens (pas de fichier dépendances) |
| `--taille-page N` | Éléments par requête, 5 à 100 (défaut 50) |
| `--ca fichier.pem`, `--insecure` | Certificat interne, ou pas de vérification (déconseillé) |
| `--sans-proxy` | Ignorer les variables `http(s)_proxy` |
| `--debug` | Afficher les requêtes GraphQL (jamais le jeton) |

## Dépannage

| Message | Cause probable | Action |
| --- | --- | --- |
| `accès refusé (401)` ou `(403)` | Jeton invalide, expiré, ou sans `read_api` | Regénérer le jeton |
| `groupe « … » introuvable` | Chemin erroné ou jeton sans accès | Vérifier `GROUPE_RACINE` et le rôle Reporter |
| `CERTIFICATE_VERIFY_FAILED` | Autorité interne inconnue de l'image | `--ca` ou variable `GITLAB_CA_FILE` |
| `connexion impossible` | Le proxy du runner intercepte l'appel | Ajouter l'hôte GitLab à `NO_PROXY`, ou `--sans-proxy` |
| `requête trop complexe` | Limite de complexité GraphQL | Réglé automatiquement ; sinon `--taille-page 20` ou `--sans-liens` |
| `types absents de cette instance` | Fonction absente de votre version (statut, champs…) | Normal : les colonnes concernées restent vides |
| Bloc GLQL en erreur | Syntaxe, ou GitLab antérieur à 18.7 | Tester le bloc dans une page wiki |
