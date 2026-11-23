#!/usr/bin/env bash
# Crée le projet @ton-org/dev-proxy complet en une seule commande.
# Usage : bash create-dev-proxy.sh [dossier] [scope]
#   dossier : dossier à créer            (défaut : dev-proxy)
#   scope   : groupe racine GitLab       (défaut : ton-org)
#   GITLAB_HOST=gitlab.mon-entreprise.fr bash create-dev-proxy.sh   → remplace gitlab.interne
set -euo pipefail

DIR="${1:-dev-proxy}"
SCOPE="${2:-ton-org}"
HOST="${GITLAB_HOST:-gitlab.interne}"

if [ -e "$DIR" ]; then
  echo "Erreur : '$DIR' existe déjà." >&2
  exit 1
fi

mkdir -p "$DIR/src" "$DIR/test"
cd "$DIR"

cat > 'package.json' <<'__DEVPROXY_EOF__'
{
  "name": "@ton-org/dev-proxy",
  "version": "0.1.0",
  "description": "Configuration de proxy partagée pour les ng serve des projets Angular (local ou VM de dev)",
  "type": "module",
  "exports": {
    ".": {
      "types": "./src/index.d.ts",
      "default": "./src/index.mjs"
    }
  },
  "files": [
    "src"
  ],
  "engines": {
    "node": ">=20"
  },
  "scripts": {
    "test": "node --test"
  },
  "license": "UNLICENSED"
}
__DEVPROXY_EOF__

cat > '.gitignore' <<'__DEVPROXY_EOF__'
node_modules/
*.tgz
# généré par la CI avec le job token, ne jamais committer
.npmrc
__DEVPROXY_EOF__

cat > '.gitlab-ci.yml' <<'__DEVPROXY_EOF__'
stages:
  - test
  - publish

default:
  image: node:22-alpine
  # Si votre GitLab utilise une CA interne, ajoutez-la ici, par ex. :
  # variables:
  #   NODE_EXTRA_CA_CERTS: /etc/ssl/certs/ca-interne.crt

test:
  stage: test
  script:
    - npm test
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
    - if: $CI_COMMIT_TAG

publish:
  stage: publish
  needs: [test]
  rules:
    # Uniquement sur un tag de version : v1.2.3 ou v1.2.3-rc.1
    - if: $CI_COMMIT_TAG =~ /^v\d+\.\d+\.\d+(-[0-9A-Za-z.-]+)?$/
  script:
    # 1. Le tag doit correspondre à la version de package.json
    - PKG_VERSION="$(node -p "require('./package.json').version")"
    - |
      if [ "v${PKG_VERSION}" != "${CI_COMMIT_TAG}" ]; then
        echo "Tag ${CI_COMMIT_TAG} ≠ version package.json (${PKG_VERSION}). Utilisez 'npm version'." >&2
        exit 1
      fi
    # 2. Authentification au registre npm du projet avec le job token
    - REGISTRY="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/packages/npm/"
    - echo "${REGISTRY#https?}:_authToken=${CI_JOB_TOKEN}" > .npmrc
    # 3. Pré-release (v1.2.3-rc.1) → dist-tag "next", sinon "latest"
    - NPM_TAG=latest
    - case "$CI_COMMIT_TAG" in *-*) NPM_TAG=next ;; esac
    - npm publish --registry "${REGISTRY}" --tag "${NPM_TAG}"
__DEVPROXY_EOF__

cat > 'README.md' <<'__DEVPROXY_EOF__'
# @ton-org/dev-proxy

Proxy de dev partagé pour les `ng serve` de tous les projets Angular.
Par défaut, chaque route part vers la **VM de dev** ; chaque dev choisit ce qu'il fait tourner **en local**, sans toucher aux fichiers versionnés.

> Remplacez `ton-org` par le nom de votre **groupe racine GitLab** et `gitlab.interne` par votre hôte.

## Ajouter / modifier un service

Éditer `src/services.mjs`, puis publier une nouvelle version (voir « Publier »).

## Publier

La CI publie automatiquement sur le registre npm du projet GitLab quand un tag `vX.Y.Z` est poussé.

```bash
npm test
npm version minor          # ou patch / major → commit + tag vX.Y.Z
git push --follow-tags     # la CI teste puis publie
```

Pré-release : `npm version prerelease --preid rc` → publiée avec le dist-tag `next`.

## Utiliser dans un projet Angular

1. `.npmrc` du projet (versionné, sans token) :
   ```
   @ton-org:registry=https://gitlab.interne/api/v4/packages/npm/
   ```
2. `~/.npmrc` de chaque dev (token personnel, scope `read_api`) :
   ```
   //gitlab.interne/api/v4/packages/npm/:_authToken=glpat-xxxxxxxx
   ```
3. Installer : `npm i -D @ton-org/dev-proxy`
4. `proxy.conf.mjs` :
   ```js
   import { createProxy } from '@ton-org/dev-proxy';
   export default createProxy(['apps-b', 'api']);
   ```
5. `angular.json` → `serve.options.proxyConfig: "proxy.conf.mjs"`

### ⚠️ Ne jamais proxifier son propre chemin

Dans le projet `apps-b` lui-même, `/apps-b` ne doit **pas** passer par le proxy :
le proxy s'exécute avant le serveur de dev et intercepterait `main.js`, `styles.css`…
(→ 404 / page blanche, ou boucle si `apps-b` est en local).

```js
// proxy.conf.mjs du projet apps-b
import { createProxy } from '@ton-org/dev-proxy';
export default createProxy(['apps-b', 'api'], { self: 'apps-b' }); // apps-b est filtré
```

## Choisir local / VM (côté dev)

| Moyen | Exemple | Portée |
|---|---|---|
| Variable d'env | `DEV_LOCAL=apps-b,api ng serve` | ce lancement |
| Fichier perso | `~/.config/dev-proxy.json` → `{ "local": ["apps-b"], "vmUrl": "https://ma-vm" }` | permanent |
| Autre VM | `DEV_VM_URL=https://autre-vm ng serve` | ce lancement |

Au démarrage, `ng serve` affiche la cible de chaque route :

```
[dev-proxy] /apps-b         → http://127.0.0.1:4291  (local)
[dev-proxy] /api            → https://dev-vm.interne  (VM)
```

## CI des projets consommateurs

```yaml
before_script:
  - echo "@ton-org:registry=${CI_API_V4_URL}/packages/npm/" > .npmrc
  - echo "${CI_API_V4_URL#https?}/packages/npm/:_authToken=${CI_JOB_TOKEN}" >> .npmrc
  - npm ci
```

Le projet `dev-proxy` doit autoriser leur job token :
*Settings → CI/CD → Job token permissions* → ajouter le groupe (ou les projets) consommateurs.
__DEVPROXY_EOF__

cat > 'src/services.mjs' <<'__DEVPROXY_EOF__'
/**
 * Registre unique des services exposés derrière le proxy de dev.
 * C'est le SEUL fichier à modifier quand un service apparaît ou change de port.
 *
 * - path      : préfixe d'URL côté navigateur (ex. /apps-b)
 * - localPort : port du `ng serve` (ou du backend) quand le service tourne en local
 * - vmUrl     : (optionnel) cible propre à ce service sur la VM ;
 *               sinon DEV_VM_URL, puis vmUrl du fichier utilisateur, puis defaultVmUrl
 */
export const defaultVmUrl = 'https://dev-vm.interne';

export const services = {
  'apps-b': { path: '/apps-b', localPort: 4291 },
  api: { path: '/api', localPort: 8080 },
};
__DEVPROXY_EOF__

cat > 'src/index.mjs' <<'__DEVPROXY_EOF__'
import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { join } from 'node:path';
import { services as defaultServices, defaultVmUrl } from './services.mjs';

export { services, defaultVmUrl } from './services.mjs';

/** Fichier de préférences propre à chaque dev (hors git). */
export const userConfigPath = join(homedir(), '.config', 'dev-proxy.json');

function readUserConfig(path) {
  if (!existsSync(path)) return {};
  try {
    return JSON.parse(readFileSync(path, 'utf8'));
  } catch (e) {
    throw new Error(`dev-proxy : ${path} n'est pas un JSON valide (${e.message})`);
  }
}

/**
 * Calcule la cible de chaque service demandé.
 * Priorité : variables d'env (DEV_LOCAL, DEV_VM_URL) > ~/.config/dev-proxy.json > défauts.
 */
export function resolveTargets(names, opts = {}) {
  const env = opts.env ?? process.env;
  const registry = opts.services ?? defaultServices;
  const user = readUserConfig(opts.configPath ?? userConfigPath);

  const localList =
    env.DEV_LOCAL !== undefined
      ? env.DEV_LOCAL.split(',').map((s) => s.trim()).filter(Boolean)
      : user.local ?? [];
  const local = new Set(localList);
  const vmUrl = env.DEV_VM_URL ?? user.vmUrl ?? defaultVmUrl;

  for (const n of local) {
    if (!registry[n]) {
      console.warn(`[dev-proxy] "${n}" déclaré en local mais absent du registre (faute de frappe ?)`);
    }
  }

  // Un projet ne doit jamais proxifier son propre chemin : sinon le proxy
  // intercepte ses propres fichiers (main.js, styles…) avant le serveur de dev.
  const self = new Set([opts.self ?? []].flat());
  const wanted = names.filter((name) => {
    if (!self.has(name)) return true;
    if (!opts.silent) console.warn(`[dev-proxy] "${name}" ignoré : c'est le projet courant`);
    return false;
  });

  return wanted.map((name) => {
    const s = registry[name];
    if (!s) {
      throw new Error(
        `dev-proxy : service inconnu "${name}". Services connus : ${Object.keys(registry).join(', ')}`,
      );
    }
    const isLocal = local.has(name);
    return {
      name,
      path: s.path,
      isLocal,
      target: isLocal ? `http://127.0.0.1:${s.localPort}` : s.vmUrl ?? vmUrl,
    };
  });
}

/**
 * Construit l'objet attendu par `proxyConfig` d'Angular (Vite ou webpack).
 * Usage dans proxy.conf.mjs :  export default createProxy(['apps-b', 'api']);
 */
export function createProxy(names, opts = {}) {
  const conf = {};
  for (const r of resolveTargets(names, opts)) {
    const entry = { target: r.target, secure: false, changeOrigin: true, ws: true };
    // Vite : "/x" ne matche que "/x" exactement, "/x/**" matche tout le sous-arbre.
    conf[r.path] = { ...entry };
    conf[`${r.path}/**`] = { ...entry };
    if (!opts.silent) {
      console.log(`[dev-proxy] ${r.path.padEnd(14)} → ${r.target}${r.isLocal ? '  (local)' : '  (VM)'}`);
    }
  }
  return conf;
}
__DEVPROXY_EOF__

cat > 'src/index.d.ts' <<'__DEVPROXY_EOF__'
export interface ServiceDef {
  path: string;
  localPort: number;
  vmUrl?: string;
}

export interface ProxyOptions {
  /** Variables d'environnement à utiliser (défaut : process.env). */
  env?: Record<string, string | undefined>;
  /** Chemin du fichier de préférences (défaut : ~/.config/dev-proxy.json). */
  configPath?: string;
  /** Registre de services à utiliser (défaut : celui du package). */
  services?: Record<string, ServiceDef>;
  /** Service(s) servi(s) par le projet courant : jamais proxifiés. */
  self?: string | string[];
  /** Ne pas afficher le récapitulatif au démarrage. */
  silent?: boolean;
}

export interface ResolvedTarget {
  name: string;
  path: string;
  isLocal: boolean;
  target: string;
}

export interface ProxyEntry {
  target: string;
  secure: boolean;
  changeOrigin: boolean;
  ws: boolean;
}

export const services: Record<string, ServiceDef>;
export const defaultVmUrl: string;
export const userConfigPath: string;

export function resolveTargets(names: string[], opts?: ProxyOptions): ResolvedTarget[];
export function createProxy(names: string[], opts?: ProxyOptions): Record<string, ProxyEntry>;
__DEVPROXY_EOF__

cat > 'test/index.test.mjs' <<'__DEVPROXY_EOF__'
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createProxy, resolveTargets, defaultVmUrl } from '../src/index.mjs';

const noFile = join(tmpdir(), 'dev-proxy-inexistant.json');
const base = { configPath: noFile, silent: true };

function userFile(content) {
  const dir = mkdtempSync(join(tmpdir(), 'dev-proxy-'));
  const p = join(dir, 'dev-proxy.json');
  writeFileSync(p, JSON.stringify(content));
  return p;
}

test('par défaut, tout part vers la VM', () => {
  const [r] = resolveTargets(['apps-b'], { ...base, env: {} });
  assert.equal(r.isLocal, false);
  assert.equal(r.target, defaultVmUrl);
});

test('DEV_LOCAL bascule un service en local', () => {
  const [b, api] = resolveTargets(['apps-b', 'api'], { ...base, env: { DEV_LOCAL: 'apps-b' } });
  assert.equal(b.target, 'http://127.0.0.1:4291');
  assert.equal(api.isLocal, false);
});

test('DEV_VM_URL remplace la VM par défaut', () => {
  const [r] = resolveTargets(['api'], { ...base, env: { DEV_VM_URL: 'https://autre-vm' } });
  assert.equal(r.target, 'https://autre-vm');
});

test('le fichier utilisateur est lu, mais DEV_LOCAL a priorité', () => {
  const configPath = userFile({ local: ['api'], vmUrl: 'https://ma-vm' });
  const [b, api] = resolveTargets(['apps-b', 'api'], { configPath, silent: true, env: {} });
  assert.equal(api.target, 'http://127.0.0.1:8080');
  assert.equal(b.target, 'https://ma-vm');

  const [b2, api2] = resolveTargets(['apps-b', 'api'], {
    configPath,
    silent: true,
    env: { DEV_LOCAL: 'apps-b' },
  });
  assert.equal(b2.isLocal, true);
  assert.equal(api2.isLocal, false);
});

test('service inconnu → erreur explicite', () => {
  assert.throws(() => createProxy(['nope'], { ...base, env: {} }), /service inconnu "nope"/);
});

test('self : le projet courant n\'est jamais proxifié', () => {
  const conf = createProxy(['apps-b', 'api'], { ...base, env: {}, self: 'apps-b' });
  assert.deepEqual(Object.keys(conf), ['/api', '/api/**']);
});

test('createProxy génère le chemin exact et le sous-arbre', () => {
  const conf = createProxy(['apps-b'], { ...base, env: {} });
  assert.deepEqual(Object.keys(conf), ['/apps-b', '/apps-b/**']);
  assert.equal(conf['/apps-b/**'].ws, true);
  assert.notEqual(conf['/apps-b'], conf['/apps-b/**']);
});
__DEVPROXY_EOF__

# Personnalisation du scope et de l'hôte GitLab
if [ "$SCOPE" != "ton-org" ] || [ "$HOST" != "gitlab.interne" ]; then
  for f in package.json README.md .gitlab-ci.yml src/*.mjs src/*.ts test/*.mjs; do
    sed -i "s/ton-org/${SCOPE}/g; s/gitlab\.interne/${HOST}/g" "$f"
  done
fi

# Vérification
if command -v node >/dev/null 2>&1; then
  npm test --silent && echo "✔ Tests OK"
else
  echo "⚠ Node absent : tests non lancés"
fi

# Dépôt git
if command -v git >/dev/null 2>&1; then
  git init -q -b main
  git add .
  echo "✔ Dépôt git initialisé (fichiers indexés, pas encore commités)"
fi

cat <<EOF

Projet créé dans : $(pwd)

Étapes suivantes :
  git commit -m "feat: init dev-proxy"
  git remote add origin git@${HOST}:${SCOPE}/tooling/dev-proxy.git
  git push -u origin main
  git tag v0.1.0 && git push --tags      # → la CI publie le package
EOF
