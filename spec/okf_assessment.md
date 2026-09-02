# OKF (Open Knowledge Format) Assessment

**Status: the three recommended ideas below (lifecycle metadata,
provenance, and a `type` discriminator) have been implemented.** See
`lib/radar/tech_radar/status.ex`, `lib/radar/tech_radar/release.ex`, and
`lib/radar/tech_radar.ex` for the `type`/`status`/`stale_after`/`sources`
front-matter fields, the `Status` config (draft/stable/deprecated), and
`TechRadar.stale?/1,2`. Full OKF compliance (attestation, YAML-map fields,
unvalidated links) was deliberately not pursued, per the "Where it doesn't
fit" section below.

Evaluation of this app's current markdown/MDEx content pipeline, and whether
adopting Google Cloud's Open Knowledge Format (OKF) would improve it.

## Current state

The app's markdown pipeline is small and deliberately narrow:

- **`lib/radar/tech_radar/front_matter_parser.ex`** is a **hand-rolled
  parser**, explicitly *not* YAML. It supports exactly 6 known keys
  (`title`, `ring`, `quadrant`, `tags`, `featured`, `related`), 4 value
  shapes (quoted/bare strings, bracketed scalar lists, booleans), and raises
  at compile time on any unknown key or malformed block.
- **MDEx** (v0.13.5, current) is used in exactly two places
  (`lib/radar/tech_radar/html_converter.ex`,
  `lib/radar/tech_radar/about.ex`), both calling `MDEx.to_html!/2` with
  `table`/`autolink`/`strikethrough` extensions and the library's default
  sanitizer — nothing else. MDEx never sees the front matter (the regex
  parser strips it first), and none of MDEx's structured capabilities
  (AST/`MDEx.Document`, native front-matter parsing, link/heading
  extraction, syntax highlighting via `lumis`) are used anywhere.
- `related:` is validated at **compile time** against real item ids (see
  `lib/radar/tech_radar.ex`) — links are guaranteed non-dead by
  construction, which is stricter than most content pipelines bother with.

## What OKF actually is

Google Cloud's Open Knowledge Format (released June 2026) is a spec for
portable, agent-readable knowledge bundles: a directory of markdown files,
each with YAML front matter. Only one field is required — `type` (a
free-text string, not centrally registered). Everything else is optional
and grouped into families:

- **Recommended**: `title`, `description`, `resource` (URI), `tags`
- **Provenance**: `sources` (what a doc was derived from, with
  author/timestamp)
- **Trust**: `generated` (by whom/when) and `verified` (by whom/when)
- **Lifecycle**: `status` (draft/stable/deprecated), `stale_after` (an
  expiry instant)
- **Attestation**: for `type: Attested Computation` docs specifically —
  `runtime`, `parameters`, `executor`, `attester`, with receipts — clearly
  built for BigQuery/dbt-style computed metrics, not general content.

Cross-links are just **ordinary markdown links in prose**
(`[customers](/tables/customers.md)`), deliberately untyped — the spec
explicitly forbids consumers from rejecting a bundle over a broken link.
Reserved filenames `index.md` and `log.md` give a bundle a manual directory
listing and changelog. Everything is versioned loosely (`0.2`), and the
whole design principle is "minimally opinionated, maximally portable."

Sources: [Google Cloud blog post](https://cloud.google.com/blog/products/data-analytics/how-the-open-knowledge-format-can-improve-data-sharing),
[OKF SPEC.md](https://github.com/GoogleCloudPlatform/knowledge-catalog/blob/main/okf/SPEC.md).

## Where this app already does what OKF is trying to achieve

It's worth naming this first: this radar is *structurally* already very
close to an OKF bundle — markdown + front matter, directory-per-release,
cross-links, version-controlled in git. A few places it's actually
**better** than raw OKF:

- OKF's `index.md` is a manually maintained listing. This app's `/radar`
  page is a **live, always-accurate index** generated from the compiled
  items — strictly superior, nothing to gain by adding static `index.md`
  files.
- OKF's cross-links are untyped and unvalidated by design ("consumers MUST
  NOT reject... broken links"). This app's `related:` field is validated at
  compile time — you get a stronger guarantee (no dead links, ever) than
  OKF's own philosophy asks for. Adopting OKF's link-validation stance would
  be a regression, not an improvement.
- OKF's `log.md` is a manually written changelog. This app already derives
  ring-movement history automatically from dated release files
  (`ItemBuilder`) — again, generated and guaranteed-consistent beats
  hand-maintained.

## Where OKF genuinely has something to offer

1. **Lifecycle metadata (`status`, `stale_after`)** — this is a real gap.
   Nothing today flags "this item's assessment hasn't been revisited in N
   months." For a tech radar specifically, staleness tracking is directly
   on-topic (rings are time-sensitive judgments).
2. **Lightweight provenance (`sources`)** — nothing today records *why* an
   item landed in a given ring (a postmortem, a vendor doc, a bake-off). A
   flat list of source URLs per item would add real traceability for
   basically free.
3. **A `type` discriminator** — currently every markdown file in this app
   is implicitly "a radar item." If you ever want non-item content (release
   notes, team playbooks) to live in the same pipeline, `type` gives you
   that seam. Not needed today, but cheap insurance.
4. **Portability** — if this content is ever meant to be consumed outside
   this Phoenix app (by an internal AI agent, a different tool, another
   team's catalog), OKF-shaped front matter is something generic tooling
   could already parse, vs. today's bespoke 6-key format.

## Where it doesn't fit / isn't worth adopting

- **Attestation/executor/receipt fields** are built for computed metrics
  (BigQuery queries, dbt models) — there's no analog for "why is Kubernetes
  in the Adopt ring," so this whole family is dead weight for this project.
- **Full YAML front matter**: the current parser deliberately avoids a YAML
  dependency, and it works because every field so far is flat
  (scalars/lists). OKF's richer optional fields (`sources` as a list of
  *maps*, `generated`/`verified` as maps) would require nested structures
  the hand-rolled parser genuinely cannot represent — adopting those
  specifically would force in a real YAML library. The
  `stale_after`/`status`/flat-`sources` subset above stays within the
  current parser's reach; the map-shaped fields don't.
- **MDEx's unused AST/native front-matter capabilities**: worth noting as a
  separate, smaller finding — regardless of OKF, this app is only using
  MDEx as a `markdown -> HTML string` function. If you ever want
  auto-generated excerpts, a table of contents, or extracted-link
  validation done via MDEx itself rather than hand-rolled code, that's
  available and untouched today — but it's orthogonal to OKF, not a reason
  to adopt it.

## Bottom line

Full OKF compliance isn't a good match — a chunk of the spec (attestation)
doesn't apply, and its "don't validate links" philosophy is a step down
from what this app already guarantees. But three specific, low-cost ideas
are worth borrowing later if wanted: **`status`/`stale_after`** for
lifecycle tracking, a flat **`sources`** list for provenance, and (only if
the content pipeline ever needs to be consumed by something other than this
app) shaping the existing fields to be more OKF-recognizable rather than
replacing the format outright. None of that requires a YAML dependency or
touching the current validation model — it's additive to the existing
hand-rolled parser.
