#!/usr/bin/env bash
# Mintlify CLI does not support Node 25+. This script prefers Homebrew node@22/node@20,
# otherwise a compatible default `node`, otherwise Docker (node:22-bookworm).
set -euo pipefail

DOCS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-3000}"

node_major() {
  "$1" -p "parseInt(process.versions.node.split('.')[0], 10)" 2>/dev/null || echo 99
}

# Invoke npx via the same Node as node_bin so a global Node 25 on PATH is never used.
run_mint_with_node() {
  local node_bin="$1"
  local bindir prefix npx_cli
  bindir="$(dirname "$node_bin")"
  prefix="$(cd "$bindir/.." && pwd)"
  npx_cli="$prefix/lib/node_modules/npm/bin/npx-cli.js"
  cd "$DOCS_DIR"
  if [[ -f "$npx_cli" ]]; then
    PATH="$bindir:$PATH" exec "$node_bin" "$npx_cli" --yes mint@latest dev --port "$PORT"
  fi
  PATH="$bindir:$PATH" exec "$bindir/npx" --yes mint@latest dev --port "$PORT"
}

# 1) Homebrew side-by-side installs (no need to brew link)
for brew_prefix in /opt/homebrew/opt /usr/local/opt; do
  for ver in node@22 node@20; do
    candidate="$brew_prefix/$ver/bin/node"
    if [[ -x "$candidate" ]]; then
      maj=$(node_major "$candidate")
      if [[ "$maj" -lt 25 ]]; then
        echo "[mintlify-docs] Using $candidate (Node $maj)"
        run_mint_with_node "$candidate"
      fi
    fi
  done
done

# 2) Current PATH node if already < 25
if command -v node >/dev/null 2>&1; then
  node_path="$(command -v node)"
  maj=$(node_major "$node_path")
  if [[ "$maj" -lt 25 ]]; then
    echo "[mintlify-docs] Using $node_path (Node $maj)"
    run_mint_with_node "$node_path"
  fi
  echo "[mintlify-docs] Default node is v$maj (>= 25); Mintlify is unsupported on this version."
fi

# 3) Docker fallback
if command -v docker >/dev/null 2>&1; then
  echo "[mintlify-docs] Starting Mintlify via Docker (node:22-bookworm) on port $PORT ..."
  exec docker run --rm -it \
    -p "${PORT}:${PORT}" \
    -v "${DOCS_DIR}:/docs" \
    -w /docs \
    node:22-bookworm \
    bash -lc "npx --yes mint@latest dev --port ${PORT}"
fi

echo ""
echo "Mintlify dev requires Node 20.x–24.x (not 25+). None found."
echo ""
echo "Fix one of:"
echo "  brew install node@22"
echo "  # then re-run: yarn docs:dev"
echo ""
echo "Or install Docker Desktop / OrbStack and re-run (this script will use node:22 automatically)."
echo ""
exit 1
