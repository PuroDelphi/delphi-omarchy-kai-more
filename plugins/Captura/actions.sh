#!/usr/bin/env bash
set -euo pipefail
action=${1:-}
path=${2:-}
case "$action" in
  copy) test -f "$path"; wl-copy --type image/png < "$path" ;;
  pinta) test -f "$path"; exec pinta "$path" ;;
  folder) mkdir -p -- "$path"; exec xdg-open "$path" ;;
  trash) test -f "$path"; exec gio trash -- "$path" ;;
  *) echo "Operación desconocida" >&2; exit 2 ;;
esac
