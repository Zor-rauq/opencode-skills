OpenCode — Agent Instructions
Instructions permanentes pour toutes les sessions OpenCode.
Ce fichier est la référence de comportement de l'agent sur ce projet.
Comportement général
Produis le code le plus simple qui satisfait le besoin.
Préfère la clarté sur l'ingéniosité.
Garde les fonctions courtes et à responsabilité unique.
Utilise des noms de variables et de fonctions qui révèlent l'intention métier ou opérationnelle.
Évite les abstractions prématurées et les patterns non nécessaires.
Limite les commentaires à l'intention, aux contraintes non évidentes, ou aux caveats opérationnels critiques.
Ne commente pas ce que le code exprime déjà clairement.
Ne génère jamais de secrets, tokens, mots de passe ou clés en clair dans le code, les configs, les logs ou les exemples.
Valide les entrées aux frontières de confiance.
Échoue vite sur une configuration invalide ou un état requis manquant.
Standards par type de fichier
Bash / Shell
Commence tout script avec #!/usr/bin/env bash et set -euo pipefail.
Quote les variables systématiquement.
Utilise des tableaux pour les arguments de commandes.
Valide les outils requis et les arguments en entrée au démarrage.
Émets les erreurs vers stderr avec un message actionnable.
Utilise des traps pour nettoyer les fichiers temporaires.
N'utilise pas || true sans justification documentée.
Python
Utilise des type hints sur les fonctions publiques et les helpers importants.
Utilise pathlib pour les chemins.
Utilise logging pour les scripts opérationnels, pas print.
Sépare parsing, orchestration, accès API et formatage de sortie.
Lève des exceptions explicites avec contexte.
Retourne des codes de sortie non-zéro pour les échecs CLI.
N'intègre jamais de credentials.
Terraform / OpenTofu
Épingle les versions providers dans versions.tf.
Utilise des contraintes de type sur les variables.
Préfère for_each à count quand l'identité compte.
Utilise l'état distant pour les environnements partagés et la production.
N'intègre jamais de secrets ; utilise les variables CI ou les secret stores.
Tagging et nommage cohérents sur toutes les ressources.
GitLab CI/CD
Utilise rules à la place de only/except.
Nomme les stages et les jobs clairement.
Scope les artifacts.
Définis des timeouts explicites.
Utilise des variables masquées et protégées pour les secrets.
N'affiche jamais de variables secrets dans les logs.
Déplace la logique complexe dans des scripts versionnés plutôt que dans de l'inline YAML.
Docker / Podman
Multi-stage builds par défaut.
Image de base minimale.
Utilisateur non-root.
COPY plutôt que ADD sauf besoin explicite.
Aucun secret dans les layers.
Entrypoint en forme exec.
Markdown / Documentation
Concis, structuré, orienté action.
Préfère les bullets et les tableaux pour le scanning.
Exemples sanitisés, aucun secret réel.
Terminologie cohérente avec le codebase.
Gestion des secrets
Utilise exclusivement des placeholders dans les exemples : ${SECRET_NAME}, <TOKEN>, CHANGE_ME.
Référence les secrets via les variables CI/CD, les vaults ou les secret managers.
Ne produis aucun secret en clair, même pour un test ou un exemple.
Signale immédiatement toute valeur suspecte détectée dans le code existant.
Sécurité par défaut
Applique le principe de moindre privilège sur les IAM, RBAC, tokens CI, et permissions containers.
Évite les wildcards dans les permissions sauf si strictement nécessaire et justifié.
Sépare les identités humaines et machines.
Utilise des credentials de courte durée quand disponibles.
Workflow Git — branche, commits et validation
Règle fondamentale
Toute modification, même mineure, doit être réalisée dans une branche dédiée.
Ne jamais commiter directement sur main, master, ou toute branche de production.
Nommage de branche
Construis le nom de branche selon le contexte de la tâche :
Utilise le kebab-case, tout en minuscules.
Garde le nom court et factuel (3-5 mots max après le préfixe).
Si une issue ou ticket existe, inclus son identifiant : feat/PROJ-42-add-scan-stage.
Procédure de démarrage systématique
Avant toute modification :
git checkout main && git pull
git checkout -b <type>/<description>
Commits atomiques
Un commit = une modification logique cohérente.
Ne regroupe pas des changements sans lien dans le même commit.
Utilise le format conventionnel :
<type>(<scope>): <description impérative courte>

[Corps optionnel : pourquoi — uniquement si non évident depuis le code]
[Note de compatibilité ou de migration si applicable]
Types valides : feat, fix, refactor, docs, ci, chore, test, security, infra.
Exemples corrects :
feat(ci): add SAST scan stage to merge request pipeline
fix(terraform): set explicit timeout on RDS instance
refactor(deploy): extract environment validation into function
Exemples incorrects :
update stuff
fixes
WIP
various changes
Check-points obligatoires — validation utilisateur
L'agent doit demander une validation explicite avant de continuer dans les situations suivantes.
Ne jamais enchaîner deux check-points sans attendre la confirmation de l'utilisateur.
Check-point 1 — Avant de commencer
Avant de créer la branche et d'écrire le moindre code, présente :
─── CHECK-POINT 1 / Compréhension ──────────────────────────
Objectif  : <ce qui est demandé en une phrase>
Approche  : <liste courte des étapes prévues>
Fichiers  : <liste des fichiers ou composants impactés>
Risques   : <points d'attention ou questions en suspens>
─────────────────────────────────────────────────────────────
→ Confirmes-tu cette direction avant que je commence ?
Check-point 2 — Après chaque étape logique significative
Après avoir committé une étape cohérente :
─── CHECK-POINT 2 / Étape complétée ────────────────────────
Fait      : <description de ce qui a été committé>
Commit    : <hash court — message>
Résultat  : <comportement attendu ou observé>
Suivant   : <prochaine étape prévue>
─────────────────────────────────────────────────────────────
→ On continue sur la prochaine étape ?
Check-point 3 — Avant toute action destructive ou irréversible
Obligatoire avant :
Suppression de fichiers, ressources, branches
Modification d'état Terraform en production
Changement de schéma de base de données
Rotation ou invalidation de credentials
Force-push
─── CHECK-POINT 3 / Action irréversible ────────────────────
Action    : <description précise de ce qui va être exécuté>
Impact    : <ce qui sera modifié ou supprimé définitivement>
Rollback  : <possibilité ou impossibilité de retour arrière>
─────────────────────────────────────────────────────────────
→ Confirmes-tu l'exécution de cette action ?
Check-point 4 — Fin de tâche / prêt pour Merge Request
Avant de proposer d'ouvrir une MR :
─── CHECK-POINT 4 / Prêt pour Merge Request ────────────────
Branche   : <nom de la branche>
Commits   : <liste des commits avec hash court>
Résumé    : <description de ce que la MR apporte>
À vérifier: <points à valider manuellement avant merge>
─────────────────────────────────────────────────────────────
→ Je peux préparer la description de la MR ou tu gères la suite ?
Revue de code
Évalue dans cet ordre : correction, sécurité, risque opérationnel, maintenabilité, simplicité.
Sépare les problèmes bloquants des améliorations optionnelles.
Propose toujours une alternative plus simple ou plus sûre plutôt que de simplement signaler.
Ne pinaille pas sur le style si le projet dispose déjà d'outils de formatting automatique.
Refactoring
Préfère les étapes petites et reviewables.
Ne mélange pas refactoring et ajout de fonctionnalité dans le même commit.
Préserve les interfaces publiques sauf si le changement l'autorise explicitement.
Arrête quand le code est suffisamment clair ; ne vise pas la perfection théorique.
Ce qui est toujours interdit
Commiter directement sur main ou une branche de production.
Hardcoder des secrets, tokens, mots de passe ou clés.
Logger des valeurs sensibles.
Utiliser des wildcards dans les permissions IAM sans justification explicite.
Exécuter une action destructive sans check-point de validation préalable.
Introduire une nouvelle dépendance sans justifier le besoin.
Ignorer silencieusement une erreur.
Enchaîner des étapes sans avoir obtenu la validation de l'utilisateur sur le check-point précédent.
Skills disponibles
Charge le skill correspondant pour toute tâche spécialisée :
