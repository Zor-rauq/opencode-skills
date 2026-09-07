# Accès et développement sur les grappes de VM

Documentation de configuration du poste de travail : tunnel WireGuard, SSH, Wave Terminal, VS Code Remote.

---

## Sommaire

1. [Topologie et conventions](#1-topologie-et-conventions)
2. [Prérequis](#2-prérequis)
3. [Tunnel WireGuard](#3-tunnel-wireguard)
4. [Configuration SSH](#4-configuration-ssh)
5. [Wave Terminal](#5-wave-terminal)
6. [VS Code Remote](#6-vs-code-remote)
7. [Garde-fous production](#7-garde-fous-production)
8. [Dépannage](#8-dépannage)
9. [Checklist de mise en place](#9-checklist-de-mise-en-place)
10. [Aide-mémoire](#10-aide-mémoire)

---

## 1. Topologie et conventions

### 1.1 Structure d'une grappe

Chaque grappe est un bloc de 4 VM. Le **3ᵉ octet** de l'IP identifie la grappe, le **4ᵉ octet** identifie le rôle. La structure est identique d'une grappe à l'autre.

| Rôle    | Dernier octet | Description                  |
| ------- | ------------- | ---------------------------- |
| `apps`  | `.80`         | Applicatif                   |
| `mock`  | `.81`         | Bouchons / simulateurs       |
| `regie` | `.82`         | Régie                        |
| `ntp`   | `.83`         | Service de temps             |

| Grappe | 3ᵉ octet | Environnement | Plage IP                        |
| ------ | -------- | ------------- | ------------------------------- |
| 1      | `1`      | **PROD**      | `10.29.1.80` → `10.29.1.83`     |
| 8      | `8`      | Pré-production| `10.29.8.80` → `10.29.8.83`     |

> **À confirmer avant application** : cette documentation suppose que le numéro de grappe est bien porté par le 3ᵉ octet (`10.29.<grappe>.8X`). Si la variable est ailleurs, seules les valeurs `HostName` de la section 4 changent — le reste de la structure reste valide.

### 1.2 Convention de nommage retenue

Format : `<env>-<role>`

```
prod-apps      prod-mock      prod-regie      prod-ntp
preprod-apps   preprod-mock   preprod-regie   preprod-ntp
```

Ce nommage sert de clé unique dans **tous** les outils : `~/.ssh/config`, Wave (`connections.json`), VS Code Remote-SSH. Un seul nom à retenir par machine, aucune IP à mémoriser.

> Si d'autres grappes s'ajoutent (grappe 3, 5…), préférer `g3-apps`, `g5-apps` et garder `prod-*` / `preprod-*` comme alias explicites pour les deux grappes critiques.

---

## 2. Prérequis

| Élément                 | Vérification                          |
| ----------------------- | ------------------------------------- |
| Client WireGuard        | `wg --version`                        |
| OpenSSH client          | `ssh -V`                              |
| Wave Terminal ≥ 0.14    | menu Wave → About (les sessions durables nécessitent 0.14) |
| VS Code + Remote-SSH    | extension `ms-vscode-remote.remote-ssh` |

Accès requis côté IaaS : compte utilisateur sur les 8 VM, et clé publique déployable (ou mot de passe temporaire pour le premier dépôt de clé).

---

## 3. Tunnel WireGuard

Le tunnel doit être **monté avant** toute tentative de connexion. Wave et VS Code échouent silencieusement ou se figent si le réseau n'est pas joignable au moment de la connexion.

### 3.1 Montage / démontage

```bash
# Montage
sudo wg-quick up <nom_interface>

# Vérification de l'état
sudo wg show

# Test de joignabilité de la grappe
ping -c 2 10.29.1.80

# Démontage
sudo wg-quick down <nom_interface>
```

### 3.2 Alias pratiques

À ajouter dans le `~/.zshrc` **du poste** (pas des VM) :

```zsh
alias vpn-up='sudo wg-quick up <nom_interface> && sudo wg show'
alias vpn-down='sudo wg-quick down <nom_interface>'
alias vpn-status='sudo wg show <nom_interface> | head -20'

# Vérifie que la grappe répond avant de lancer les outils
grappe-check() {
  local octet="${1:-1}"
  for ip in 80 81 82 83; do
    if ping -c1 -W1 "10.29.${octet}.${ip}" >/dev/null 2>&1; then
      echo "OK   10.29.${octet}.${ip}"
    else
      echo "KO   10.29.${octet}.${ip}"
    fi
  done
}
```

Usage : `grappe-check 1` (prod), `grappe-check 8` (pré-prod).

### 3.3 Démarrage automatique (optionnel)

```bash
sudo systemctl enable --now wg-quick@<nom_interface>
```

À éviter si le tunnel route du trafic non désiré en permanence. Préférer le montage manuel via alias.

---

## 4. Configuration SSH

C'est la **source de vérité unique** : Wave et VS Code lisent tous les deux `~/.ssh/config`. Toute machine déclarée ici apparaît automatiquement dans les deux outils.

### 4.1 Génération de la clé

```bash
ssh-keygen -t ed25519 -C "poste-<ton_login>" -f ~/.ssh/id_ed25519_grappes
```

Utiliser une passphrase, elle sera mise en cache par l'agent SSH.

### 4.2 Déploiement de la clé sur les 8 VM

Tunnel monté, puis :

```bash
for env in 1 8; do
  for ip in 80 81 82 83; do
    ssh-copy-id -i ~/.ssh/id_ed25519_grappes.pub <USER>@10.29.${env}.${ip}
  done
done
```

### 4.3 Fichier `~/.ssh/config`

```sshconfig
# ============================================================
#  GRAPPES VM — généré manuellement, source de vérité
#  Les blocs spécifiques DOIVENT précéder le bloc wildcard :
#  SSH retient la PREMIÈRE valeur trouvée pour chaque mot-clé.
# ============================================================

# ---------- GRAPPE 1 — PRODUCTION ----------
Host prod-apps
  HostName 10.29.1.80

Host prod-mock
  HostName 10.29.1.81

Host prod-regie
  HostName 10.29.1.82

Host prod-ntp
  HostName 10.29.1.83

# ---------- GRAPPE 8 — PRÉ-PRODUCTION ----------
Host preprod-apps
  HostName 10.29.8.80

Host preprod-mock
  HostName 10.29.8.81

Host preprod-regie
  HostName 10.29.8.82

Host preprod-ntp
  HostName 10.29.8.83

# ---------- OPTIONS COMMUNES (en dernier) ----------
Host prod-* preprod-*
  User <USER>
  IdentityFile ~/.ssh/id_ed25519_grappes
  IdentitiesOnly yes
  AddKeysToAgent yes
  # Les options ci-dessous sont utilisées par le client ssh et VS Code,
  # mais IGNORÉES par Wave (voir 4.5).
  ServerAliveInterval 30
  ServerAliveCountMax 3
  TCPKeepAlive yes
```

### 4.4 Permissions

```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/config ~/.ssh/id_ed25519_grappes
chmod 644 ~/.ssh/id_ed25519_grappes.pub
```

### 4.5 Contraintes imposées par Wave

Wave parse `~/.ssh/config` mais avec deux limites qui doivent orienter l'écriture du fichier :

- **Le mot-clé `Match` n'est pas supporté** (incompatibilité de la bibliothèque de parsing). Ne pas l'utiliser dans ce fichier, sous peine de casser la résolution.
- **Seul un sous-ensemble des mots-clés est appliqué** : `Host`, `User`, `HostName`, `Port`, `IdentityFile`, `BatchMode`, `PubkeyAuthentication`, `PasswordAuthentication`, `KbdInteractiveAuthentication`, `PreferredAuthentications`, `AddKeysToAgent`, `IdentityAgent`, `IdentitiesOnly`, `ProxyJump`, `UserKnownHostsFile`, `GlobalKnownHostsFile`.
  Tout le reste (`ServerAliveInterval`, `ControlMaster`, `Compression`, `LocalForward`…) est parsé mais sans effet dans Wave. La persistance de session dans Wave passe par les **sessions durables** (section 5.5), pas par les keepalives SSH.

### 4.6 Rebond via bastion (si applicable)

Si l'IaaS impose un bastion plutôt qu'un accès direct :

```sshconfig
Host bastion
  HostName <ip_ou_dns_bastion>
  User <USER>

Host prod-* preprod-*
  ProxyJump bastion
  ...
```

`ProxyJump` fait partie des mots-clés effectivement supportés par Wave.

### 4.7 Test de validation

```bash
for h in prod-apps prod-mock prod-regie prod-ntp \
         preprod-apps preprod-mock preprod-regie preprod-ntp; do
  printf '%-15s ' "$h"
  ssh -o BatchMode=yes -o ConnectTimeout=5 "$h" 'hostname' 2>&1 | tail -1
done
```

Les 8 lignes doivent renvoyer un nom d'hôte. Ne pas passer à la suite tant que ce n'est pas le cas.

### 4.8 Ajouter une nouvelle grappe

Script de génération à adapter :

```bash
gen_grappe() {
  local prefix="$1" octet="$2"
  local roles=(apps mock regie ntp)
  local last=(80 81 82 83)
  echo "# ---------- GRAPPE ${octet} ----------"
  for i in 0 1 2 3; do
    printf 'Host %s-%s\n  HostName 10.29.%s.%s\n\n' \
      "$prefix" "${roles[$i]}" "$octet" "${last[$i]}"
  done
}

gen_grappe g3 3 >> ~/.ssh/config
```

Penser ensuite à étendre le pattern du bloc wildcard : `Host prod-* preprod-* g3-*`.

---

## 5. Wave Terminal

### 5.1 Localiser les fichiers de configuration

Ne pas deviner le chemin, le demander à Wave :

```bash
wsh wavepath config     # répertoire de configuration
wsh wavepath log        # fichier de log (utile en dépannage)
```

Fichiers concernés dans ce répertoire :

| Fichier             | Rôle                                             |
| ------------------- | ------------------------------------------------ |
| `settings.json`     | Réglages globaux                                 |
| `connections.json`  | Réglages par connexion                           |
| `termthemes.json`   | Thèmes de terminal personnalisés                 |
| `widgets.json`      | Widgets de la barre latérale                     |

Édition depuis Wave : `wsh editconfig` (ouvre `settings.json`), ou `wsh editconfig connections.json`.

### 5.2 Corriger le blocage `wsh` existant

Symptôme : bandeau *« wsh is not installed for this connection »*, widgets `files` / `sysinfo` indisponibles sur la connexion.

Cause : une entrée a été écrite dans `connections.json` désactivant `wsh` pour cette connexion — soit après un refus au prompt d'installation, soit après un échec.

**Procédure :**

1. Ouvrir `connections.json`.
2. Rechercher les deux orthographes — la documentation officielle est incohérente sur ce point, les deux peuvent exister dans un fichier :
   - `"conn:wshenabled": false`
   - `"conn:enablewsh": false`
3. Supprimer la ligne, ou la passer à `true`.
4. Redémarrer Wave.
5. Reconnecter le bloc. Si l'installation ne se relance pas : `wsh conn reinstall <USER>@prod-apps`.

### 5.3 `connections.json` complet

Le nom de la clé doit correspondre **exactement** à ce qui s'affiche dans le menu déroulant des connexions (généralement `<USER>@prod-apps`).

> **Point de vigilance sur la structure du fichier** : la documentation Wave montre deux formes selon les pages — un objet plat dont les clés sont les connexions, et une forme enveloppée dans `{"connections": { … }}`. **Conserver la structure déjà présente dans votre fichier** et n'ajouter que les clés internes. En cas de doute, modifier une seule connexion, redémarrer Wave, vérifier que le réglage prend effet, puis dupliquer.

```json
{
  "<USER>@prod-apps": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "<theme-prod-rouge>",
    "display:order": 1,
    "cmd:env": { "GRAPPE": "1", "ENVIRONNEMENT": "prod", "ROLE": "apps" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@prod-mock": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "<theme-prod-rouge>",
    "display:order": 2,
    "cmd:env": { "GRAPPE": "1", "ENVIRONNEMENT": "prod", "ROLE": "mock" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@prod-regie": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "<theme-prod-rouge>",
    "display:order": 3,
    "cmd:env": { "GRAPPE": "1", "ENVIRONNEMENT": "prod", "ROLE": "regie" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@prod-ntp": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "<theme-prod-rouge>",
    "display:order": 4,
    "cmd:env": { "GRAPPE": "1", "ENVIRONNEMENT": "prod", "ROLE": "ntp" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },

  "<USER>@preprod-apps": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "warmyellow",
    "display:order": 11,
    "cmd:env": { "GRAPPE": "8", "ENVIRONNEMENT": "preprod", "ROLE": "apps" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@preprod-mock": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "warmyellow",
    "display:order": 12,
    "cmd:env": { "GRAPPE": "8", "ENVIRONNEMENT": "preprod", "ROLE": "mock" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@preprod-regie": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "warmyellow",
    "display:order": 13,
    "cmd:env": { "GRAPPE": "8", "ENVIRONNEMENT": "preprod", "ROLE": "regie" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  },
  "<USER>@preprod-ntp": {
    "conn:wshenabled": true,
    "conn:askbeforewshinstall": false,
    "term:durable": true,
    "term:theme": "warmyellow",
    "display:order": 14,
    "cmd:env": { "GRAPPE": "8", "ENVIRONNEMENT": "preprod", "ROLE": "ntp" },
    "cmd:initscript.zsh": "~/.waveterm/init-remote.zsh"
  }
}
```

### 5.4 Référence des clés utilisées

| Clé                        | Effet                                                                                                  |
| -------------------------- | ------------------------------------------------------------------------------------------------------ |
| `conn:wshenabled`          | Autorise l'usage de `wsh` sur la connexion. À `false`, `wsh` ne sera **jamais** utilisé. Défaut `true`. |
| `conn:askbeforewshinstall` | À `false`, `wsh` s'installe sans demander confirmation. **C'est la clé qui évite de reproduire le blocage** sur les 7 autres VM. Défaut `true`. |
| `conn:wshpath`             | Chemin de l'exécutable `wsh` sur la machine distante. Défaut `~/.waveterm/bin/wsh`.                     |
| `conn:shellpath`           | Force le shell distant. À renseigner si le shell par défaut n'est ni bash, zsh, pwsh ni fish.           |
| `conn:ignoresshconfig`     | Ignore `~/.ssh/config` pour cette connexion. **Ne pas activer** dans ce montage.                        |
| `term:durable`             | Active les sessions durables pour la connexion (voir 5.5).                                             |
| `term:theme`               | Thème de terminal spécifique à la connexion.                                                           |
| `term:fontsize`            | Taille de police spécifique à la connexion.                                                            |
| `display:order`            | Ordre d'affichage dans le menu déroulant (flottant, défaut `0`).                                       |
| `display:hidden`           | Masque une connexion du menu (utile pour les entrées `git@…` du `~/.ssh/config`).                      |
| `cmd:env`                  | Variables d'environnement injectées. **Nécessite `wsh`.**                                              |
| `cmd:initscript.zsh`       | Script joué à l'initialisation d'un shell zsh. **Nécessite `wsh`.**                                    |

Autres variantes du script d'init : `cmd:initscript` (tous shells), `.sh` (bash + zsh), `.bash`, `.pwsh`, `.fish`. La plus spécifique au shell courant l'emporte.

### 5.5 Sessions durables

Fonctionnalité introduite en v0.14, **désactivée par défaut** sur les connexions SSH. Wave lance un gestionnaire de jobs léger sur le serveur distant, à la manière de tmux, qui maintient le shell indépendamment de la connexion Wave, met en tampon la sortie pendant la déconnexion et permet le rattachement automatique. Sont préservés : répertoire courant, variables d'environnement, historique du shell, jobs en cours et scrollback complet.

C'est la réponse adaptée à un accès via tunnel WireGuard, où la coupure réseau est un événement normal.

**Activation globale** dans `settings.json` :

```json
{
  "term:durable": true
}
```

La hiérarchie de priorité est : réglage du bloc > réglage de la connexion > réglage global.

**Pilotage à l'usage :**

- Icône bouclier dans l'en-tête du terminal : `Standard`, `Durable (Attaché)`, `Durable (Détaché)`, `Durable (En attente)`. Survol → détails et actions.
- Clic droit sur le terminal → Advanced → Session Durability.
- En ligne de commande : `wsh setmeta term:durable=true` ou `false`.

**Points d'attention :**

- Basculer entre mode standard et durable **redémarre le shell** : tout processus en cours est interrompu.
- Fermer un bloc, changer sa connexion ou supprimer l'onglet **termine** la session distante.
- Un bloc fermé alors qu'on était déconnecté laisse la session tourner ; Wave nettoie ces sessions orphelines à la reconnexion suivante.
- Chaque session durable maintient un processus Go léger sur la VM. À prendre en compte sur `ntp` si la machine est dimensionnée au minimum.

### 5.6 Script d'initialisation distant

Fichier `~/.waveterm/init-remote.zsh` **sur chaque VM** :

```zsh
# Repères visuels dans le prompt
export PS1="%F{yellow}[${ENVIRONNEMENT}/${ROLE}]%f %~ %# "

# Alias applicatifs
alias logs='sudo journalctl -u <service> -f'
alias status='systemctl status <service>'
alias conf='cd /etc/<service>'
```

Déploiement :

```bash
for h in prod-apps prod-mock prod-regie prod-ntp \
         preprod-apps preprod-mock preprod-regie preprod-ntp; do
  ssh "$h" 'mkdir -p ~/.waveterm'
  scp ~/init-remote.zsh "$h":~/.waveterm/init-remote.zsh
done
```

> Le script d'init n'est appliqué que si `wsh` est actif sur la connexion.

### 5.7 Règle impérative sur le `.zshrc` distant

Wave détecte la plateforme distante en exécutant une commande qui repose sur la sortie de `uname -sm`. **Toute écriture parasite au démarrage du shell distant casse cette détection** et fait échouer l'installation de `wsh` (erreur typique : `unsupported wsh platform: -`).

Sur chaque VM, encadrer tout affichage :

```zsh
# ~/.zshrc — sur les VM distantes
if [[ $- == *i* ]]; then
  # Uniquement en mode interactif : bannières, fastfetch, messages d'accueil…
  echo "Bienvenue sur ${HOST}"
fi
```

Vérification, qui doit renvoyer **uniquement** la ligne `uname` :

```bash
ssh prod-apps 'uname -sm'
```

### 5.8 Organisation des workspaces

C'est le principal gain d'ergonomie du montage.

1. Créer un workspace **PROD** et un workspace **PRÉ-PROD**.
2. Dans chacun, un onglet avec 4 blocs terminal en grille 2×2, un par rôle (`apps`, `mock`, `regie`, `ntp`).
3. La disposition est persistée : la grappe entière se rouvre d'un clic.
4. Ajouter dans le même onglet un bloc `files` pointant sur le répertoire applicatif (nécessite `wsh`) et un bloc `sysinfo` sur `apps`.

Bascule de connexion d'un bloc existant, sans le recréer :

```bash
wsh ssh prod-regie
```

### 5.9 Réglages globaux `settings.json`

```json
{
  "term:durable": true,
  "term:bellindicator": true,
  "autoupdate:enabled": true
}
```

`term:bellindicator` (actif par défaut depuis la v0.14) allume un badge sur le bloc et l'onglet quand le terminal sonne — pratique pour repérer la fin d'un déploiement long sur un bloc en arrière-plan.

---

## 6. VS Code Remote

### 6.1 Installation

Extension **Remote - SSH** (`ms-vscode-remote.remote-ssh`), ou le pack **Remote Development** (`ms-vscode-remote.vscode-remote-extensionpack`) qui inclut aussi Dev Containers et WSL.

### 6.2 Aucune configuration d'hôte à refaire

Remote-SSH lit le même `~/.ssh/config`. Les 8 hôtes déclarés en section 4 apparaissent directement dans la palette :

`F1` → **Remote-SSH: Connect to Host** → `prod-apps`

Un accès direct est également disponible via l'icône Remote dans la barre latérale (Remote Explorer → SSH).

### 6.3 `settings.json` utilisateur

```jsonc
{
  // Fichier de config SSH utilisé (par défaut ~/.ssh/config)
  "remote.SSH.configFile": "~/.ssh/config",

  // Évite la détection d'OS à chaque connexion : gain de temps notable
  "remote.SSH.remotePlatform": {
    "prod-apps": "linux",
    "prod-mock": "linux",
    "prod-regie": "linux",
    "prod-ntp": "linux",
    "preprod-apps": "linux",
    "preprod-mock": "linux",
    "preprod-regie": "linux",
    "preprod-ntp": "linux"
  },

  // Tunnel lent au montage : marge sur le délai de connexion
  "remote.SSH.connectTimeout": 60,

  // Reconnexion automatique après coupure du tunnel
  "remote.SSH.maxReconnectionAttempts": 5,

  // VM sans accès Internet sortant : le serveur VS Code est téléchargé
  // en local puis copié via SSH. Indispensable sur un IaaS cloisonné.
  "remote.SSH.localServerDownload": "always",

  // Extensions installées automatiquement sur CHAQUE machine distante
  "remote.SSH.defaultExtensions": [
    "ms-azuretools.vscode-docker",
    "redhat.vscode-yaml",
    "timonwong.shellcheck"
  ],

  // Affiche le terminal de login : utile pour saisir une passphrase
  "remote.SSH.showLoginTerminal": true
}
```

> `remote.SSH.localServerDownload` : valeurs `auto` (défaut), `always`, `off`. Si les VM n'ont pas de route vers Internet, `always` est le seul mode qui fonctionne.

### 6.4 Limites structurelles à connaître

- **Une fenêtre VS Code = un hôte distant.** Les workspaces multi-racines ne peuvent pas couvrir plusieurs hôtes SSH simultanément. Pour travailler sur `apps` et `regie` en parallèle : deux fenêtres. C'est précisément là que Wave complète VS Code, en agrégeant les 4 VM dans un seul onglet.
- **Le serveur VS Code s'installe sur chaque VM** dans `~/.vscode-server` (plusieurs centaines de Mo, plus les extensions). À ne pas déployer sur `ntp` si la machine est petite : y préférer un terminal Wave.
- **Les extensions sont de deux natures** : « UI » (thèmes, raccourcis) restent locales, « Workspace » (langages, linters, debuggers) s'installent côté distant. La colonne d'installation dans le panneau Extensions indique explicitement de quel côté chacune se trouve.

### 6.5 Réglages par machine distante

Une fois connecté, `F1` → **Preferences: Open Remote Settings (SSH: prod-apps)** produit un fichier valable uniquement sur cette VM. Utile pour y placer les chemins d'interpréteurs ou les réglages de linter propres à la machine, sans polluer la configuration locale.

### 6.6 Redirection de ports

VS Code détecte les ports ouverts par les processus distants et propose la redirection automatiquement. Vue **Ports** (à côté du Terminal) → **Forward a Port** pour un ajout manuel.

Permet d'attaquer une application tournant sur `prod-apps` depuis `http://localhost:<port>` sans exposer de port supplémentaire côté VM.

### 6.7 Développement local en conteneur

Le développement quotidien (build, tests, serveur de dev) reste dans l'environnement conteneurisé local : les VM servent au déploiement, à la vérification et au diagnostic, pas à l'édition à chaud.

Pour rattacher VS Code au conteneur de développement local : extension **Dev Containers**, `F1` → **Dev Containers: Attach to Running Container**. Avec un backend Podman, renseigner au préalable :

```json
{
  "dev.containers.dockerPath": "podman"
}
```

Sur les VM comme en local, invoquer les outils de build via `npx` plutôt que par une installation globale, pour que la version utilisée soit celle épinglée par le projet et non celle du poste.

---

## 7. Garde-fous production

La grappe 1 est en production. Le risque principal du montage est l'action exécutée dans le mauvais bloc.

| Mesure                        | Mise en œuvre                                                                     |
| ----------------------------- | --------------------------------------------------------------------------------- |
| Thème rouge sur les 4 VM prod | `term:theme` dans `connections.json` (section 5.3)                                 |
| Prompt explicite              | `PS1` alimenté par `$ENVIRONNEMENT` via `cmd:env` + script d'init (section 5.6)     |
| Workspaces séparés            | Jamais de bloc prod et pré-prod dans le même onglet                                |
| Ordre du menu déroulant       | `display:order` : prod en 1-4, pré-prod en 11-14, jamais adjacents                 |
| Confirmation manuelle         | Alias distants destructifs préfixés (`prod-restart`, jamais `restart`)             |

Définir un thème rouge dédié dans `termthemes.json`, puis référencer son nom dans `term:theme`. La liste des thèmes disponibles est consultable dans les réglages de Wave (Terminal Theme) — reprendre un nom existant si la création d'un thème personnalisé n'est pas souhaitée.

---

## 8. Dépannage

### 8.1 Activer les traces de connexion

Dans le bloc Wave concerné : menu du bloc → **Debug Connection** → `Info` ou `Verbose`. Les traces s'affichent directement dans le terminal pendant la connexion.

Log complet : `wsh wavepath log`.

### 8.2 Table de diagnostic

| Symptôme                                    | Cause probable                                                     | Correction                                                                 |
| ------------------------------------------- | ------------------------------------------------------------------ | -------------------------------------------------------------------------- |
| `wsh is not installed for this connection`  | `conn:wshenabled` (ou `conn:enablewsh`) à `false`                   | Section 5.2                                                                |
| `unsupported wsh platform: -`               | Sortie parasite au démarrage du shell distant                       | Section 5.7                                                                |
| Installation de `wsh` échoue, shell vide dans les traces | `AllowTcpForwarding no` dans `/etc/ssh/sshd_config` de la VM | Passer à `yes` ou `local`, redémarrer `sshd`, redémarrer Wave              |
| `wsh` indisponible, shell exotique          | Shell distant hors bash / zsh / pwsh / fish                         | `conn:shellpath` vers un shell supporté, ou `chsh` sur la VM               |
| Connexion figée après coupure du tunnel     | Session non durable                                                 | `term:durable` (section 5.5)                                               |
| Session durable en état `Lost`              | Redémarrage de la VM ou gestionnaire de jobs tué                    | « Restart Session » depuis le bouclier                                     |
| Session durable qui ne se rattache pas      | Connexion SSH sous-jacente coupée                                   | Clic droit → Advanced → Force Restart Controller                           |
| Aucun hôte dans VS Code Remote              | `Match` présent dans `~/.ssh/config`, ou chemin non standard        | Retirer `Match` ; vérifier `remote.SSH.configFile`                         |
| VS Code bloqué sur « Setting up SSH Host »  | VM sans accès Internet pour télécharger le serveur                  | `"remote.SSH.localServerDownload": "always"`                               |
| Tout est injoignable                        | Tunnel WireGuard non monté                                          | `vpn-up` puis `grappe-check 1`                                             |

### 8.3 Commandes de reprise Wave

```bash
wsh conn status                    # état de toutes les connexions
wsh conn ensure prod-apps          # réamorce sans recréer le bloc
wsh conn reinstall prod-apps       # réinstalle wsh sur la machine distante
wsh conn disconnect prod-apps
wsh conn connect prod-apps
```

---

## 9. Checklist de mise en place

```
PRÉREQUIS
[ ] WireGuard installé, tunnel monté, grappe-check 1 et 8 au vert
[ ] Wave ≥ 0.14
[ ] VS Code + extension Remote - SSH

SSH
[ ] Clé ed25519 générée
[ ] Clé déployée sur les 8 VM
[ ] ~/.ssh/config écrit (blocs spécifiques AVANT le wildcard)
[ ] Aucun mot-clé Match dans le fichier
[ ] Permissions 700 / 600 appliquées
[ ] Les 8 hôtes répondent au test de la section 4.7

VM (à faire sur chacune des 8)
[ ] .zshrc silencieux en mode non interactif — ssh <host> 'uname -sm' propre
[ ] AllowTcpForwarding à yes ou local dans /etc/ssh/sshd_config
[ ] ~/.waveterm/init-remote.zsh déployé

WAVE
[ ] connections.json nettoyé des conn:wshenabled / conn:enablewsh à false
[ ] connections.json complété pour les 8 connexions
[ ] conn:askbeforewshinstall à false partout
[ ] settings.json : term:durable à true
[ ] Thème rouge appliqué aux 4 connexions prod
[ ] Workspace PROD créé (4 blocs)
[ ] Workspace PRÉ-PROD créé (4 blocs)
[ ] wsh conn status : les 8 connexions avec wsh actif

VS CODE
[ ] remote.SSH.remotePlatform renseigné pour les 8 hôtes
[ ] remote.SSH.localServerDownload adapté au cloisonnement réseau
[ ] Connexion testée sur preprod-apps
[ ] Serveur VS Code volontairement NON déployé sur les VM ntp
```

---

## 10. Aide-mémoire

### Poste local

```bash
vpn-up                       # monter le tunnel
grappe-check 1               # joignabilité prod
ssh prod-apps                # connexion directe hors Wave
```

### Wave

| Commande                          | Effet                                       |
| --------------------------------- | ------------------------------------------- |
| `wsh ssh prod-regie`              | Bascule la connexion du bloc courant        |
| `wsh conn status`                 | État des connexions                         |
| `wsh conn ensure <host>`          | Réamorce une connexion                      |
| `wsh conn reinstall <host>`       | Réinstalle `wsh` à distance                 |
| `wsh setmeta term:durable=true`   | Passe le bloc en session durable            |
| `wsh view <fichier>`              | Prévisualise un fichier distant             |
| `wsh edit <fichier>`              | Édite un fichier distant dans Wave          |
| `wsh wavepath config`             | Chemin des fichiers de configuration        |
| `wsh wavepath log`                | Chemin du fichier de log                    |
| `wsh editconfig connections.json` | Ouvre `connections.json` dans Wave          |

### Variables injectées dans les sessions distantes

`TERM_PROGRAM=waveterm`, `WAVETERM=1`, `WAVETERM_CONN`, `WAVETERM_BLOCKID`, `WAVETERM_TABID`, `WAVETERM_WORKSPACEID`, `WAVETERM_CLIENTID`, `WAVETERM_VERSION` — plus les variables définies dans `cmd:env`.

### Références

- Connexions Wave : <https://docs.waveterm.dev/connections>
- Sessions durables : <https://docs.waveterm.dev/durable-sessions>
- Référence `wsh` : <https://docs.waveterm.dev/wsh-reference>
- Configuration Wave : <https://docs.waveterm.dev/config>
- VS Code Remote-SSH : <https://code.visualstudio.com/docs/remote/ssh>
