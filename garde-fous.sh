#!/usr/bin/env bash
# garde-fous.sh — Applique de façon idempotente les garde-fous logs / disque
# Cibles : Rocky Linux 9 / Oracle Linux 9, podman (root et rootless)
#
# Usage :
#   sudo ./garde-fous.sh           applique la configuration
#   sudo ./garde-fous.sh --check   vérifie seulement (code retour 2 si écart)
#
# Relançable autant de fois que voulu : un fichier déjà conforme n'est pas
# touché, et un service n'est redémarré que si sa configuration a changé.

set -euo pipefail

# ---------------------------------------------------------------------------
# Paramètres
# ---------------------------------------------------------------------------
LOG_SIZE_MAX=52428800          # 50 Mo max par fichier de log de conteneur
JOURNAL_MAX="2G"               # taille max du journal systemd
JOURNAL_KEEP_FREE="4G"         # espace disque toujours laissé libre
JOURNAL_RETENTION="1month"     # durée de conservation max
LOGROTATE_MAXSIZE="500M"       # rotation de /var/log/messages au-delà
FILTRE_RSYSLOG=0               # 1 = active le filtre rsyslog (optionnel)

PODMAN_CONF=/etc/containers/containers.conf.d/10-garde-fous.conf
JOURNALD_CONF=/etc/systemd/journald.conf.d/10-limits.conf
LOGROTATE=/etc/logrotate.d/rsyslog
RSYSLOG_FILTRE=/etc/rsyslog.d/00-filtre-podman.conf
BACKUP_DIR=/root/garde-fous-backup

MODE="apply"
[[ "${1:-}" == "--check" ]] && MODE="check"

if [[ $EUID -ne 0 ]]; then
  echo "Ce script doit être lancé avec sudo." >&2
  exit 1
fi

ECARTS=0
PODMAN_MODIFIE=0
JOURNALD_MODIFIE=0
RSYSLOG_MODIFIE=0

ok()     { printf '  [OK]        %s\n' "$1"; }
change() { printf '  [MODIFIÉ]   %s\n' "$1"; }
ecart()  { printf '  [ÉCART]     %s\n' "$1"; ECARTS=$((ECARTS + 1)); }
warn()   { printf '  [ATTENTION] %s\n' "$1"; }

# ensure_file <chemin> <contenu>
# Crée le dossier et le fichier si besoin, réécrit le fichier si son contenu
# diffère. Retourne 0 si le fichier a été (ou devrait être) modifié, 1 sinon.
ensure_file() {
  local path="$1" content="$2" tmp
  tmp=$(mktemp)
  printf '%s\n' "$content" > "$tmp"

  if [[ -f "$path" ]] && cmp -s "$tmp" "$path"; then
    rm -f "$tmp"; ok "$path"; return 1
  fi

  if [[ $MODE == "check" ]]; then
    rm -f "$tmp"; ecart "$path (absent ou différent)"; return 0
  fi

  mkdir -p "$(dirname "$path")"
  install -m 0644 -o root -g root "$tmp" "$path"
  rm -f "$tmp"
  if command -v restorecon >/dev/null; then restorecon -q "$path" || true; fi
  change "$path"
  return 0
}

# ensure_logrotate_option <directive complète>   ex : "maxsize 500M"
# Ajoute la directive dans le bloc, ou corrige sa valeur si elle existe déjà.
ensure_logrotate_option() {
  local wanted="$1" key="${1%% *}"

  if grep -qE "^\s*${wanted}\s*$" "$LOGROTATE"; then
    ok "$LOGROTATE : $wanted"; return 1
  fi

  if [[ $MODE == "check" ]]; then
    ecart "$LOGROTATE : '$wanted' absent ou différent"; return 0
  fi

  if grep -qE "^\s*${key}(\s|$)" "$LOGROTATE"; then
    # La directive existe avec une autre valeur : on la remplace
    sed -i -E "s|^\s*${key}(\s.*)?$|    ${wanted}|" "$LOGROTATE"
  else
    # Sinon on l'ajoute juste après la première accolade ouvrante
    sed -i -E "0,/\{\s*$/s//{\n    ${wanted}/" "$LOGROTATE"
  fi
  change "$LOGROTATE : $wanted"
  return 0
}

echo "Mode : $MODE"

# ---------------------------------------------------------------------------
echo "1. Podman (logs des conteneurs + événements)"
# ---------------------------------------------------------------------------
CONTENU=$(cat <<EOF
# Géré par garde-fous.sh — ne pas modifier à la main
[containers]
log_driver = "k8s-file"
log_size_max = ${LOG_SIZE_MAX}

[engine]
events_logger = "file"
EOF
)
if ensure_file "$PODMAN_CONF" "$CONTENU"; then PODMAN_MODIFIE=1; fi

# Une config utilisateur est prioritaire sur la config système : on la signale
for f in /root/.config/containers/containers.conf \
         /home/*/.config/containers/containers.conf \
         /home/*/.config/containers/containers.conf.d/*.conf; do
  [[ -f "$f" ]] || continue
  if grep -qE '^\s*(log_driver|log_size_max|events_logger)\s*=' "$f"; then
    warn "$f redéfinit un réglage de logs (prioritaire sur la config système)"
  fi
done

# ---------------------------------------------------------------------------
echo "2. journald"
# ---------------------------------------------------------------------------
CONTENU=$(cat <<EOF
# Géré par garde-fous.sh — ne pas modifier à la main
[Journal]
Storage=persistent
SystemMaxUse=${JOURNAL_MAX}
SystemKeepFree=${JOURNAL_KEEP_FREE}
MaxRetentionSec=${JOURNAL_RETENTION}
EOF
)
if ensure_file "$JOURNALD_CONF" "$CONTENU"; then JOURNALD_MODIFIE=1; fi

# ---------------------------------------------------------------------------
echo "3. logrotate (/var/log/messages)"
# ---------------------------------------------------------------------------
if [[ -f "$LOGROTATE" ]]; then
  # Sauvegarde de l'original, une seule fois, hors de /etc/logrotate.d
  if [[ $MODE == "apply" && ! -f "$BACKUP_DIR/logrotate-rsyslog.orig" ]]; then
    mkdir -p "$BACKUP_DIR"
    cp -p "$LOGROTATE" "$BACKUP_DIR/logrotate-rsyslog.orig"
  fi

  LOGROTATE_MODIFIE=0
  if ensure_logrotate_option "maxsize ${LOGROTATE_MAXSIZE}"; then LOGROTATE_MODIFIE=1; fi
  if ensure_logrotate_option "compress"; then LOGROTATE_MODIFIE=1; fi

  if [[ $MODE == "apply" && $LOGROTATE_MODIFIE -eq 1 ]]; then
    if ! logrotate -d /etc/logrotate.conf >/dev/null 2>&1; then
      cp -p "$BACKUP_DIR/logrotate-rsyslog.orig" "$LOGROTATE"
      warn "config logrotate invalide : fichier d'origine restauré"
    fi
  fi
else
  warn "$LOGROTATE introuvable (paquet rsyslog-logrotate absent ?)"
fi

# ---------------------------------------------------------------------------
echo "4. Filtre rsyslog (optionnel, FILTRE_RSYSLOG=$FILTRE_RSYSLOG)"
# ---------------------------------------------------------------------------
if [[ $FILTRE_RSYSLOG -eq 1 ]]; then
  CONTENU=$(cat <<'EOF'
# Géré par garde-fous.sh — ne pas modifier à la main
if $programname == "podman" then stop
if $msg contains "podman healthcheck" then stop
EOF
)
  if ensure_file "$RSYSLOG_FILTRE" "$CONTENU"; then RSYSLOG_MODIFIE=1; fi
elif [[ -f "$RSYSLOG_FILTRE" ]]; then
  if [[ $MODE == "check" ]]; then
    ecart "$RSYSLOG_FILTRE présent alors que le filtre est désactivé"
  else
    rm -f "$RSYSLOG_FILTRE"; RSYSLOG_MODIFIE=1; change "$RSYSLOG_FILTRE supprimé"
  fi
else
  ok "filtre désactivé"
fi

# ---------------------------------------------------------------------------
if [[ $MODE == "apply" ]]; then
  echo "5. Rechargement des services"
  if [[ $JOURNALD_MODIFIE -eq 1 ]]; then
    if systemctl restart systemd-journald; then change "systemd-journald redémarré"
    else warn "échec du redémarrage de systemd-journald"; fi
  fi
  if [[ $RSYSLOG_MODIFIE -eq 1 ]]; then
    if rsyslogd -N1 >/dev/null 2>&1; then
      if systemctl restart rsyslog; then change "rsyslog redémarré"
      else warn "échec du redémarrage de rsyslog"; fi
    else
      warn "config rsyslog invalide (rsyslogd -N1) : rsyslog NON redémarré"
    fi
  fi
  if [[ $PODMAN_MODIFIE -eq 1 ]]; then
    warn "config podman modifiée : recréer les conteneurs (down puis up) pour l'appliquer"
  fi
  if [[ "$PODMAN_MODIFIE$JOURNALD_MODIFIE$RSYSLOG_MODIFIE" == "000" ]]; then
    ok "rien à recharger"
  fi
fi

# ---------------------------------------------------------------------------
echo "6. Vérifications"
# ---------------------------------------------------------------------------
DRIVER=$(podman info --format '{{.Host.LogDriver}}' 2>/dev/null || echo "inconnu")
if [[ $DRIVER == "k8s-file" ]]; then
  ok "podman (root) : driver $DRIVER"
else
  ecart "podman (root) : driver $DRIVER au lieu de k8s-file"
fi
printf '  %s\n' "$(journalctl --disk-usage 2>/dev/null || echo 'journal : taille inconnue')"

echo
if [[ $MODE == "check" ]]; then
  if [[ $ECARTS -gt 0 ]]; then
    echo "Résultat : $ECARTS écart(s). Lancer sans --check pour corriger."
    exit 2
  fi
  echo "Résultat : tout est en place."
else
  echo "Terminé. Côté rootless, vérifier sans sudo : podman info --format '{{.Host.LogDriver}}'"
fi
