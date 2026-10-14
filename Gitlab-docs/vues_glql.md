# Tableau de bord PI : vues GLQL

Ce fichier sert deux fois. Ouvert dans GitLab (dépôt ou wiki), chaque bloc
s'affiche en table à jour. Passé au script d'export (`--glql vues_glql.md`),
chaque bloc devient un fichier `glql_NN_<titre>.csv`.

Remplacer `ldp` par le chemin de votre groupe racine. Le filtre `type` de GLQL
ne connaît que les types système (Issue, Task, Epic…) : les User Stories,
Enablers et Spikes se filtrent par jalon, itération ou projet.

```glql
display: table
title: Features du PI-1
fields: title, labels("niveau::*") AS "Niveau", milestone, health, state, start, due, updated
sort: updated desc
query: type = Epic and group = "ldp" and includeSubgroups = true and label = ~"niveau::feature" and milestone = "PI-1"
```

```glql
display: table
title: Backlog du PI-1 toutes équipes
fields: project, title, type, status, iteration, weight, epic, assignee, state
sort: weight desc
query: group = "ldp" and includeSubgroups = true and milestone = "PI-1" and iteration = any
```

```glql
display: table
title: Sprint en cours
fields: project, title, type, status, weight, assignee, updated
sort: updated desc
query: group = "ldp" and includeSubgroups = true and iteration = current
```

```glql
display: table
title: Éléments à risque
fields: title, type, health, milestone, assignee, updated
sort: updated desc
query: group = "ldp" and includeSubgroups = true and health = "at risk" and state = opened
```
