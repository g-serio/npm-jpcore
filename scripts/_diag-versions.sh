#!/usr/bin/env bash
set -euo pipefail
export NVM_DIR="$HOME/.nvm"
# shellcheck disable=SC1091
. "$NVM_DIR/nvm.sh"
nvm use default >/dev/null
cd /home/dev/npm-jpcore
for dir in packages/stack packages/core packages/studio packages/react packages/mcp packages/next packages/cli; do
  name=$(node -p "JSON.parse(require('fs').readFileSync('$dir/package.json','utf8')).name")
  local=$(node -p "JSON.parse(require('fs').readFileSync('$dir/package.json','utf8')).version")
  remote=$(npm view "$name" version 2>/dev/null || echo UNPUBLISHED)
  echo "$name local=$local npm=$remote"
done
echo "---"
git status -sb | head -40
