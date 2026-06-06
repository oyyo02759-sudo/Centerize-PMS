# Centerize PMS — Project Development Workflow

A graph-aware, break-nothing workflow for extending the Centerize PMS codebase.
It is built around the tools we have installed: the **code-review-graph** skills
(`explore-codebase`, `review-changes`, `refactor-safely`, `debug-issue`) and the
**UI/UX Pro Max** skill for frontend work.

> **Why this exists:** the codebase has live, coupled subsystems (multi-tenant
> billing, PromptPay payments, real-time room grid). The graph lets us see the
> *blast radius* of any change **before** we write code, so the team can move fast
> without breaking what already works.

---

## 1. System map (know what you're touching)

| Layer | Location | Stack | Graph communities |
| ----- | -------- | ----- | ----------------- |
| **Backend API** | repo root (`src/`, `prisma/`) | NestJS · Prisma · PostgreSQL | `property`, `billing-invoice`, `tenants`, `webhook`, `websocket`, `health`, `common-database` |
| **Frontend** | `frontend/` | Next.js · React · `socket.io-client` | (not yet indexed — see §7) |
| **Prototype** | `centerize-pms/` | Vite · React (Google AI Studio export) | reference only — **do not build on this** |

### 🔴 High-risk zones (touch with extra care)
These have the highest blast radius. Always run an impact check before editing.
1. **`common-database` ↔ `billing-invoice`** — graph-flagged high coupling (12 edges). A change in the shared DB layer ripples into invoicing.
2. **Tenant isolation** (`tenants` community, SQL) — every query must stay tenant-scoped. A leak here is a security incident, not a bug.
3. **Payments** — `createPromptPayQr`, `generateInvoice`, `handleSubscribe`. Money-handling: never refactor casually.
4. **Real-time** — `websocket` (socket.io) drives the live room grid; breaking an event contract breaks the frontend silently.

---

## 2. The golden rules

1. **Graph before grep.** Always start by querying the graph (it's faster, cheaper, and shows callers/dependents). Fall back to file reading only when the graph doesn't cover it.
2. **Impact before edit.** Never modify a hub/critical node without running `get_impact_radius` + `get_affected_flows` first.
3. **One change, one branch.** Branch off `main`; keep PRs scoped to a single feature/fix.
4. **Existing contracts are sacred.** API response shapes, websocket event names, and DB columns are consumed by the frontend and by tenants' integrations. Change them additively (deprecate, don't delete) unless coordinated.
5. **Tests gate the merge.** New behavior ships with a test that covers its critical flow.
6. **Let the hooks work for you.** The graph auto-updates after edits, and the pre-commit hook runs change-detection. Read its output — don't `--no-verify` past it.

---

## 3. The workflow (per change)

### Phase 0 — Frame the change
- Write one sentence: *what* changes and *which subsystem* it lives in (§1 table).
- Branch: `git switch -c feat/<area>-<short-desc>` (e.g. `feat/billing-partial-refund`).

### Phase 1 — Explore & understand  → **skill: `explore-codebase`**
Goal: build a mental model without reading whole files.
- `semantic_search_nodes` — find the functions/classes by keyword.
- `query_graph` with `callers_of` / `callees_of` / `imports_of` — see how the code connects.
- `query_graph` with `tests_for` — find existing coverage you must keep green.
- Output of this phase: a short list of the exact nodes/files you'll touch.

### Phase 2 — Impact analysis (the break-nothing gate) → graph MCP tools
**Do this before writing code.**
- `get_impact_radius` on each node you plan to change → the blast radius.
- `get_affected_flows` → which critical flows (e.g. `handleSubscribe`, `getGridMatrix`) your change passes through.
- If the radius touches a **🔴 high-risk zone (§1)**, escalate: pair-review the plan, add regression tests *first*.
- Decide: is this an **additive** change (safe) or a **breaking** change (needs coordination + deprecation path)?

### Phase 3 — Design
- **Backend:** respect module boundaries. New logic goes in the owning module; shared logic goes through `common-database` deliberately (and re-check coupling). Keep every query tenant-scoped.
- **Frontend:** → **skill: `UI/UX Pro Max`**. Use it to plan/build components against our stack (Next.js + React). Ask it for layout, palette, accessibility, and component structure. Reuse existing components before creating new ones. Keep websocket event names in sync with the backend contract.

### Phase 4 — Implement
- Small commits, descriptive messages.
- **TDD where it matters:** for high-risk zones, write the failing test first.
- Keep API/websocket/DB contracts additive (rule §4).
- The graph re-indexes automatically as you edit (PostToolUse hook).

### Phase 5 — Self-review  → **skill: `review-changes`**
Before opening a PR, run a structured review on your own diff:
- `detect_changes` → risk-scored summary of what you changed.
- `get_review_context` → token-efficient source snippets for the reviewer (and for you).
- `get_affected_flows` again → confirm you didn't disturb a flow you didn't intend to.
- Fix anything flagged; re-run until clean.

### Phase 6 — Verify it actually works  → `/verify` or `/run`
- Backend: run the relevant test suite + boot the API.
- Frontend: run `frontend` dev server, click through the changed UI.
- For real-time/billing changes: exercise the full flow end-to-end (e.g. subscribe → invoice → PromptPay QR; or room status change → grid updates live).

### Phase 7 — Commit, PR & review
- The **pre-commit hook** runs `code-review-graph update` + `detect-changes --brief`. Read it.
- Open the PR. Reviewer uses **`review-changes`** / the `/review` skill on the diff — focus review attention where `detect_changes` shows high risk.
- Merge only when: tests green ✅, impact understood ✅, contracts preserved (or deprecation documented) ✅.

---

## 4. Special protocols

### Refactoring → **skill: `refactor-safely`**
1. `refactor_tool` to plan renames / find dead code.
2. `get_impact_radius` on every symbol being moved/renamed.
3. Change call sites in the same PR; never leave the graph half-migrated.
4. Use this especially to *reduce* the `common-database` ↔ `billing-invoice` coupling over time.

### Debugging → **skill: `debug-issue`**
1. Reproduce, identify the entry point (e.g. a flow from `list_flows`).
2. `traverse_graph` / `query_graph` to walk the call chain to the fault.
3. `get_affected_flows` to confirm the fix's scope before patching.
4. Add a regression test at the discovered fault site.

### Database / schema changes (highest blast radius)
- Schema lives in `prisma/` + `schema.sql` / `seed.sql`.
- Migrations are **additive-first**: add columns/tables, backfill, then (later, separately) remove.
- Re-verify tenant scoping on every new query path.
- Run `get_impact_radius` on the affected Prisma models — DB changes fan out furthest.

---

## 5. Per-role cheat sheet

| You are… | Start with | Then |
| -------- | ---------- | ---- |
| Adding a **backend feature** | `explore-codebase` → `get_impact_radius` | implement → `review-changes` → `/verify` |
| Building **UI** | `UI/UX Pro Max` (design) + `explore-codebase` (reuse) | implement → run `frontend` → `review-changes` |
| **Refactoring** | `refactor-safely` | impact-check every symbol → migrate call sites in one PR |
| **Fixing a bug** | `debug-issue` | regression test → `review-changes` |
| **Reviewing a PR** | `detect_changes` on the diff | focus on high-risk + high-coupling areas |

---

## 6. Definition of Done
- [ ] Impact analysis run; blast radius understood and documented in the PR.
- [ ] No 🔴 high-risk zone touched without an explicit regression test.
- [ ] Existing API / websocket / DB contracts preserved (or deprecation path documented).
- [ ] Tenant isolation verified on any new query path.
- [ ] `detect_changes` self-review clean.
- [ ] Tests green; feature verified in a running app.
- [ ] Pre-commit hook output reviewed (not bypassed).

---

## 7. Housekeeping
- The graph indexes **both backend and frontend** (35 files): backend `src/` + the Next.js `frontend/src/` source. Impact analysis (`get_impact_radius`, `get_affected_flows`) works across the UI too.
- **The graph only indexes git-tracked files.** New files won't appear in the graph until they're at least `git add`-ed. Compiled frontend artifacts (`*.js`, `*.d.ts`, `*.js.map` under `frontend/src/`) are gitignored on purpose so they don't pollute the graph with duplicate symbols.
- The graph rebuilds incrementally on edit; if it ever looks stale, run `code-review-graph build`.
