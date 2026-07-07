#!/usr/bin/env bash
# Index a project into the shared ai-knowledge-base (Supabase-backed).
# No MCP server involved — runs the same indexProject() pipeline the MCP
# tool uses, directly, so it never needs a local stdio MCP entry just for
# this one tool.
#
# Usage:
#   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
#     index-project.sh <repo_root> <project_path> <slug> [ref] [commit]
#
#   repo_root      path to a local ai-knowledge-base checkout (cloned here if missing)
#   project_path   absolute path to the codebase to index
#   slug           project identifier (folder name under projects/)
#   ref            snapshot ref, e.g. branch:main (default: branch:main)
#   commit         optional git commit SHA
set -euo pipefail

REPO_ROOT="${1:?repo_root required}"
PROJECT_PATH="${2:?project_path required}"
SLUG="${3:?slug required}"
REF="${4:-branch:main}"
COMMIT="${5:-}"

: "${SUPABASE_URL:?SUPABASE_URL must be set}"
: "${SUPABASE_SERVICE_ROLE_KEY:?SUPABASE_SERVICE_ROLE_KEY must be set}"

if [ ! -d "$REPO_ROOT" ]; then
  echo "Cloning ai-knowledge-base into $REPO_ROOT ..."
  git clone --depth 1 https://github.com/MarcellDr/ai-knowledge-base.git "$REPO_ROOT"
fi

cd "$REPO_ROOT"

if [ ! -d node_modules ]; then
  echo "Installing dependencies (first run only) ..."
  pnpm install
fi

ARGS=("$PROJECT_PATH" --slug "$SLUG" --ref "$REF" --include-source)
if [ -n "$COMMIT" ]; then
  ARGS+=(--commit "$COMMIT")
fi

echo "Indexing $SLUG @ $REF ..."
pnpm index "${ARGS[@]}"
