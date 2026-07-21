#!/usr/bin/env bash
set -euo pipefail

NEXUS_BASE="https://nexus.exemple.local"
GROUP_REPO="npm-group"
THIRDPARTY_REPO="npm-thirdparty-hosted"
NPM_USER="${NEXUS_USER}"
NPM_PASS="${NEXUS_PASS}"
WORKDIR=".nexus-promote"
mkdir -p "$WORKDIR"

export NPM_CONFIG_USERCONFIG="$WORKDIR/.npmrc"

AUTH_B64="$(printf '%s:%s' "$NPM_USER" "$NPM_PASS" | base64 | tr -d '
')"

cat > "$NPM_CONFIG_USERCONFIG" <<EOF
registry=${NEXUS_BASE}/repository/${GROUP_REPO}/
always-auth=true
_auth=${AUTH_B64}
email=build@noreply.local
EOF

jq -r '
  .. | objects | select(has("version") and has("resolved")) |
  @base64
' package-lock.json | while read -r row; do
  obj="$(printf '%s' "$row" | base64 -d)"
  name="$(printf '%s' "$obj" | jq -r '.name // empty')"
  version="$(printf '%s' "$obj" | jq -r '.version')"
  resolved="$(printf '%s' "$obj" | jq -r '.resolved')"

  if [ -z "$name" ] || [ "$name" = "null" ]; then
    continue
  fi

  pkg_path="$(node -e "console.log(encodeURIComponent(process.argv[1]).replace('%40','@'))" "$name")"
  check_url="${NEXUS_BASE}/service/rest/v1/search/assets?repository=${THIRDPARTY_REPO}&name=${pkg_path}&version=${version}"

  exists="$(curl -su "$NPM_USER:$NPM_PASS" "$check_url" | jq '.items | length')"
  if [ "$exists" != "0" ]; then
    echo "already present: $name@$version"
    continue
  fi

  file="$WORKDIR/${name##*/}-${version}.tgz"
  curl -fLsu "$NPM_USER:$NPM_PASS" -o "$file" "$resolved"

  npm publish "$file" --registry "${NEXUS_BASE}/repository/${THIRDPARTY_REPO}/"
done
