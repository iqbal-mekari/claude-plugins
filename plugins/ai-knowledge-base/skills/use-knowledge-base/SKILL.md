---
name: use-knowledge-base
description: Use the ai-knowledge-base MCP server to search codebases, store session learnings, manage skills, and recall project knowledge. Invoke when the user asks about a codebase, wants to find code, store what was learned, or manage knowledge across projects.
---

# AI Knowledge Base

A self-hosted GraphRAG knowledge base that indexes codebases via tree-sitter → symbol graph → embeddings, backed by a shared team server (no external LLM or API cost — embeddings run locally wherever indexing happens).

## Startup issues

**401 / unauthorized** — the `MCP_AUTH_TOKEN` in `.mcp.json` is missing or wrong. Ask the admin for the current token and re-check `.mcp.json`.

**Connection error / "fetch failed"** — the team server may be down, or outbound HTTPS is blocked on this network. This is a remote server, not something you start locally.

**Indexing a project isn't an MCP tool call** — see the `index-project` skill instead, which runs a local script rather than going through the remote server (which can't see your filesystem).

---

## Indexed projects

Run `list_projects` to get the live state.

---

## MCP Tools Reference

### Indexing

Not an MCP tool call here — use the **`index-project` skill** instead, which
runs a local script (`skills/index-project/scripts/index-project.sh`). The
underlying pipeline takes the same parameters either way:

```
slug           project identifier
root_path      absolute path to the codebase
ref            "branch:main" | "tag:v1.0" | "user:label"
include_source_in_embedding   true = full source in embeddings (richer search, ~85% larger)
force          bypass embedding cache, re-embed everything
```

### Searching

**`search`** — Primary retrieval. Natural-language query → vector search + graph expansion.

```
slug, query, ref, k (seed results, default 8), expand_hops (default 1), kinds (filter by symbol kind)
```

**`get_symbol`** — Fetch verbatim source for a specific symbol by FQN or id.

```
slug, fqn ("module.ClassName.methodName"), ref, id
```

**`get_neighbors`** — Show callers / callees of a symbol.

```
slug, fqn or id, ref
```

**`impact`** — Blast radius: everything that transitively depends on a symbol.

```
slug, fqn or id, ref, max_depth (default 3)
```

### Memories (session-scoped, typed)

| kind       | use for                                     |
| ---------- | ------------------------------------------- |
| `decision` | Architectural choices and their rationale   |
| `fact`     | Non-obvious truths about the codebase       |
| `pattern`  | Reusable conventions or approaches          |
| `gotcha`   | Pitfalls, sharp edges, non-obvious behavior |
| `todo`     | Concrete open follow-ups                    |

**`store_memory`** — Persist a typed memory.

```
slug, session_id, memory: { kind, title, content, confidence }
```

**`recall_memory`** — Retrieve memories by semantic similarity + recency.

```
slug, query, types (filter by kind), k
```

**`list_memories`** — List all memories, newest first.

```
slug, kind (optional filter), session_id (optional filter), limit, offset
```

**`delete_memory`** — Delete by id, session_id, or all. Always requires `confirm: true`.

### Skills (project-level reusable knowledge)

**`store_skill`** — Create or update a skill.

```
slug, skill_slug, title, content (markdown), metadata
```

**`list_skills`** — List all skills for a project.

**`recall_skill`** — Retrieve skills by semantic similarity.

```
slug, query, k
```

**`delete_skill`** — Delete by skill_slug, or all. Requires `confirm: true`.

### Project management

**`list_projects`** — List all indexed projects and their refs.

Deleting a project isn't an MCP tool call either — same reasoning as
indexing (admin-level, needs the service-role key directly). Use the
**`delete-project` skill** instead.

---

## Common Workflows

### Query a codebase

```
search(slug, "how does cashout work?", ref="branch:release/2.45")
```

Drill deeper with `get_symbol` or `get_neighbors`. Use `impact` to understand blast radius before changing something.

### Index a new project

Use the `index-project` skill (see above) — not an MCP tool call:

```
SUPABASE_URL="<url>" SUPABASE_SERVICE_ROLE_KEY="<key>" \
  bash skills/index-project/scripts/index-project.sh \
  ~/ai-knowledge-base /path/to/project my-project branch:main
```

### Store a session learning

```
store_memory(slug, session_id, { kind:"gotcha", title:"...", content:"...", confidence:0.9 })
```

Or use `/distill-session` at end of session to bulk-extract learnings.

### Recall what we know about a topic

```
recall_memory(slug, "cashout flow")     ← session learnings
recall_skill(slug, "how to reindex")   ← how-tos and scripts
search(slug, "cashout flow")           ← actual code
```

---

## Tips

- **Always pass `ref`** — without it, defaults to `branch:main`.
- **`search` before `get_symbol`** — search gives you the FQN/id needed for symbol lookups.
- **`expand_hops=0`** for a tighter result set when graph noise is high.
- **All deletes require `confirm: true`** — you'll always see a preview before anything is removed.
