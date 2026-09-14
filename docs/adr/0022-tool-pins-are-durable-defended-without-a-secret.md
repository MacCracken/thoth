# 0022 — Tool pins are durable, and the store is defended without a secret

**Status**: Accepted
**Date**: 2026-09-14

## Context

ADR-0021 closed with an open question: trust-on-first-use over a repo's authority keys is the natural
shape for per-repo trust, "but where is the trust record kept, and what defends *it*?" 0.42.0's tool
pins ([toolpin], the CVE-2025-54136 rug-pull defence) had already answered the first half by not
having a record at all: the pins lived in memory and died with the process. That was said plainly —
the defence caught a definition swapped *during* a session, not one swapped *between* two runs — and
the gap review named the between-runs half as gap 3, "a security-relevant file thoth writes and must
then defend (tamper, replace, symlink-redirect)". The maintainer decided at 0.50.1 to close it as the
sixth feature arc (0.51.0).

The constraints are the tree's usual ones. Security degrades closed: an unreadable or edited store must
never quietly become "first sight". Missing capabilities are announced, not faked. Authority keys are
global-only (ADR-0021): a cloned repo cannot ship a store of pre-approved pins. Every buffer is bytes;
no new dependency; the request goldens stay byte-identical while no store is bound. And one constraint
peculiar to this file: **thoth has no secret.** There is no key in the process, no keyring seam on the
spine, no t-ron custody API — t-ron authorises tool *names*, it holds nothing.

## Decision

**Pins persist across runs in a store thoth writes, and the store's integrity layer claims exactly what
a keyless process can defend.**

The store: `[toolpin].file` (an authority key, global-only, `~/` expands) or, unset, `~/.thoth/toolpins`
when the operator already has a `~/.thoth` (thoth creates no directory — the 0.45.3 root rule); with
neither, pins are session-scoped and the greeting, `/state` and `/tools` say so (one-shot's stderr speaks only
for a store thoth REFUSED, or a write that failed during the turn — a no-store run is not an error there).
The default is on because the 0.42.0 defence is on by default — a between-runs half that had to be
switched on would be a weaker floor than the in-session half it extends. `[toolpin].durable = false`
opts the store off; `[toolpin].enabled` moves to the same global-only reading (a repo's local
`enabled = false` used to switch the defence off, and `/reload` applied it live — the class ADR-0021
forbids).

The format is line-oriented text — greppable evidence after an incident — under one whole-file digest:

```
THOTH-TOOLPIN-1
<host>\t<name>\t<sha256 hex>\t<pinned epoch secs>
DIGEST\t<sha256 hex over every byte before this line>
```

A pin is **host + name**: `[daimon].url` at pin time — canonicalised (lower-cased, trailing slashes
dropped), so a re-spelling of the same daimon is the same namespace — is the identity daimon exposes (no
server id travels on the wire), so the same name on another daimon is another tool, never "CHANGED";
`/reload` rebinds the namespace when the url moves. `[daimon].url` stays a layered preference: a repo that
sets it points thoth at *another* daimon, whose tools honestly pin in their own namespace — the greeting and
`/state` name that, so the operator's own tool names are never read as a silent fresh first sight. The hash is 0.42.0's, unchanged: SHA-256 over
`name \0 description \0 inputSchema`, where `inputSchema` is bayan's compact re-serialisation of the
parsed tree in wire key order (whitespace and string escapes are canonical; key order is not — a server
that reorders keys reads as changed, which degrades closed, and is recorded below).

The semantics: a first run pins silently and creates the file at the first probe. Later runs compare —
a changed definition is withheld from the advertisement, refused at dispatch, and announced as
`CHANGED since it was pinned on <date> (a previous run)`, so the operator can tell a between-runs swap
from an in-session one. A tool absent from the registry *keeps* its pin (a vanish-and-return with a
new definition is precisely the swap). The in-memory table grew from 128 to 1024 pins for the same
reason: a store's rows are only ever added and must not crowd a live registry out of its slots (past
it the remainder is advertised UNPINNED, and said). A flush re-reads and re-verifies the file, keeps other hosts'
rows verbatim, unions same-host rows another session pinned since this one loaded (a pin is never
downgraded — except under `/tools trust`, when this host's rows go by the operator's hand), and writes
by temp + exclusive create at 0600 + `fsync` + rename. Any failure to verify — magic, row shape, count,
digest — rejects the *whole* file (a per-line skip would be first sight through the back door; the file is
verified whole *before* any row is applied), leaves it untouched as evidence, and makes the run
session-scoped, announced; only `/tools trust` rewrites a rejected store. The writer stops at the same row
cap the reader enforces (`TPS_ROWS_MAX`, 8192 rows across every host; the load cap `TPS_READ_CAP` is 1 MiB),
so thoth never writes a file it would then call edited. The store's ten states — unbound · loaded · new ·
rejected · a symlink · unreadable · over the cap · no path · `durable = false` · write failed — are the
one vocabulary every surface speaks (`src/toolpin.cyr`). A symlink at the path is
refused before anything is read or written (the check is `is_symlink` then open — there is no portable
`O_NOFOLLOW` on the floor, so the window between them is a named residual, not a defended one). A file the
load buffer cannot hold is never written back — not by `/tools trust` either. An unreadable-but-present
store is told from an absent one by `stat`, never by an open that fails for both.

**What the integrity layer honestly buys.** A MAC key would live beside the store under the same uid,
so a per-line HMAC would be a per-line SHA-256 wearing a costume; the whole-file digest is the honest
form of the same claim. It closes the CVE shape between runs — the MCP server or daimon swapping a
definition while thoth is down; neither touches the file. It catches corruption, a torn write, a foreign
writer, a stale format, a truncation. It does **not** catch a local user or a compromised process with
the operator's uid editing, replacing or deleting the store: a deleted store is a silent first sight on
the next run, and the only signal is the greeting row reading `new` where it read `N pinned`. What holds
against that uid's neighbours: 0600 on every write on POSIX targets (the rename replaces the inode with
thoth's own temp, so a pre-existing looser file is 0600 after the first flush — neither the session nor the
history store can say that; AGNOS's open carries no create mode at all and Windows's is an ACL hint — the
floor rows), the symlink refusal, and ADR-0021. The `pinned on <date>` in a withheld notice is a UTC calendar
date.

## Consequences

- **Positive** — the rug-pull defence now spans runs, which is where a swap is cheapest to plant and
  where an unattended one-shot run (bound through the same line in `main.cyr`) is most exposed. The
  store is a text file an operator can read in an incident. `[toolpin].enabled` can no longer be
  switched off by a repo. `/tools` shows each tool's pin state; `/state` and the greeting box say where
  the trust record lives on every surface.
- **Negative** — thoth owns one more file it must defend, and the defence has a stated ceiling (a
  same-uid editor). A write that fails mid-session stops persistence for the run (state 9, named on every
  surface; `/tools trust` may retry the rewrite) — the pins taken after it are not saved. Two sessions trusting the same host at once are last-writer-wins on that host's rows
  (the history file's residual). The PE lane's `is_symlink` is a no-op, so the symlink refusal does
  not hold there (the lane is closed anyway); AGNOS drops `O_EXCL` on the temp's create (a plain
  create) and has no per-fd `fsync` (a whole-fs sync stands in). A repo-local `enabled = false` that
  used to work is now reported as suppressed — a behaviour change, named in the CHANGELOG.
- **Neutral** — the schema key-order sensitivity is 0.42.0's and stays: a false CHANGED withholds (closed),
  never allows; canonicalising keys before hashing is a patch candidate if a real server reorders them.
  Per-tool trust (`/tools trust <name>`) is a natural later patch; 0.51.0 keeps 0.42.0's wholesale
  trust. The `--events` stream gains no new kind.

## The spine's eventual home

daimon 2.1.3 keeps its registry in memory, accepts `POST /v1/mcp/tools` without auth, overwrites on
the same name, and exposes no per-tool identity or hash. The correct end state is daimon pinning once
for every consumer — a persisted registry, a `definition_sha256` and `pinned_at` per element in the
manifest, an audit event on change, and a per-consumer trust verb through t-ron. When daimon ships a
manifest hash, thoth compares its own to daimon's (a mismatch means the two disagree about
canonicalisation — announced) and thoth's store becomes the operator's local record rather than the
only defence. Until then this store is the client-side floor. The ask is recorded in the roadmap's
waiting table.

## Alternatives considered

- **A per-line HMAC or a signed store** — rejected: no secret exists to key it; the claim would be
  theatre (the 0.42.0 header's own standard).
- **Opt-in like `[session].file`** — rejected: a rug-pull defence nobody switched on is the CVE
  re-opened; the default follows the in-session half's default.
- **Per-line skip of a bad row** — rejected: an accidental edit would silently drop pins, which is first
  sight through the back door.
- **Dropping the pin of a tool absent from the registry** — rejected: that is the swap's own shape.
- **A confirm modal or a t-ron verb for `/tools trust`** — rejected for this minor: a typed slash command
  is the operator's own act (the `/allow` precedent), the TUI's loop-level modal is unusable mid-turn,
  and a new reserved verb is policy surface every operator's `[tron].policy` would have to learn. It is
  logged at WARN with the host and count instead — and an `[alias]` (a repo-settable preference) may not
  expand to it or to `/allow`: a line reached through expansion was not typed by the operator, so it is
  refused whole.
- **Waiting for daimon** — rejected as the only answer: the spine's home is recorded above; the floor
  ships now.

## Addendum (0.51.1)

The 0.51.0 doc sweep found the store's one gap this ADR did not name: `_project_sensitive` — the rule
that keeps the model's jailed tools off thoth's own state files — did not name `[toolpin].file`. The
default `~/.thoth/toolpins` was covered by the `.thoth` component rule; a custom path inside the
project jail was readable and, with `[edit].enabled`, rewritable — a swapped definition re-baselined
through thoth's own `edit`, which the digest cannot catch (the model's `edit` runs as the operator).
Closed at 0.51.1: the pin store is the fifth configured path the jail refuses.
