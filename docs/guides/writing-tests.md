# Writing a test

How the suites are laid out, how to add to them, and how to prove a test tests something.

## Layout

There are five suites, `tests/thoth_{core,agent,tui,gui,render}.tcyr`. Each is a standalone program: its own `src` includes, its case files, a `main()` calling its tests, and an exit. `gui` and `render` are deliberately lean. `core`, `agent` and `tui` pull in most of the tree.

Test bodies live in `tests/cases/`, and `testutil.cyr` holds shared byte helpers. The `.cyr` files there are includes, not programs.

```bash
cyrius test
```

```bash
cyrius test tests/thoth_gui.tcyr
```

The first runs `src/test.cyr` and every suite. The second runs one.

## Adding a test

1. Put the body in the matching `tests/cases/<domain>.cyr`, and any shared helper in `testutil.cyr`.
2. Call it from `main()` in the matching `.tcyr`.
3. Add any `src` include it newly needs. The compiler names what is missing.

A `main()` in a suite that arms `OUT_RING` calls `out_ring_sink_set(&feed_write)` first.

## Fixtures must be tracked

CI checks out only tracked files, so a test reading a gitignored file passes here and fails there. A local `thoth.cyml` once made an "ambiguous completion" test pass on one machine only.

- `git ls-files <path>` returns nothing for an untracked file.
- Safe fixtures: `VERSION`, `CHANGELOG.md`, `src/*.cyr`, `tests/fixtures/`.
- To prove the suite leans on nothing untracked, run it from a `git archive HEAD` copy.

## Vendor pins

`src/vendor/` is the one part of the compile set no compiler check covers: a stale or half-applied sync builds and passes everything else. `tests/cases/vendor.cyr` is the gate. A plain substring needle also matches the bundle's own changelog prose about that symbol, so:

- **Anchor to the line.** `"\nvar SYS_IOCTL"` can only be a module-scope definition. Add a positive control so a broken escape fails rather than passing on zero matches.
- **Partition, don't word-bound.** Assert `count("entry_hash") == count("_sit_entry_hash") + count("tree_entry_hash")`. A `\b` grep cannot see a partial rename, because `_sit_entry_hash` has no word boundary before `entry_hash`.

kashi is the exception: thoth vendors its freestanding `font_data.cyr`, which carries no version header, so pin its properties instead.

## Traps

- **The gate blocks on stdin.** A test reaching it with no t-ron bound waits at the confirm prompt. Bind an allow-all `tron_new` policy, and run suites with `</dev/null`. `test_tui_ask_rows` really reads stdin too, so it hangs where stdin is an open socket and passes in CI.
- **Tool pins carry across groups.** Call `toolpin_reset()` at the top of any group that formats a tool registry, or pin state from an earlier group withholds your test tool.
- **`agent_tools_add_*` bound their writes by `AGENT_TOOLS_CAP` (32768), not by your buffer.** A small stack buffer is a smashed stack. Pass `alloc(AGENT_TOOLS_CAP)`.
- **`strstr` returns an index,** with -1 for absent. It is not a pointer.
- **A test argv array indexes in bytes.** `var av[64]` holds eight pointers at `&av + 8`, `&av + 16`. `+ 1` crashes the unit with no assertion failure.
- **Stop when a premise fails.** A test that carried on after one did `kill(self, 10)` on the Mac, where signal 10 is SIGBUS.

## Break tests

A test that passes with the fix broken is not a test. Break every fix on purpose and watch its test fail.

1. Work in a scratch copy, never the checkout.
2. Run a baseline in that copy first.
3. `rm -f` the test binary before each build. A failed build leaves the old binary, which then passes.
4. Merge stderr, because `FAIL:` lines are not on stdout. Reading only stdout reports every break as missed. Judge by new `FAIL:` lines against the baseline.
5. A mutation that stops the build proves nothing: deleting one `if` of a chain usually does. Pick another.
6. A miss means the test is weak. Fix the test, not the count. A fake too fast to reach a tick, or sampled bands that never meet a checkpoint, both passed for the wrong reason.

Keep a hang's timeout at about 60 s, because a hang costs the whole timeout. To break a floor change, see `toolchain-refresh.md`.

## Model behaviour

A model is noisy, so an A/B of the binary is the only proof a change moved it: about 3 runs of 40 rounds each. A prose note on tool descriptions once looked like a fix, and the counts were noise (12 against 2 stray calls). It was removed.

Once the model stops taking a path, no prompt reaches that code. Build a probe with the path forced open. For the two-roots correction, that meant commenting out `agent_tools_add_project(...)` in `agent_turn`, so `fs_read` was the only file tool.
