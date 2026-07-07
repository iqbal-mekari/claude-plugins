# AI Knowledge Base — Workspace Instructions

A self-hosted GraphRAG knowledge base that indexes codebases via tree-sitter → symbol graph →
embeddings, backed by a shared team server. Search code, store session learnings, and recall
project knowledge — no per-user setup for search, no external LLM/API cost.

## Critical Rules

1. **Read `skills/use-knowledge-base/SKILL.md` before any MCP call.** It is the authoritative tool reference.
2. **`index_project` and `delete_project` are never MCP tool calls.** The remote server can't see your local filesystem — indexing and deleting are admin-level operations that require the Supabase service-role key directly. Use the `index-project` / `delete-project` skills' scripts instead.
3. **Never commit or log `SUPABASE_SERVICE_ROLE_KEY` or the MCP bearer token.** Ask the admin for them each time; treat them like passwords.
4. **Never skip the delete preview.** Always run `delete-project.sh` without `--confirm` first, show the user what will be removed, and only re-run with `--confirm` after explicit approval.
5. **Always pass `ref` explicitly** to `search`, `get_symbol`, `get_neighbors`, and `impact` — don't rely on the `branch:main` default when the user's context implies a different branch/tag.
6. **Never fabricate search results.** If `search` returns nothing useful, say so or narrow the query — do not invent code that isn't in the result set.

## Agent

| Agent               | Role                                                                                                                                          | Invocable |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- | --------- |
| `codebase-explorer` | Answers questions about an indexed codebase: search → drill into symbols → trace call graph → assess blast radius → optionally store a memory | ✅        |

## Skills

| Skill                | Invocation                      | Purpose                                                                                                       |
| -------------------- | ------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `use-knowledge-base` | (reference, or called by agent) | Full MCP tools reference + common workflows — read this first                                                 |
| `index-project`      | (called on request)             | Index/re-index a project via a local script (no MCP call — needs local disk access)                           |
| `delete-project`     | (called on request)             | Delete a project or single ref/snapshot via a local script (needs the service-role key; always preview first) |
| `distill-session`    | `/distill-session`              | Bulk-extract a session's durable learnings into typed memories                                                |

## MCP Tools (`ai-knowledge-base` server)

| Tool                                                                 | Use                                                                             |
| -------------------------------------------------------------------- | ------------------------------------------------------------------------------- |
| `search`                                                             | Primary retrieval — natural-language query → vector search + graph expansion    |
| `get_symbol`                                                         | Fetch verbatim source for a symbol by FQN or id                                 |
| `get_neighbors`                                                      | Callers/callees of a symbol                                                     |
| `impact`                                                             | Blast radius — everything that transitively depends on a symbol                 |
| `list_projects`                                                      | List indexed projects and their refs                                            |
| `store_memory` / `recall_memory` / `list_memories` / `delete_memory` | Session-scoped typed memories (`decision`, `fact`, `pattern`, `gotcha`, `todo`) |
| `store_skill` / `recall_skill` / `list_skills` / `delete_skill`      | Project-level reusable how-to knowledge                                         |
| `get_session_log`                                                    | Raw session log, used by `distill-session`                                      |

`index_project` and `delete_project` exist as pipeline functions but are **not** exposed as MCP
tools on the remote server — use the skills' bundled scripts instead (see Critical Rules).

## Setup

This plugin ships pre-configured to talk to the team's hosted server. After installing:

1. Open this plugin's `.mcp.json` and replace `PASTE_YOUR_MCP_AUTH_TOKEN_HERE` with the real
   `MCP_AUTH_TOKEN` (ask the admin — treat it like a password, never commit the real value).
2. Restart Claude Code. The `ai-knowledge-base` MCP tools (`search`, `get_symbol`, `recall_memory`, etc.) become available immediately — no local Docker/Supabase needed for search/recall.
3. Indexing and deleting need one more thing: `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY` for
   the team's hosted instance (ask the admin), passed as env vars to the `index-project` /
   `delete-project` scripts. These run locally because they need to read source files off disk
   or hold the admin key — never through the remote MCP server.

## Scope

- **Search/recall is read-only and safe by default.** Indexing writes to the shared database; deleting is destructive and gated behind explicit `--confirm`.
- **One shared server, one shared database.** Everyone's `search`/`recall` reads from the same indexed data — there's no per-user local index.
- **No server-side LLM.** `distill-session` extraction is done by the host (Claude), not the MCP server — the server only stores and retrieves.
