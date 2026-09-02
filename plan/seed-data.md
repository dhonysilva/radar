# Seed the radar with ~110 items and cross-item links

**Status: implemented.** See the "Outcome" section at the end for what
actually shipped vs. this original plan.

## Context

The app currently has only 11 unique radar items (12 markdown files) under
`priv/radar/releases/`, which isn't enough to meaningfully exercise the UI
(filtering, ring-movement history/flags, tag search, and navigation) while
analyzing how the application behaves under realistic data volume. The user
wants a heavy seed (~100+ new items), inspired by the kinds of technologies
that appear on the real ThoughtWorks Technology Radar, **and** wants items to
link to each other so navigation between related items can be exercised.

Research found:
- This project has **no database** for radar content. Items are compiled at
  **build time** from markdown files (`priv/radar/releases/<date>/<slug>.md`)
  via `NimblePublisher` — see `lib/radar/tech_radar/releases.ex`,
  `front_matter_parser.ex`, `release.ex`, `item_builder.ex`. "Seeding" means
  adding more `.md` files; there is no seed script to run.
- There is **no existing relationship/link mechanism** between items at all
  (no `related` field, no join table, no `[[wiki-link]]` convention). This
  has to be built from scratch: a new `related` front-matter field (list of
  slugs), threaded through `FrontMatterParser` → `Release` → `Item`, plus
  compile-time validation that referenced slugs exist, plus a "Related
  items" section on the detail page.
- I fetched https://www.thoughtworks.com/radar to ground the item list in
  real, current blip names (e.g. Model Context Protocol, Spec-driven
  development, Claude Code, agent instruction bloat). Descriptions will be
  **original writing**, not copied ThoughtWorks text — only the technology
  names/categorization are factual/reused.

## Part 1 — Add a `related` field so items can link to each other

Extend the existing allowlist-validation pattern (used today for
`ring`/`quadrant`, see `release.ex:58-66`) to a new optional list field:

1. **`lib/radar/tech_radar/front_matter_parser.ex`**: add `"related" =>
   :related` to `@known_keys` (line 27-33). No other parser change needed —
   it already parses bracketed lists (`tags` uses the same shape).
2. **`lib/radar/tech_radar/release.ex`**: add `:related` to `@enforce_keys`/
   `defstruct`/`@type`, default to `[]` via `Map.get(attrs, :related, [])` in
   `build/3` (mirrors the existing `tags` default on line 41). Keep it as a
   list of plain strings — **no `String.to_atom`**, consistent with the
   AGENTS.md rule already called out in this file's comments.
3. **`lib/radar/tech_radar/item.ex`**: add `:related` (list of strings) to
   the struct/type.
4. **`lib/radar/tech_radar/item_builder.ex`**: carry `current.related`
   through into the built `%Item{}` (same treatment as `tags`/`featured` —
   taken from the latest release, not merged across history).
5. **`lib/radar/tech_radar.ex`**: after `@items = ItemBuilder.from_releases(...)`
   (line 10), add a compile-time check that every id in every item's
   `related` list matches a real item id, raising a clear compile error
   otherwise (same spirit as `Release.atom_for!/4`'s unknown-ring/quadrant
   error) — this catches typos in the ~100+ new files immediately instead of
   producing dead links silently.

## Part 2 — Render related items on the detail page

**`lib/radar_web/live/radar_live/show.ex`**:
- In `mount/3` (lines 7-20), resolve `item.related` slugs to full `Item`
  structs via `TechRadar.get_item/1` (compile-time validation guarantees
  they exist) and assign them, e.g. `:related_items`.
- In `render/1`, add a "Related items" section after the tags block
  (~line 72), following the same `:if={... != []}` + `<h2 class="font-semibold">`
  list pattern already used for the History block, linking each with
  `<.link navigate={~p"/radar/#{related.id}"}>` — this is the same link
  pattern used for item cards in `lib/radar_web/live/radar_live/index.ex:89`.

## Part 3 — Seed ~107 new items (→ ~118 total)

Add markdown files under three new release folders — `priv/radar/releases/2025-02-01/`,
`2025-08-01/`, and `2026-02-01/` (today is 2026-09-02, so the last one is the
"current" release) — on top of the two existing folders. Each file follows
the existing style (`priv/radar/releases/2024-01-15/erlang.md`): quoted
title, `ring`/`quadrant` from the existing allowlist in `config.ex`, a short
`tags` list, a new `related` list (2-4 slugs), and 2 short original
paragraphs of body markdown (no text copied from ThoughtWorks).

**Ring movement / history**: ~15 items will appear in two consecutive dated
folders with a changed `ring` value (e.g. `github-copilot`: trial in
2025-02-01 → adopt in 2025-08-01) to exercise the `:changed` flag and the
History block. The freshest AI-agent items (MCP, Claude Code, GitHub
Spec-Kit, context engineering, agent instruction bloat, etc.) will appear
only in the final 2026-02-01 release, so they show as `:new`.

**Item roster** (slugs are illustrative — final slugs will be kebab-case of
the title), grouped by quadrant, ~26-30 items each:

- **Techniques (~30)**: trunk-based-development, contract-testing,
  feature-flags, domain-driven-design, event-sourcing, cqrs,
  chaos-engineering, platform-engineering, data-mesh, micro-frontends,
  big-bang-rewrites, prompt-engineering, spec-driven-development,
  llm-assisted-code-review, vibe-coding-without-review, shift-left-security,
  zero-trust-architecture, mutation-testing, dora-metrics, fuzz-testing,
  coding-agent-feedback-loops, architecture-drift-detection-with-llms,
  continuous-deployment, api-first-design, blue-green-deployments,
  dark-launching, team-topologies, socio-technical-architecture,
  context-engineering, agent-instruction-bloat
- **Tools (~28)**: github-copilot, claude-code, github-spec-kit,
  cargo-mutants, codescene, playwright, testcontainers,
  opentelemetry-collector, istio, argo-cd, backstage, langchain, datadog,
  grafana, renovate-bot, k6, storybook, eslint, prettier, sentry, dependabot,
  terragrunt, pulumi, checkov, trivy, semgrep, openclaw, wuppiefuzz
- **Platforms (~25)**: aws-lambda, postgresql, pgvector, vercel, supabase,
  cloudflare-workers, model-context-protocol, snowflake, databricks, fly-io,
  hashicorp-vault, temporal, clickhouse, redis, kafka, rabbitmq, dynamodb,
  cockroachdb, neon, railway, netlify, azure-container-apps,
  google-cloud-run, openshift, nomad
- **Languages & Frameworks (~24)**: typescript, react, svelte, go, python,
  nextjs, htmx, zig, solidjs, tailwindcss, livebook, ash-framework, deno,
  gleam, vue, remix, astro, bun, kotlin, swift, flutter, julia, nim, elm

**Related-item clusters** (used to pick each item's `related` list, so links
form a navigable, thematically coherent graph rather than random pairs; a
few cross-cluster edges — e.g. `contract-testing` ↔ `microservices`,
`chaos-engineering` ↔ `kubernetes` — keep clusters from being fully
disconnected):
- BEAM/Elixir: elixir, erlang, phoenix-liveview, livebook, gleam, ash-framework
- Frontend meta-frameworks: react, nextjs, remix, astro, qwik, svelte, solidjs, vue
- Frontend tooling: tailwindcss, htmx, storybook, eslint, prettier, bun, deno, jquery
- Systems languages: rust, go, zig, cargo-mutants, kotlin, swift
- Data/storage: postgresql, pgvector, redis, kafka, rabbitmq, dynamodb, cockroachdb, neon, clickhouse, snowflake, databricks, data-mesh
- Infra/IaC: terraform, pulumi, terragrunt, checkov, hashicorp-vault, kubernetes, openshift, nomad, argo-cd
- Serverless/edge/platform: aws-lambda, cloudflare-workers, vercel, netlify, fly-io, railway, google-cloud-run, azure-container-apps, supabase
- Observability/reliability: opentelemetry-collector, datadog, grafana, dora-metrics, chaos-engineering, sentry
- Security: zero-trust-architecture, shift-left-security, trivy, semgrep, checkov, hashicorp-vault
- Testing/quality: contract-testing, mutation-testing, cargo-mutants, testcontainers, playwright, k6, fuzz-testing, wuppiefuzz
- Architecture/process: microservices, domain-driven-design, cqrs, event-sourcing, micro-frontends, backstage, platform-engineering, trunk-based-development, feature-flags, team-topologies, socio-technical-architecture, api-first-design, continuous-deployment, blue-green-deployments, dark-launching, big-bang-rewrites
- AI/agents: ai-pair-programming, prompt-engineering, github-copilot, claude-code, langchain, model-context-protocol, spec-driven-development, github-spec-kit, llm-assisted-code-review, vibe-coding-without-review, architecture-drift-detection-with-llms, coding-agent-feedback-loops, codescene, context-engineering, agent-instruction-bloat, openclaw
- Dependency/CI hygiene: renovate-bot, dependabot, eslint, prettier, semgrep

## Part 4 — Tests

- **`test/radar/tech_radar/front_matter_parser_test.exs`**: add a case
  asserting `related` parses as a list of strings (same shape as `tags`),
  alongside the existing "defaults are absent when a field is omitted" case.
- **`test/radar/tech_radar/item_builder_test.exs`**: add `related: []`
  (or a sample list) to the test `release/1` helper's defaults, and assert
  it's carried onto the built `Item`.
- **`test/radar/tech_radar_test.exs`**: add a case exercising the
  compile-time-style validation logic in isolation (or, if the check lives
  as a plain function, call it directly with a bad slug list and assert it
  raises) plus a positive case that `get_item/1` on a fixture item's
  `related` ids all resolve via `get_item/1`.
- Test fixtures under `test/support/fixtures/radar/releases/**/*.md` are
  unaffected unless we want a fixture exercising `related` directly — add
  `related: [...]` to one or two fixture files (e.g. `alpha.md` → `beta`) if
  that makes the new context-level test simpler.

## Verification

- `mix compile --warnings-as-errors` — since `@items` is a compile-time
  module attribute, this alone will catch any malformed front matter or bad
  `related` slug across all ~118 files.
- `mix test` — runs the extended unit tests plus the full existing suite.
- `mix phx.server`, then browse `/radar`, filter by quadrant/ring/tag, open
  a few item detail pages (including ones with History from ring movement)
  and confirm the new "Related items" links navigate correctly between
  items.

## Outcome

Implemented as planned, with one addition beyond the original scope: the 11
pre-existing items (`elixir`, `erlang`, `graphql`, `jquery`, `kubernetes`,
`microservices`, `phoenix-liveview`, `rust`, `terraform`,
`ai-pair-programming`, `webassembly`) also got a `related:` line added to
their front matter, so the link graph is bidirectional instead of only
pointing outward from the new items.

Final numbers, confirmed via `mix run -e`:
- **118 total items**, 122 markdown files (15 items have two dated releases).
- **15** items flagged `:new`, **16** flagged `:changed` (15 planned
  movements + the pre-existing `graphql` item, which already moved
  trial → adopt across its original two releases).
- Distribution by quadrant: techniques 33, tools 29, platforms 26,
  languages-and-frameworks 30.
- Distribution by ring: adopt 51, trial 33, assess 25, hold 9.
- Every item resolves at least one inbound related link except the 11
  pre-existing items originally had none outbound — fixed by the addition
  above.

Verified via `mix compile --warnings-as-errors` (0 warnings/errors — this
also validates every `related` id across all 122 files), `mix test` (40/40
passing), `mix format`, and a live `mix phx.server` smoke test: index page
renders all 118 item cards, a moved item (`claude-code`) shows its History
entry and "Changed" badge, and a "Related items" section with working
`<.link navigate>` links renders on item detail pages (spot-checked on
`kubernetes`).

The generator script used to produce the 122 seed markdown files was a
one-off Elixir script run from the scratchpad directory and was not
committed to the repo.
