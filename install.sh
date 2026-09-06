#!/usr/bin/env bash
# Install the route skill for Claude Code.
#
#   ./install.sh              install globally into ~/.claude/skills/route
#   ./install.sh <project>    install into <project>/.claude/skills/route
#
# Copies SKILL.md and docs/ (SKILL.md refers to docs/ and docs/schemas/ by relative path).

set -euo pipefail

src="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ $# -gt 0 ]]; then
  dest="${1%/}/.claude/skills/route"
else
  dest="${HOME}/.claude/skills/route"
fi

mkdir -p "$dest"
cp "$src/SKILL.md" "$dest/SKILL.md"
rm -rf "$dest/docs"
cp -R "$src/docs" "$dest/docs"

echo "Installed route -> $dest (SKILL.md + docs/)"
echo "Start a new Claude Code session and run /route to use it."
