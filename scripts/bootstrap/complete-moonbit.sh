#!/bin/sh
set -eu
: "${MISE_TOOL_INSTALL_PATH:?missing install path}"
: "${MISE_TOOL_VERSION:?missing version}"
export MOON_HOME="$MISE_TOOL_INSTALL_PATH"
installer="$(mktemp)"
trap 'rm -f "$installer"' EXIT HUP INT TERM
curl -fsSL https://cli.moonbitlang.com/install/unix.sh -o "$installer"
bash "$installer" "$MISE_TOOL_VERSION"
"$MOON_HOME/bin/moon" update
