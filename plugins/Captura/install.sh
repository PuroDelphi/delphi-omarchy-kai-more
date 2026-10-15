#!/usr/bin/env bash
set -euo pipefail
source_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
backend=${1:-"$source_dir/bin/CapturaBackend"}
destination="$HOME/.config/omarchy/plugins/purodelphi.captura"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/captura"
if [[ ! -x $backend ]]; then
  echo "Compila backend/CapturaBackend.dproj para Linux64 e indica su ejecutable:" >&2
  echo "  ./install.sh /ruta/a/CapturaBackend" >&2
  exit 1
fi
for dependency in omarchy quickshell grim slurp wl-copy gio; do
  command -v "$dependency" >/dev/null || { echo "Falta: $dependency" >&2; exit 1; }
done
"$backend" version
omarchy plugin validate "$source_dir"
mkdir -p "$state_dir" "$destination/plugin" "$destination/bin" "$HOME/Pictures/Capturas"
if [[ -f $HOME/.config/omarchy/shell.json ]]; then
  cp -a -- "$HOME/.config/omarchy/shell.json" "$state_dir/shell.json.before-install-$(date +%Y%m%d-%H%M%S)"
fi
install -m 0644 "$source_dir/manifest.json" "$destination/manifest.json"
install -m 0644 "$source_dir"/plugin/*.qml "$destination/plugin/"
install -m 0755 "$source_dir/actions.sh" "$destination/actions.sh"
install -m 0755 "$backend" "$destination/bin/CapturaBackend"
omarchy shell shell rescanPlugins
omarchy plugin enable purodelphi.captura --section right --before omarchy.agents
echo 'Captura instalado. Pulsa el icono de cámara en la barra.'
