# Going through the not-verified list

How to prove a claim where it lives: on a real provider, on iron, on another OS, at scale. Each section is a run that was done and can be repeated, and the
results are in `state.md`'s Targets section. Rerun a section when its lane or the spine moves. What a run finds joins the next cut, with a test.

The hosts are `ecb` (an Apple Silicon Mac), `cass` (Windows 11 x64) and `pi` (a Raspberry Pi on aarch64 Linux). All three are SSH hosts.

## Before any row

Build the binary under test on the tree under test:

```bash
cyrius build src/main.cyr build/thoth
```

Copy the tree to another host like this, so a local config never leaves the machine:

```bash
rsync -a --delete --exclude /build --exclude /.thoth/config.cyml ./ ecb:thoth-verify/
```

- **Anchor both excludes.** `--exclude /.thoth/config.cyml` keeps your local config home and `--exclude /build` skips the build output. Without the leading slash they also drop the tracked
  fixtures `tests/fixtures/home/.thoth/config.cyml` and `tests/fixtures/map/build/`, and about a dozen rows then fail with no fault in the code.
- **A tree with no `.git` runs a few assertions fewer.** Copy `.git` too, with `HOME` set to an empty directory, for a run comparable to the release's.
- **Hold stdin both ways for a final suite run:** closed with `</dev/null`, and open through a FIFO. Never use `nohup … &`: it makes the shell
  ignore SIGINT, and a test then fails on the harness.
- **Under a sandboxing agent,** a compiled binary's local TCP needs the sandbox off.
- **A project under your real home walks up into your real `~/.thoth`,** whatever `HOME` says, and takes it as a local layer. Keep a lab outside `~`: `/var/tmp` is on disk here.
- **Wait for a stub to answer before driving thoth at it.** `curl -s http://127.0.0.1:PORT/v1/health` is enough. A cold Python on the Mac has
  lost that race.
- **Keep the old binary** in scratch and A/B every live claim against it. `/proc/PID/io`'s `syscw` counts write calls where there is no strace. Tell builds apart by hash, not size: cyrius binaries page-align, and three different builds once had the same size.
- **A wrapper can hide a signal bug.** `timeout(1)` gives its child a clean ignored-signal mask: an ignored SIGPIPE in the shell is gone under it, and an ignored-SIGCHLD regression read as
  cleared under `exec timeout 20 thoth`. An agent's Bash tool hands every child an ignored SIGPIPE. Run a signal repro without the wrapper, against a control binary.
- **Hold stdin open with a FIFO, not `sleep N |`.** A stray `sleep` breaks `ptydrive.py`'s `gone sleep`. Kill strays by pid, never with `pkill -f` or `pkill -x`.
- **A config file with `---` fences reads as no config at all,** so an A/B on it shows nothing.

## V-1 — The real spine

Build hoosh, daimon, bote and mneme at their tags in a scratch copy, and point `AGNOS_STACK_HOME`, `HOOSH_DIR`, `DAIMON_DIR`, `BOTE_DIR` and `MNEME_DIR` at it, so your repos and
`~/.agnos-stack` stay as they are. Do not pass daimon `--version`: it has no such flag and starts serving. Stock `hoosh.cyml` caps its default budget pool at 100,000 tokens, which about fifteen turns
exhaust, so raise `[[budgets]]` in the copy.

```bash
scripts/stack.sh up
```

```bash
scripts/stack.sh status
```

Use a real model id from `GET /v1/models/catalog`, and run outside any checkout so a repository's local layer cannot override the config.

| Claim | Drive it | Passes when |
|---|---|---|
| W-6, the blocking path | `[hoosh].stream = false`, a task making two parallel `read_file` calls (haiku goes one at a time; sonnet will do both) | Every round is accepted. A pairing fault is a 400 from the provider |
| W-6, a delegated child | `[hoosh].stream = true`, a task that delegates (children take the blocking path) | The child's rounds are accepted, with normalized calls |
| W-10 | A project holding `printf 'caf\xe9 \xff\xfe end\n' > bad.txt`, and a task that reads it | A reply, not a 400. The request carried U+FFFD |
| T-3 | `/remember` a fact, then ask for it in a new session | Recall arrives redacted and guarded, and only from a global `[daimon].url` |
| T-3, the pin | Re-register `mneme_search` with a changed description (`POST /v1/mcp/tools`), then a new session's first turn | `--logs` shows the withhold and no `authz tool=mneme_search`, and the model does not know the fact |
| The spine moved | `/models`, `/tools`, a streaming turn with usage, a stop | Each still works against hoosh 2.10.0 and daimon 2.5.3 |

Run `thoth --logs FILE` throughout, so a failure has its record.

```bash
scripts/stack.sh down
```

## V-2 — The project map's effect

In the same bring-up, give a real model the same ten navigation tasks in a project of a few hundred files, once with `[project].map = true`
and once with `false`:

```bash
grep -c list_dir run-map-on.log run-map-off.log
```

Report `list_dir` calls per turn, and the bytes the map added per round. This also informs gap-review question 5.

## V-3 — A large repository

Generate the tree on disk, not on tmpfs, and outside your home. `/tmp` is tmpfs on this machine.

```bash
python3 -I -c "
import os,subprocess
r='/var/tmp/thoth-big'
for d in range(1000):
    p=f'{r}/d{d:03}'; os.makedirs(p,exist_ok=True)
    for f in range(100): open(f'{p}/f{f:02}.txt','w').write(f'{d} {f}\n')
subprocess.run(['git','init','-q'],cwd=r); subprocess.run(['git','add','.'],cwd=r)
subprocess.run(['git','-c','user.name=v','-c','user.email=v@example.invalid','commit','-qm','tree'],cwd=r)"
```

Drive thoth in it against `scripts/live/stubhoosh.py`, with `scripts/live/ptydrive.py` for the TUI:

- time to the first frame, and a turn's wall time (the git walk runs in a child, so neither should see it);
- `/tree`, the `search` tool and the project map, each of which must finish, stay bounded and name any cut;
- RSS over ten turns;
- a long session's save on this disk: 200 turns of 4 KB each. The store holds a bounded history, so per-turn time should stay flat.

Remove the tree afterwards.

## V-4 — aarch64 on iron

```bash
for s in core agent tui gui render; do cyrius build --aarch64 tests/thoth_$s.tcyr build/a64_$s; done
```

```bash
rsync -a --delete --exclude /.thoth/config.cyml --exclude 'build/live' ./ pi:thoth-verify/
```

```bash
ssh pi 'cd thoth-verify && for s in core agent tui gui render; do build/a64_$s </dev/null 2>&1 | tail -2; done'
```

```bash
ssh pi 'rm -rf thoth-verify'
```

The `rsync` above carries `.git`. Run with `HOME` set to an empty directory, and expect the release's counts plus two. The Pi has 1.8 GB of memory and about 4 GB free. Remove
`build/a64_*` here when done.

The Pi drops off the network mid-`rsync`, and a half-synced tree fails with false numbers. Add `--timeout=30` and retry until it exits 0. It also caught test windows and kill deadlines too tight for a slow host, so read a timeout failure there as a finding.

## V-5 — macOS under attack

Use the pinned toolchain through a private `CYRIUS_HOME`. Non-interactive SSH on `ecb` has no cyrius on `PATH`, and the private home leaves its own `~/.cyrius/current` alone:

```bash
ssh ecb 'export CYRIUS_HOME=/tmp/cyrius-pin-6718 PATH=/tmp/cyrius-pin-6718/bin:$PATH; cd thoth-verify && mkdir -p build && cyrius build src/main.cyr build/thoth && python3 -I scripts/live/hostile-wire.py build/thoth'
```

`ecb` cannot reach GitHub, so `cyrius install` and `cyriusly install` both fail there. If `/tmp/cyrius-pin-<version>` is gone, ship the toolchain from this machine:

1. `git -C ~/Repos/cyrius archive <tag>` into scratch, copy `~/.cyrius/versions/<tag>/bin/cycc` to its `build/cycc`, and run `sh scripts/build-macos-arm64-tarball.sh <out>`.
2. `scp` the tarball to `ecb` and unpack its `bin`, `lib` and `VERSION` into `~/.cyrius/versions/<tag>/`. Never touch `current`.
3. Run `xattr -c` and `codesign --force -s -` on every non-`.sh` file in `bin`. The binaries are cross-built unsigned, and macOS kills them on first run with exit 137, which looks like a crash.
4. Build the private home:

   ```bash
   ssh ecb 'V=6.7.18; P=/tmp/cyrius-pin-6718; mkdir -p $P; ln -s ~/.cyrius/versions/$V/bin $P/bin; ln -s ~/.cyrius/versions $P/versions; echo $V > $P/current'
   ```

The stock wrapper runs `$CYRIUS_HOME/bin/cycc`, not the pinned one. Pointing `CYRIUS_HOME` at `~/.cyrius` runs whatever `current` is, and the errors look like source faults (`expected identifier, got reserved keyword 'f64_le'`). Pointing it at a version directory looks for `versions/<V>/versions/<V>/lib`.

macOS has no signalfd, and signal 10 is SIGBUS there.

A clean run prints the scenario count, no `!!` line, and exits 0. Then, by hand, the attacks the 2026-11-05 audit ran on Linux:

- `yes &` through the `shell` tool: the job dies at its next write;
- a command swapping a FIFO into the capture's place: thoth keeps its deadline;
- a FIFO in the tree, reached by `read_file`, `search`, `edit` and `@`;
- a `[session].file` that is a link, one at 0644, and one owned by someone else;
- a killed thoth, which leaves no process of a running command.

macOS has the line tier only, so the TUI's attacks do not apply there. `/read` is not jailed and is not meant to be: it is the operator's own command, printing to their terminal, and
nothing goes to the model.

## V-6 — Windows past `--version`

The lane stops on nine names in vendored bundles, none of them reached by a thoth call. Build a throwaway PE in a copy of the tree, never in the checkout, with
this block above the first `include` in `src/main.cyr`:

```
#ifdef CYRIUS_TARGET_WIN
enum WinStubNames { SIGHUP = 1; SIG_BLOCK = 0; SIG_SETMASK = 2; SYS_GETEUID = 107; SYS_FCHMOD = 91; SYS_GETCWD = 79; O_CLOEXEC = 524288; O_NONBLOCK = 2048; }
fn sys_fstat(fd, st) { return 0 - 1; }
#endif
```

```bash
cyrius build --win src/main.cyr build/thoth.exe
```

```bash
scp build/thoth.exe cass:thoth-verify.exe
```

`cass` answers in PowerShell 5.1, so send bare PowerShell in single quotes and do not nest `powershell -Command`:

```bash
ssh cass '& .\thoth-verify.exe --version; Write-Output ("exit=" + $LASTEXITCODE)'
```

Reach a stub gateway on this machine through a reverse tunnel, with `-R 18194:127.0.0.1:18194`, and write the drive as a `.ps1` file that is copied over and run with
`powershell -NoProfile -ExecutionPolicy Bypass -File`. Set `HOME` for the run, or the global layer is not found. Drive `--events` with the stub's `read:` and `run:`, with a policy that allows `thoth_shell`, since a
confirm cannot be answered there. Never pass `read: CON`: it hangs the run. An unrouted syscall exits `-1073741795`. The roadmap's waiting table says what must land before anything ships on PE. Remove the
executable from `cass` when done.

## V-7 — Six files no auditor read

Done on 2026-11-05: `src/mpick.cyr`, the store half of `src/toolpin.cyr`, `install.sh`, `scripts/live/wlkit.py`, `scripts/live/pngtool.py` and `scripts/gen-splash.sh`. For the next ones, read them as
the audit read the rest: one area, a frozen copy of the tree, and a reproduction before anything is filed. Findings go in a dated file under `docs/audit/`.

## The ring-3 smoke

This is not a table row, because every release runs it. `--private` builds the selftest kernel in a throwaway copy of the agnos tree, so the operator's own `build/agnos` is
never replaced:

```bash
./scripts/agnos-run.sh --private
```

The same copy shape runs any other `--agnos` binary, through `agnos/scripts/smoke/basestack-run-smoke.sh ELF EXPECT NAME`.

Run it serially. The harness writes one log per name and overwrites it, so a parallel run can read another's failed boot as its own. To check that a pass means something, give it a wrong expect string and watch it fail.

## A turn that gets stuck or comes back empty

Find out whose bytes are wrong before reading code. This found every "gets stuck" bug so far:

1. **Capture.** Put a logging proxy between thoth and hoosh: a small Python listener that forwards `POST /v1/chat/completions` to `:8088`, writes each request and response to a numbered file, and returns them unchanged. Point a scratch project's `.thoth/config.cyml` at it, so nothing global changes. The files show whether the gateway sent the bad bytes or thoth misread them.
2. **Replay.** Send a captured body with `curl`. This turned a random failure into 3 of 3. Replaying it at the provider directly separates the gateway from the model.
3. **Bisect** the message list, cutting only at complete assistant-and-tool-result groups. A cut inside a group is an invalid conversation and fails for its own reason.
4. **Control for size.** When a failure looks size-shaped, send equal-byte payloads of different token density. 20 KB of `yyyy` and of `word word` passed, and 20 KB of unique hex came back empty, which pointed at the provider's token count rather than the gateway's handling of large bodies.
5. **Flip one thing.** Hold the body constant and change `stream`. That found hoosh's local streaming path dropping `tools`.
6. **Run the real binary on a pty.** `curl` passed while the real path failed, and a one-shot `-p` hides the `tool-call:` and `result:` trace.
