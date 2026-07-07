#!/usr/bin/env bash
# Delete a project (or a single ref/snapshot) from the shared ai-knowledge-base.
# No MCP server involved — like index-project, this runs the same
# deleteProject()/deleteRef() pipeline directly via `pnpm delete`.
#
# Usage:
#   SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... \
#     delete-project.sh <repo_root> <slug> [ref] [--confirm]
#
#   repo_root   path to a local ai-knowledge-base checkout (cloned here if missing)
#   slug        project identifier to delete
#   ref         optional — delete only this snapshot (e.g. branch:main).
#               Omit to delete the ENTIRE project (irreversible).
#   --confirm   without it, only a preview is shown — nothing is deleted.
set -euo pipefail

REPO_ROOT="${1:?repo_root required}"
SLUG="${2:?slug required}"
shift 2

REF=""
CONFIRM=""
for arg in "$@"; do
  case "$arg" in
    --confirm) CONFIRM="--confirm" ;;
    *) REF="$arg" ;;
  esac
done

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

ARGS=("$SLUG")
if [ -n "$REF" ]; then
  ARGS+=(--ref "$REF")
fi
if [ -n "$CONFIRM" ]; then
  ARGS+=(--confirm)
fi

pnpm delete "${ARGS[@]}"
