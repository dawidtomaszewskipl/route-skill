#!/usr/bin/env bash
# Install the route skill for Claude Code.
#
#   ./install.sh              install globally into ~/.claude/skills/route
#   ./install.sh <project>    install into <project>/.claude/skills/route

set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/SKILL.md"

if [[ $# -gt 0 ]]; then
  dest="${1%/}/.claude/skills/route"
else
  dest="${HOME}/.claude/skills/route"
fi

mkdir -p "$dest"
cp "$src" "$dest/SKILL.md"

echo "Installed route -> $dest/SKILL.md"
echo "Start a new Claude Code session and run /route to use it."
