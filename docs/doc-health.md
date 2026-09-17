---
name: thoth Documentation Health
description: Living state of doc currency in the thoth repo — fresh / durable / stale / open — refreshed as docs are touched
type: state
---

# Documentation Health — thoth

> **Repair batch 8 (0.52.3)** (2026-09-17): the window's aarch64 syscalls (three unrenumbered), its refusal off Linux, key repeat, the key ring. Docs touched = `CHANGELOG.md`, `docs/development/state.md` (version block, Tests + Targets counts, the Linux / aarch64 / macOS / AGNOS rows, gate 1's stamp, Next), `docs/development/roadmap.md` (batch 8 shipped, batch 9 empty; F8's paragraph points at `gwl_win_backend_select`; a cyrius waiting row for the unnamed syscalls; batch 8's text corrected from "every target" to what was measured), `README.md` / `CONTRIBUTING.md` (stamp) and this line; cyrius and aethersafha each gained a filed issue. No full re-sweep — the tables below stand from the 0.51.1 sweep.
>
> **Repair batch 7 (0.52.2)** (2026-09-17): the live verification kit checked in (`scripts/gui-live.sh`, `scripts/live/`) and `scripts/agnos-run.sh`'s pre-kernel boots classified + retried. Docs touched = `CHANGELOG.md`, `docs/development/state.md` (version block, the AGNOS Targets row, gate 1's re-run stamp, Next), `docs/development/roadmap.md` (batch 7 shipped; batch 8 → 0.52.3 pinned with `thoth gui`'s x86_64-Linux syscalls on every target; F8's gate rewritten from aethersafha/setu source — the contract, the launcher, claimed Ctrl chords, the 2 MB slot, the unpollable channel, rung 3; the gnoboot row's thoth half done), `CLAUDE.md` (process step 3: live verification), `CONTRIBUTING.md` ("Verifying a front end live"; stamp), `docs/guides/getting-started.md` (the `gui-live.sh up` line), `README.md` (stamp) and this line. No full re-sweep — the tables below stand from the 0.51.1 sweep.
>
> **Repair batch 6 (0.52.1)** (2026-09-17): the window driven live on a headless Hyprland over SSH — every owed check passed, eight defects found and fixed with the pinned `hi` repaint. Docs touched = `CHANGELOG.md`, `docs/development/state.md` (version block, Tests + Targets counts, the four Targets rows re-stamped to 0.52.1 — warning sets diffed against 0.52.0, macOS native 822 + 1937 + 1029 + 190 + 749, AGNOS `thoth 0.52.1` in ring 3 on the third boot — and Next), `docs/development/roadmap.md` (batch 6 shipped; batch 7 → 0.52.2 pinned with `agnos-run.sh`'s misattributed boot failure; the gnoboot waiting row; the waiting table re-checked 2026-09-17, no dependency moved; the registry's owed window checks removed as verified, the HiDPI claim corrected into a degradation line; gate 1's re-run stamp), `docs/guides/getting-started.md` (the pointer and `gcmd` source-map rows), `README.md` / `CONTRIBUTING.md` (stamp) and this line. No full re-sweep — the tables below stand from the 0.51.1 sweep.
>
> **F7 (0.52.0)** (2026-09-16): a running command belongs to the surface (the wait poll; the window pumped; Esc stops a command on both surfaces). Docs touched = `CHANGELOG.md`, `docs/development/state.md` (version block, Surface's floor bullet, Tests + Targets counts, Next), `docs/development/roadmap.md` (F7 out of the candidates and F8 first; the shipped batch-4/5 and 0.51.1 sections removed — forward-only; repair batch 6 → 0.52.1 pinned with the agent suite's repaint leak; the waiting table re-checked 2026-09-16 — daimon 2.1.4, its `--agnos` build issue; the registry's owed window checks + what a stop cannot reach), `.thoth/config.cyml.example` (Esc on `[hooks]` / `[verify]` / `[shell].timeout_ms`), `docs/guides/getting-started.md` (the `exec` / `intr` source-map rows), `README.md` / `CONTRIBUTING.md` (stamp) and this line. No full re-sweep — the tables below stand from the 0.51.1 sweep.
>
> **Repair batch 5 (0.51.3)** (2026-09-14): the cyrius 6.6.4 re-vendor (batch 4 item 10). `lib/` re-synced (`cyrius lib sync --full`); `"sys"` added to `[deps].stdlib` (sigil 3.12.18's `agnosys_uname` now calls `sys_uname` — dead-path here but an undefined-fn warning otherwise). `O_NOFOLLOW` now guards the toolpin store and `[history].file` opens (io.cyr gained the constant). Docs touched = `CHANGELOG.md`, `docs/development/state.md` (version block, Tests + Targets counts, the four Targets rows + the gate-1 rung re-stamped to 0.51.3 / 6.6.4 — macOS native suite re-run 822 + 1937 + 982 + 190 + 641 on the cross-built toolchain, AGNOS re-run `thoth 0.51.3` in ring 3), `docs/development/roadmap.md` (batch 5 shipped), `.thoth/config.cyml.example` (symlink prose — the O_NOFOLLOW residual), `README.md` / `CONTRIBUTING.md` (stamp) and this line. No full re-sweep — the tables below stand from the 0.51.1 sweep.
>
> **Repair batch 4 (0.51.2)** (2026-09-14): nine repairs from the pinned batch; docs touched = `CHANGELOG.md`,
> `docs/development/state.md` (version block, Tests + Targets counts, the AGNOS row re-stamped after the runtime
> re-run), `docs/development/roadmap.md` (batch 4 items 1–9 shipped, item 10 split to batch 5 → 0.51.3, gate 1 /
> the Targets AGNOS row re-run), `.thoth/config.cyml.example` unchanged, `README.md` / `CONTRIBUTING.md` (stamp)
> and this line. `docs/examples/.gitkeep` was removed (batch 4 item 6). No full re-sweep — the tables below
> stand from the 0.51.1 sweep.
>
> **Full sweep at 0.51.1** (2026-09-14). Five readers verified every doc set against the tree at 0.51.0
> (`3009b60`: the root docs, the guides + examples, the architecture notes + ADRs, `state.md`'s current-state
> sections, the gap review + the config example); every stated measurement was RE-RUN in a scratch copy (the
> Linux build, the suite — 647 + 1921 + 977 + 824 + 190 = 4,559 assertions; the runner's closing `5 passed` is the
> five suite binaries — `build.sh all`, a raw `--win`, `CYRIUS_STATS`, the include-graph re-sum) and the macOS
> suite natively on ecb (823 + 1897 + 974 + 190 + 641). The AGNOS runtime proof did NOT re-run: the local kernel
> image lacks `BASESTACK_SELFTEST` and `agnos-run.sh` refuses (exit 2) rather than pretend — roadmap batch 4.
> `roadmap.md` was re-cut forward-only (F1–F6 and repair batches 1–3 live in the CHANGELOG; batch 4 is pinned to
> 0.51.2 with ten items; the candidates F7–F14 are ordered with their gates); this ledger was rewritten from the
> readers' verdicts row by row, and the "Touched at 0.44.2 … 0.51.0" notes it had accumulated (fourteen releases
> of prepended prose over 0.43.2 tables — lesson 3 again) are replaced by this record; their durable content is
> in the tier rows.
>
> **Prior full sweeps**: 0.43.2 (47 findings — "What the sweeps found"), 0.43.0/0.43.1 (prose only), 0.33.7,
> 0.31.5 (this ledger created). Between 0.44.2 and 0.51.0 every release touched docs opportunistically, none swept.

## The three lessons this ledger exists to carry

These are the reason the file is worth keeping. Each was paid for.

1. **A doc that states a MEASUREMENT cannot be audited by reading it — the audit is re-running the
   measurement.** (0.38.6.) The `## Toolchain` pin sat two versions behind and the `## Targets` matrix
   was anchored at 0.6.4/0.6.6 across all five lanes. Re-running them flipped the macOS row from
   "builds + runs" to **does not build** — a regression invisible for ~30 releases because the row was
   re-read, never re-tested. Rows like these belong in a "re-measure" bucket, not "fresh".

2. **A number that came out of a tool is not automatically a measurement of the thing you think it
   measures.** (0.43.1.) 0.43.0 *published* "the preprocessor overflowed by 5,370 bytes". That was the
   size at which expansion **aborted**, not a total — so a bigger probe file yields a bigger number for
   the same tree. Headroom is measured by summing the include graph. The retraction had to chase the
   figure through `roadmap.md` and `gap-review.md`, which had both already built arguments on it.

3. **Prose that is prepended rather than merged leaves the file contradicting itself.** (Found at
   0.43.2.) The 0.43.0/0.43.1 sweep wrote a new "Last refresh" block on top of the 0.33.7 one and never
   re-stamped the tables below — so every Tier row still said "this sweep:" about work done ten releases
   earlier, and a dangling sentence fragment sat at the seam. The ledger asserted freshness it had not
   checked, which is precisely how `getting-started.md` and `CONTRIBUTING.md` drifted unnoticed. **If a
   sweep does not re-stamp the tables, it did not happen.**

## What the sweeps found

### 0.51.0 — ~110 findings across five readers; the ones the next sweep should look for first

- **Stamps and counts drift first.** CONTRIBUTING sat at 0.44.0 (seven minors behind, its feature list stopping
  at 0.43.x); README's multi-target line said "re-measured at 0.45.2"; the Targets row's suite counts were three
  minors stale while §Tests in the same file was current; the vendor list named ten bundles (eleven are vendored —
  agnosai-guard was missing); "all 48 modules" (66). **Bump the stamp in the release, not the sweep.**
- **Residuals carried past their fix.** ADR-0015/0017 still said "a symlink inside the project is followed"
  (closed 0.39.0); ADR-0021 still said "on macOS every local authority key is suppressed" (closed 0.44.5);
  ADR-0019's addendum still called the memory double read open (narrowed 0.45.5); ADR-0014's index row said
  POSIX-only (a Windows lane since 0.20.2); the config example said "128 tools" (1024). **A residual is a claim
  with an expiry date** — the roadmap's waiting table stamps each with the version it was last checked against.
- **Two readers measured the same lane and the doc matched neither.** README, `state.md` and the roadmap all said
  the Windows lane is blocked on "IOCP/epoll"; a raw `cyrius build --win` at 6.6.3 surfaces only
  `SYS_SOCKET`/`SYS_CONNECT` plus three vendored names. Re-running the build, not re-reading the build script's
  comment, found it.
- **A doc accurate to the code found the code short.** The config example's "these four paths" matched
  `_project_sensitive` exactly — and 0.51.0 had added a fifth own-state file (`[toolpin].file`) that neither
  named: a custom store inside the jail was model-readable and `edit`-rewritable. **Flagged as CODE and fixed in
  the same cut (0.51.1)**; the doc follows the fix, never precedes it.
- **The roadmap had become a ledger.** Six "shipped as" bullets, three "shipped as" batch sections and a 0.45.5
  macOS verification story sat in the forward-only file; one of its residuals (the GUI not binding
  `[history].file`) had been closed a release earlier. Re-cut: nothing shipped is narrated there.
- **`gap-review.html` drifted again** (stamp 0.43.2, a self-superseding footer, gap 3's 0.51.0 wording, Q2 answered
  by ADR-0022 but still listed). Twins drift; the row says re-diff them at every touch.
- **Dead links are a maintainer item, not a text fix.** The three genesis-repo standards URLs in CLAUDE.md,
  CONTRIBUTING.md and the audit return 404 on the public remote (the files are untracked in the local clone). Open.

### 0.43.2 — 47 findings

The ones that mattered most, recorded so the next sweep knows where to look:

- **A security defect the read-only review could not have found** — it needed the binary run. Piped
  stdin (`git diff | thoth 'review'`, advertised in `--help`) reached `cmd_task`, whose second act is
  the **unjailed** `@mention` reader; a `@/path` line inside third-party piped content was read and
  POSTed to the gateway, silently. Fixed by splitting the task by provenance. **Reviewing source is not
  the same as exercising the program.**
- **Two docs disagreeing is a defect, not a style issue.** `state.md`'s `## Next` still said "macOS
  builds+runs" — the exact claim the previous sweep records itself as having corrected in the README —
  120 lines from its own Targets matrix saying the opposite.
- **`gap-review.html` had drifted a release behind `gap-review.md`.** Two copies of one document always
  drift. They are now labelled as twins with an explicit "edit both, or neither".
- **Three files had no row in this ledger at all** (`CONTRIBUTING.md`, `SECURITY.md`,
  `CODE_OF_CONDUCT.md`) while the sweep prose claimed the root meta files were covered. CONTRIBUTING was
  17 releases stale; SECURITY told a reporter no tagged release existed, against 158 tags. **An absent
  row is worse than a stale one — nothing will ever flag it.**

## At a glance

| Bucket | Count | What it means |
|---|---|---|
| ✅ **Fresh — verified or fixed this sweep** | 31 | Every doc a reader verified against the tree at 0.51.0, and every stale one refreshed in this pass (per row below). |
| 🔵 **Durable — decisions/invariants, re-read not rewrite** | 19 | ADRs 0001–0008, 0010–0011, 0013, 0018, 0020, 0022 + template; CODE_OF_CONDUCT; LICENSE; the two design assets; the scripts. Point-in-time or principle; re-read on a principle change. |
| 🟡 **Stale — refresh in place** | 0 | None after this sweep; every stale row below is marked *stale → fixed at 0.51.1*. |
| 🟠 **Read-through / gap** | 2 | `docs/examples/` (a cheat-sheet, not programs); ADR-0008 (no addendum by policy — the lane state lives in `state.md`'s matrix). |
| ❓ **Open question** | 1 | The three genesis-repo standards links return 404 (CLAUDE.md, CONTRIBUTING.md, the audit). Maintainer: push upstream or repoint. |

## Tier 1 — Structural / root

| File | Status | Notes |
|---|---|---|
| `README.md` | ✅ Fresh (stale → fixed) | Stamp current; **fixed at 0.51.1**: "re-measured at 0.45.2" → 0.51.0 (lanes re-run); Windows "IOCP" → the ws2_32 socket gap + three vendored names (measured); "win is the open lane — see ADR-0008" → gates closed, matrix in `state.md`; the Ask-me-back paragraph moved out of `## Documentation`; `thoth_v1.tiff` named as the splash source. Bump the stamp every release; re-run `build.sh all` before touching the multi-target line. |
| `CHANGELOG.md` | ✅ Fresh | Through **0.51.1**. Refreshed every release. |
| `CLAUDE.md` | ✅ Fresh (stale → fixed) | Durable rules only. **Fixed at 0.51.1**: the `lib/` rule no longer says "dep symlinks" (0 symlinks; it is the synced stdlib snapshot `cyrius build`/`test` rewrite); `docs/audit/` and `gap-review.md` added to the doc list. Open: the standards links (❓). |
| `CONTRIBUTING.md` | ✅ Fresh (stale → fixed) | **Was stamped 0.44.0** — seven minors behind, feature list stopping at 0.43.x, "x86_64 Linux ships" under-reporting three lanes; the 0.43.2 row said "re-stamped 0.43.2" and never recorded the 0.44.0 bump. Re-stamped 0.51.0 with the full surface. **The first file a contributor reads — bump it in every feature release.** Open: the standards links (❓). |
| `SECURITY.md` | ✅ Fresh | Pre-1.0 SemVer, the tags, `docs/audit/` link resolves; verified 0.51.0. |
| `CODE_OF_CONDUCT.md` | 🔵 Durable | No version-bound claims; Covenant 2.1 URL 200. |
| `LICENSE` | 🔵 Durable | **New row.** GPL-3.0-only, as `cyrius.cyml` and the README state. |
| `VERSION` | ✅ Fresh | `0.51.1`; `src/version.cyr` generated by `scripts/gen-version.sh` (run by `build.sh` first). |
| `cyrius.cyml` | ✅ Fresh | **New row.** Pin `cyrius = "6.6.3"` (the sibling cyrius is 6.6.4 — the re-vendor is roadmap batch 4 item 10); the header's ordering rationale holds (its "sigil 3.7.8 / t-ron 2.1.5" stamps are first-seen context; the order still holds at sigil 3.12.17 / t-ron 2.1.10). CI reads the pin. |
| `.thoth/config.cyml.example` | ✅ Fresh (stale → fixed) | **New row** (named in nine touch notes, never tabled). Every documented key is in `_cfg_known_key` and every read key is documented (55). **Fixed at 0.51.1**: 128 → 1024 pins; "hoosh 2.6.4" → re-checked 2.6.10; `ask_user` in the serial list; three → six untrusted inlets; the six reserved verbs; the orphaned `[log].level` line; "read once" → `/reload`; mneme consumed since 0.32.0; the capture temp's `O_EXCL` claim; the 0.51.0 alias refusal; host canonicalisation; "four paths" → five (`[toolpin].file`, with the code). |
| `.gitignore` | 🔵 Durable | **New row.** Carries a 0.43.2 rationale block on checkpoints; still true. |
| `.github/workflows/ci.yml`, `release.yml` | 🔵 Durable | **New row.** Read the pin from `cyrius.cyml` (no hardcoded toolchain); the 0.38.6 rationale block intact. |
| `Thoth.dc.html` | 🔵 Durable | **New row.** The T3 pixel spec cited by ADR-0009 and the `src/gui/*` headers. |
| `thoth_v1.tiff` | 🔵 Durable | **New row.** The emblem AND the source `scripts/gen-splash.sh` renders into `src/splash.cyr` (0.45.3). |
| `scripts/build.sh` (header) | ✅ Fresh (stale → fixed) | **New row.** The target-matrix comment said the AGNOS ELF "cannot be exercised on a Linux host" — `agnos-run.sh` has run it under QEMU since 0.44.4; rewritten. `ARCH_GAP` still lists the epoll set as a tripwire (it does not surface at 6.6.3). |
| `scripts/agnos-run.sh`, `gen-version.sh`, `gen-splash.sh`, `stack.sh`, `sync-*.sh` (10) | 🔵 Durable | **New row.** Headers verified; every vendored bundle has a sync script with the pin as its default TAG. |

## Tier 2 — Architecture (`docs/architecture/`)

| File | Status | Notes |
|---|---|---|
| `001-consumer-only-no-domain-logic.md` | ✅ Fresh (stale → fixed) | Spine list + degrade-closed verified. **Fixed at 0.51.1**: "a new tool → daimon" now distinguishes hosted tools from thoth's nine local-hands tools (ADR-0014/15/17/18/20; the line is identity, ADR-0018); the substrate fan-out list gained `syscalls_linux_common` + `fs_win`. |
| `002-capability-ladder.md` | ✅ Fresh (stale → fixed) | Seam table matches `src/seams.cyr`. **Fixed**: "M6 deliverable (see roadmap)" → shipped 0.6.5 (CHANGELOG); the t-ron row gained `thoth_delegate` and the ungated read/ask tools; the sit row says `.git/` or `.sit/`, no ancestor walk. |
| `003-two-roots-project-jail-vs-mcp-host.md` | ✅ Fresh | Verified against `src/project.cyr` / `src/agent.cyr`; `create_file` added to the jailed list. |
| `README.md` | ✅ Fresh | Indexes 001–003; `create_file` added. |

## Tier 3 — Development (`docs/development/`)

| File | Status | Notes |
|---|---|---|
| `state.md` | ✅ Fresh (stale → fixed) | The per-version log is history; the current-state sections were re-measured. **Fixed at 0.51.1** (25 items): the Targets row's suite counts (three minors stale, contradicting §Tests); the `+ 5` is binaries not assertions; static data / `CYRIUS_STATS` / the include-graph re-sum (`string_data` at 44.5 % is now the tightest meter); eleven vendored bundles; the daimon ≥ 2.1.0 and hoosh ≥ 2.5.5 qualifiers; the four resources/prompts routes; the duplicated daimon-2.0.0 paragraph; the sit phantom count (16); `/run` does not ride `process_agnos`; the Windows gap = what the compiler reports; AGNOS runtime not re-run since 0.44.3 (said, not hidden); macOS re-verified on ecb; §Surface gained `search`/`delegate`/`ask_user`/`memory_write`, `mcpres`, `toolpin`, `gask`, `mpick`, the pointer, `[history].file` on the window; §Posture gained the security-floor paragraph and the full gate list; §Next says F1–F6 shipped and names batch 4. |
| `roadmap.md` | ✅ Fresh (rewritten) | **Forward-only, re-cut at 0.51.1**: three open gates (gate 1 closed, its re-run owed), 0.51.1 = the sweep + the jail repair, batch 4 → 0.51.2 (ten items incl. the cyrius 6.6.4 re-vendor and the AGNOS re-run), the waiting table re-checked against hoosh 2.6.10 / daimon 2.1.3 / sit 1.6.2 / t-ron 2.1.10 / darshana 1.1.2 / cyrius 6.6.4 / kavach 3.12.5 / bhava 2.0.0, candidates F7–F14 ordered with gates, the registry trimmed to open items. F1–F6 and batches 1–3 live in the CHANGELOG. |
| `gap-review.md` | ✅ Fresh (stale → fixed) | **Fixed**: bote 3.3.7 → 3.3.9; the "60 % of 8 MB" argument replaced by the 0.44.5 retraction (8.84 MB / 37 % of 24 MB); the pinning strength notes durability; five → six inlets + the map's directory names; Q2 (the durable rug-pull defence) answered by ADR-0022 and removed; ADR-0022 linked. Q1–Q3 still open. |
| `gap-review.html` | ✅ Fresh (stale → fixed) | Re-synced: stamp 0.43.2 → 0.51.0; the footer no longer supersedes itself and carries the twin sentence; gap 3's wording/chip/legend; bote; the ceiling; pinning; inlets; Q2. Pre-existing rendering differences (a condensed intro, a leaf table) are by design. ⚠ **Edit both, or neither — diff them at every touch.** |
| `doc-health.md` | ✅ Fresh | This file, rewritten at 0.51.1 as a full sweep. |

## Tier 4 — ADRs (`docs/adr/`)

| File | Status | Notes |
|---|---|---|
| `README.md` (index) | ✅ Fresh (stale → fixed) | **All 22 ADRs (0001–0022) have a row** (the 0.43.2 row said 18). **Fixed**: the 0016 and 0019 rows carry their supersession; the 0008 row says AGNOS runs / macOS runs / Windows on the socket gap (and points at the matrix); the 0014 row says POSIX + Windows. |
| `0022-tool-pins-are-durable-defended-without-a-secret.md` | 🔵 Durable | **New row** (0.51.0). Verified against `src/toolpin.cyr` end to end; gained the `TPS_ROWS_MAX`/`TPS_READ_CAP` numbers, the 128 → 1024 table note, the ten states, and a 0.51.1 addendum for the `_project_sensitive` gap the sweep found (closed). |
| `0021-authority-keys-are-global-only.md` | ✅ Fresh (stale → fixed) | Key list matches the `_cfg2_*_global_only` callers exactly. **Fixed**: the macOS "every local authority key suppressed" paragraph closed at 0.44.5 (cyrius 6.5.45 `getenv`). |
| `0019-layered-config-global-base-local-override.md` | ✅ Fresh (stale → fixed) | Per-key layering verified. **Fixed**: the 0.45.3 addendum's "double read stays" → narrowed at 0.45.5 by `_thoth_index_is_global`; the last case named. |
| `0020-ask-user-the-tool-that-runs-toward-the-operator.md` | 🔵 Durable | Verified line by line (`src/ask.cyr`, `gask`, the `/state` row). The "pending an on-compositor confirmation" line stands. |
| `0018-subagent-delegation-scoped-child-context.md` | 🔵 Durable | Fence ADR; depth 1, the swap set verified. |
| `0017-model-edit-tool-jailed-gated-opt-in.md` | ✅ Fresh (stale → fixed) | **Fixed**: "symlink-inside-project followed on write" → RESOLVED 0.39.0. |
| `0016-thoth-home-dir-config-memory-discovery.md` | ✅ Fresh (stale → fixed) | Supersession banner + the 0.43.2 update verified; the greeting path → `src/greet.cyr`. |
| `0015-project-read-tools-jailed-default-on.md` | ✅ Fresh (stale → fixed) | Jail + grants verified. **Fixed**: the two "symlink followed" residuals → RESOLVED 0.39.0 (the Windows `is_symlink` no-op remains). |
| `0014-model-shell-tool-local-posix-gated.md` | ✅ Fresh (addendum) | Dated addendum: 0.20.1 process-group kill, 0.20.2 Windows lane, 0.39.0 0600 capture. Decision untouched. |
| `0012-memory-seam-omit-until-mneme.md` | ✅ Fresh (stale → fixed) | Update banner verified (mneme via daimon). **Fixed**: two dead line numbers dropped; the write-residual sentence restated (AGNOS create mode; the memory append path lacks the 0.39.0 `is_symlink` walk — batch 4 item 5). |
| `0009-presentation-capability-ladder.md` | ✅ Fresh (addendum) | The 0.30.0 addendum verified. **New 0.51.0 addendum**: `sf_*` never shipped under those names (the `ROLE_*` API + `status_snapshot` did); mihi/bnrmr never vendored; the tier is on `/state`, not `/seams`; the `.git/` gate cleared 0.13.0. The Decision is left as history. |
| `0008-multi-target-builds.md` | 🟠 Read-through | Point-in-time (2026-06-12): still says AGNOS blocked on `lseek`, Windows/macOS/aarch64 "future". No addendum by policy — README / state / roadmap no longer point at it for current lane state. Candidate for an addendum in the 0009/0012 style if readers keep landing here. |
| `0001`–`0007`, `0010`–`0011`, `0013` | 🔵 Durable | Point-in-time decisions; historical stamps correct as of each date — **do not "refresh" them.** Index summaries verified against each Decision. |
| `template.md` | 🔵 Durable | The ADR starting point. |

## Tier 5 — Guides + examples (`docs/guides/`, `docs/examples/`)

| File | Status | Notes |
|---|---|---|
| `guides/getting-started.md` | ✅ Fresh (stale → fixed) | A scripted comm confirms **all 66 modules** (53 `src/` + 13 `src/gui/`) have a row and every documented command exists. **Fixed at 0.51.1** (16 items): three → five test suites (twice); `/grants` described as read roots (it is authorization grants); `/allow` arg optional; the `reasonlog.cyr` row; the `toolpin.cyr` row (the durable store, ADR-0022); the `config.cyr` row contradicting the two-layer intro; `/write` diff-after-verdict; ⌃T cycles; Ctrl-D not bound in the TUI; `search` as the third default-on tool + the map; "Adding a command" names `_dispatch_d` + the palette; `diff.cyr` shares with `/git`; the vendor list gained anuenue + agnosai-guard (eleven); a `/help` catch-all line. Remaining omissions (`/help` covers them) noted, not wrong. |
| `examples/README.md` | ✅ Fresh (stale → fixed) | Cheat-sheet, re-verified. **Fixed**: the "then `~/.thoth`" fallback wording → two merged layers (ADR-0019); `/quit` keys; the sample log line (`map_bytes`, `max_iters` 24, the sakshi prefix note). 🟠 still not runnable programs. |
| `examples/.gitkeep` | 🔵 Durable → removal pinned | Redundant; also one of sit's two false-positive classes on `/git`. Removal is roadmap batch 4 item 6. |

## Tier 6 — Audit (`docs/audit/`)

| File | Status | Notes |
|---|---|---|
| `2026-08-24-audit.md` | 🔵 Durable | **New tier + row** (SECURITY.md links it; no row existed). A dated snapshot: the `src/x.cyr:NNN` citations and A-1…A-12 ids are historical by design. All 11 findings fixed at 0.39.0; A-1's Windows `is_symlink` no-op is carried on the roadmap. Its standards link is the ❓ 404. |

## Refresh procedure

When docs are touched:

1. Find the affected row in the relevant tier table and update its **Status** / **Notes**.
2. Bump the version stamp in any Tier-1 doc that carries one (README status line, CONTRIBUTING status
   line, `state.md`/`roadmap.md` "Where we are").
3. Re-anchor the **Last refresh** line at the top — and **re-stamp the tables in the same pass**. Prose
   prepended over un-updated tables is lesson 3.
4. **Re-run every measurement the docs state** (`CYRIUS_STATS`, suite counts, build-lane status, byte
   counts, line numbers in quoted errors). Re-reading one is not auditing it.
5. When a milestone/version completes, record it in `CHANGELOG.md` (+ a `state.md` version entry) —
   **not** in `roadmap.md`, which is forward-only.
6. If a file has no row here, **add one** rather than assuming it is covered.

Cadence is **opportunistic** (touched when other docs are), not periodic — but a full sweep is worth
running at a minor closeout or when a release burst has piled up drift.
7. **At a full sweep, replace the "Touched at" notes with one sweep record** and re-stamp every row from a
   reader's verdict, not from the previous row. Fourteen releases of prepended notes over 0.43.2 tables is how
   this file re-learned lesson 3 at 0.51.0.

## What this file is NOT

- Not the [`state.md`](development/state.md) version ledger (which holds the per-version log +
  current-state block).
- Not a CHANGELOG (which records what shipped, not where each doc stands).
- Not a TODO list (open work lives in [`development/roadmap.md`](development/roadmap.md)).
