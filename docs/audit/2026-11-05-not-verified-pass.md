# thoth — the not-verified pass, 2026-11-05 (on the 0.53.3 tree)

Scope: everything the [2026-11-05 audit](2026-11-05-audit.md) said it had not proven, run where the claim lives: a real provider and the real spine, real
ARM, macOS, Windows, a 100k-file repository, and the six files no auditor had read. Recipes are in
[`../guides/verification-pass.md`](../guides/verification-pass.md).

**The result: every row was run, and running them found what reading had not.** Two fixes shipped in 0.53.3 did not work on the real stack. Two auditors read
the six files and filed 35 findings: 0 CRITICAL, 0 HIGH, 8 MEDIUM, 27 LOW. Five of the MEDIUMs are in the cyrius installer. 21 are fixed, and the rest are placed on the roadmap
or named in an ADR.

---

## The runs

| Row | Where | Result |
|---|---|---|
| **The real spine** | This host: hoosh 2.10.0, daimon 2.5.3, bote 3.8.15, mneme 1.1.4, Anthropic | Turns, delegated children and parallel rounds, on the streaming and blocking paths, all accepted. Stop 1.9 s on a live stream. `/models`, `/tools`, a model switch and `memory_write`'s prompt behave. **W-10 and T-3 failed, below.** |
| **The project map's effect** | The same stack, claude-haiku-5-5, ten navigation tasks in a 186-file tree, map on and off | On the nine valid tasks: 108k against 147k tokens (27% fewer), 12 against 18 searches, 1 against 3 `list_dir` calls, median 5.7k against 12.7k tokens a turn. One run each, so a direction, not a rate. The tenth asked for a file the copy lacked, and is left out. |
| **`.THOTH` on APFS** (T-7) | A Mac, on a case-insensitive volume | `read_file` refuses `.THOTH/note.txt` and `.ThOtH/note.txt`, both the same file as `.thoth/note.txt`, while an ordinary file reads. No marker reached the gateway. |
| **The confirm card** (G-1) | Headless compositor, the stub's `curly` | Curly quotes and a dash draw as boxes, never as straight quotes. |
| **Ring 3** | agnos 1.57.17, gnoboot 0.9.0 | thoth 0.53.3 and hoosh 2.10.0 each load, print their version and exit cleanly. |
| **A large repository** | 100,000 files on a SATA SSD | First frame 1.2 s. `/git` correct in 3.3 s. The map degrades to its one-line notice, `list_dir` works, `search` stops at 4,000 files in 41 ms. 200 turns of 4 KB save in about 6 ms a turn, flat, with RSS flat at 15 MB. **`git_probe` grows the heap 48 MB a turn, below.** |
| **aarch64 on iron** | Raspberry Pi, Ubuntu 26.04 | 2383 + 1530 + 904 + 948 + 190 = 5,955 assertions, 0 failed, on the final tree, in a checkout shape with an empty `HOME`. |
| **macOS under attack** | The Mac, native build | `hostile-wire.py`: 151 scenarios, none flagged. 17 checks held: links and FIFOs in the tree, `yes &`, a quiet background job, the deadline, a killed thoth, OSC bytes, a linked, loose or foreign session store, a new store at 0600. |
| **Windows past `--version`** | Windows 11, a scratch PE with the lane's nine vendored names defined | A streaming and a blocking turn, `read_file`, a `cmd.exe` capture and its deadline all work, and no temp file is left. **The read jail does not hold, below.** |

## What running found

| ID | Sev | Finding | State |
|---|---|---|---|
| V-1a | HIGH | **A file with invalid UTF-8 failed the turn.** `_agent_work_puts_esc` is a second escaper, which W-10's fix missed, and `hoosh.cyr`'s comment called the other one the only one. A Latin-1 file, a binary or a tool's output sent raw bytes, Anthropic refused the whole request, and the operator saw a bare 502. A repository can arrange this with one file. | **Fixed.** Bad bytes go out as U+FFFD. Proven against the provider with a Latin-1 file and 3 KB of random bytes. |
| V-1b | MED | **A swapped `mneme_search` was called on a session's first turn.** T-3 made recall honour `toolpin_withheld`, but only the tool-list build fills that table, recall runs before it, and a plain turn or a command never builds one. Every one-shot sent its prompt to the swapped tool and injected the answer. The log showed `authz tool=mneme_search` before `withheld_definition_changed`. | **Fixed.** The memory channel compares mneme's definitions once, before its first call, on every path. `/notes` had no check at all, and has one now. Proven on the real stack: no call, and the model says unknown. |
| V-1c | LOW | A gateway's error body is dropped on a streaming turn: `token budget exceeded` reads as "error body not surfaced in stream mode". | Batch 15. |
| V-1d | LOW | mneme answers "Failed to create note" for a title it holds, so `/remember` of a saved fact reads as a failed write. | The waiting table. |
| V-3a | MED | **`git_probe` grows the heap 48 MB a turn on 100k files.** 37 → 515 MB over ten turns, with no ceiling, and each probe holds the main thread for 1.8 s. The audit measured 166 KB on this tree and read it as a small cost. | Batch 15's first item. |
| V-3b | LOW | A real model read `no matches within the search limits` as "not in the project". | **Fixed.** It counts the files read and says the rest was not searched. |
| V-6a | HIGH on PE | **The read jail does not hold on Windows.** `..\x`, `sub\..\..\x`, `C:\x`, `C:/x`, `\\?\C:\x` and `\\127.0.0.1\C$\x` all read outside the project, and `CON` hangs `read_file`. The lane does not ship, and the roadmap already barred it on this. | The waiting table, now with the cases. |

A wrong note worth keeping: the "seven core rows that fail in a scratch copy" were our own rsync patterns. `--exclude .thoth/config.cyml` dropped the tracked fixture
`tests/fixtures/home/.thoth/config.cyml`, and `--exclude build` dropped `tests/fixtures/map/build/`. Anchoring both removes every such failure.

## The six files

### `src/mpick.cyr`, and the store half of `src/toolpin.cyr`

| ID | Sev | Finding | State |
|---|---|---|---|
| A-1 | MED | `read_ms` bounds each read, so a gateway sending one byte a second held Ctrl-P for as long as it liked, with Esc unread. 690,000 routes held it 9 s more. | **Fixed:** a whole-call deadline on probes and the catalog, and routes bounded by `HOOSH_ROUTE_MAX`. |
| A-2 | MED | A store others could write was trusted in silence, with no first flush to tighten it, and a neighbour's re-signed row passed. | **Fixed:** the operator's own loose store is named on every surface and rewritten 0600. Another user's is rejected. |
| A-3 | MED | One-shot and the line banner said nothing when a repository re-spelled `[daimon].url`, so no stored pin applied. | **Fixed:** one line on each. |
| A-4 | LOW | Every refused store means first sight, so a swapped tool is advertised, with one line said. ADR-0022's choice, but not "degrades closed". | gap-review question 8. |
| A-5 | LOW | A FIFO at the store path hung startup with nothing printed. | **Fixed.** |
| A-6 | LOW | A store behind an unreadable directory read as new, so as first sight. | **Fixed.** |
| A-7 | LOW | A repository's daimon rows land in the operator's global store and never expire. 11 runs filled it to the cap. | Batch 15. |
| A-8 | LOW | No lock around a flush: 39 of 400 simultaneous starts lost one host's rows. | Named in ADR-0022. |
| A-9 | LOW | `/tools trust` overwrote a file past the cap, which ADR-0022 says never happens. | **Fixed.** |
| A-10 | LOW | Past the pin table, the UNPINNED notice was invisible in one-shot and the window. | **Fixed.** |
| A-11 | LOW | `/tools` printed `pinned` beside a swapped definition before the first probe. | **Fixed:** it says CHANGED. |
| A-12 | LOW | `/state` kept counting a tool trusted by name. | **Fixed.** |
| A-13 | LOW | An id over 255 bytes showed one id and applied another. | **Fixed:** refused and counted, and the echo reads the stored id. |
| A-14 | LOW | Rows clip by bytes, mid-character, with no mark. | Batch 16. |
| A-15 | LOW | Bidi and zero-width characters in an id reached the terminal, so `stub\u200b-model` looked like `stub-model`. | **Fixed:** refused and counted. |

Held: a differential fuzz of the store's parser against an independent oracle, 600 of 600; thoth's digest against hashlib, 70 of 70; every cap exact; no control byte from a
catalog reached the terminal across 17 byte classes; a bad file leaves no rows behind; symlinks are never followed.

### The install script, the live kit and the splash

| ID | Sev | Finding | State |
|---|---|---|---|
| B-1 | MED | **A fresh runner never checks the toolchain's signature.** With no `cyrsign` yet, `install.sh` trusts a sum from the tarball's own origin, and that file can name another file. Our workflow comments said otherwise. | Comments corrected. The installer is upstream: the waiting table. **Pinning both downloads in this tree: batch 15.** |
| B-2 | MED | The installer compiles `programs/dlopen-helper.c` from the caller's working directory. thoth selects no libssl, so it is not reached. | Upstream. |
| B-3 | MED | `rm -rf` of a real `bin` or `lib` under `CYRIUS_HOME`. | Upstream. |
| B-4 | MED | The Starship snippet prints a repository's `VERSION` raw into the prompt. | Upstream. |
| B-5 | MED | A broken install reports success. | Upstream. |
| B-6, B-7, B-9, B-10 | LOW | Activation is not atomic; a fetch failure falls through to an unverified clone; a reinstall can exit 1; no network timeouts. | Upstream. |
| B-8 | LOW | A truncated `curl \| sh` exits 0 half-applied. | Upstream; batch 15's pin closes it for thoth. |
| B-11 | LOW | A `.pyc` was tracked, and bytecode can run in place of the reviewed source. | **Fixed:** removed, `__pycache__/` ignored. |
| B-12 to B-16 | LOW | `wlkit.py`: a client leaving or a malformed event killed `serve`, a client set its pacing, screencopy geometry was never checked, a short header stopped the parser, compositor strings reached the terminal raw. | **Fixed.** |
| B-17 | LOW | `pngtool.py`: nothing bounded a PNG's size or inflation. | **Fixed.** |
| B-18 to B-20 | LOW | `gen-splash.sh`: `magick` chose its decoder by content, the output was truncated first and written through a link, and a newline in `SPLASH_GAMMA` added source lines. | **Fixed.** The real TIFF still reproduces the committed file byte for byte. |

Held: **no image byte can reach `src/splash.cyr` as code.** With a verifier present, the installer refused a bad signature, a wrong sum and a stripped signature. GNU tar stopped every escape.

## Verification

Suite **948 + 2381 + 1530 + 904 + 190 + 6**, 5,953 assertions, 0 failed, with stdin closed and held open. All five suites pass under `qemu-aarch64` (5,953 of 5,953), on the Pi (5,955) and natively on macOS
(2372 + 1520 + 892 + 933 + 190). Warning sets match the last commit on all four lanes. The window was driven live with the patched kit, and the real spine reran on the final tree: the picker opened 120 models, and `bad.txt`
passed in the TUI and on the blocking path.

Each fix carries a test. 23 were broken on purpose in a scratch copy, and each failure was judged against that copy's own baseline. The route cap in `hoosh_routes_fold`, the one-shot
stderr lines and `tool advertisement full` have no test of their own: the first shares the tested cap's shape, and the rest were proven live or follow the tested site.

## Not covered

- The window on any host but this one, and a real second uid for A-2.
- AGNOS past `--version`. That is the 0.55.x arc, and its hostile pass.
- Real Ed25519 in the installer, dash, bsdtar, and a real root run.
- A terminal that renders bidi, for A-15.

## Conduct

- **Two `hello` prompts reached the operator's configured gateway.** A lab under `~` walked up into the real `~/.thoth/config.cyml` despite a fake `HOME`, and took it as a local layer. The lab moved to
  `/var/tmp`, and the guide says why. The config was not read.
- Provider traffic was under a million tokens through the operator's key, nearly all claude-haiku-5-5.
- `daimon --version` has no such flag and started a daimon, which ran for about a minute until it was stopped by pid.
- Auditor A's `pgrep -f` pattern killed its own shell, and it moved to exact pids. Auditor B's 512 MiB test overran and was stopped by pid, and a safety check stopped one `rm` before it ran.
- Temporary files on the Pi, the Mac and the Windows host were removed.
