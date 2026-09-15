---
title: Conventions
sidebar_position: 2
---

# Conventions du parc IAAS seanergy

Cette page est **ecrite a la main** : elle explique des regles, pas un etat.
Tout ce qui decrit l'etat reel se trouve dans [Etat du parc](/etat) et se
regenere tout seul.

## Une grappe

Une grappe est un environnement complet et autonome : quatre VM qui se suffisent
a elles-memes. On ne partage pas de VM entre environnements, meme le NTP : c'est
ce qui permet de detruire et recreer une grappe sans se demander qui en depend.

| Role | Fonction |
| --- | --- |
| `apps` | Services silo |
| `mock` | Simulateur |
| `regievideo` | Gestion des flux video |
| `ntp` | Serveur de temps |

## Adressage

`10.29.X.YZ`

- **X** — le subnet (`steeris`, `akkodis`, `ussps`, `dronathlon`, ...)
- **Y** — le numero de grappe
- **Z** — le role, dans l'ordre du tableau ci-dessus

Consequence : une adresse se deduit, elle ne se cherche pas. `10.29.10.82` est
la VM `regievideo` de la grappe 8 sur `steeris`.

Le numero de grappe est limite a 25 (au-dela, `Y*10 + Z` depasserait 254).

## Ce qui fait foi

1. `grappes.yaml` — ce qu'on veut
2. Le state OpenTofu — ce qui a ete deploye
3. Le plan de derive nocturne — ce qui tourne vraiment

La documentation n'est jamais une quatrieme source : elle est la mise en forme
des trois premieres.

## Ce qu'on ne fait pas

- Modifier une VM depuis la console de l'IaaS. Le plan nocturne le verra et la
  grappe passera en 🟠 ; le prochain deploiement ecrasera la modification.
- Editer une page sous `etat/`. Elle est regeneree a chaque pipeline.
- Ajouter une grappe ailleurs que dans `grappes.yaml`.

## Ajouter une grappe

Ajouter une entree dans `grappes.yaml` :

```yaml
- numero: 4
  env: integration
  subnet: akkodis
  version_composant: "2.5.0"
  validation_manuelle: false
```

La MR suffit : le job de verification refuse les collisions d'IP et les numeros
hors intervalle, la pipeline enfant se regenere avec un couple de jobs
`plan` / `apply` pour la nouvelle grappe, et la page apparait dans la doc.
