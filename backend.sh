#!/bin/sh
# Configure le backend HTTP OpenTofu sur le state GitLab de la grappe passee en
# argument. Aucun secret a gerer : CI_JOB_TOKEN suffit, et chaque grappe a son
# propre state (rayon d'explosion limite a une grappe).
#
#   usage : sh ci/backend.sh <numero-de-grappe>
set -eu

n="$1"
adresse="${CI_API_V4_URL}/projects/${CI_PROJECT_ID}/terraform/state/grappe-${n}"

tofu -chdir=tofu init -reconfigure \
  -backend-config="address=${adresse}" \
  -backend-config="lock_address=${adresse}/lock" \
  -backend-config="unlock_address=${adresse}/lock" \
  -backend-config="username=gitlab-ci-token" \
  -backend-config="password=${CI_JOB_TOKEN}" \
  -backend-config="lock_method=POST" \
  -backend-config="unlock_method=DELETE" \
  -backend-config="retry_wait_min=5"
