# Moving the cyrius pin

How to move `cyrius = "X.Y.Z"` in `cyrius.cyml` and refresh the bundles in `src/vendor/`. Each step is here because a refresh went wrong without it, and most of them apply to any cyrius consumer.

A green suite proves little here. The failures that cost the most passed it.

## What the request means

- **"To the pinned versions":** each bundle at its newest tag whose own `cyrius =` pin is at or below the new toolchain. Read the pin at each tag, not at the checkout:

  ```bash
  for t in $(git -C ~/Repos/sit tag --sort=-v:refname | head -20); do printf '%s ' "$t"; git -C ~/Repos/sit show "${t}:cyrius.cyml" | grep -m1 '^cyrius'; done
  ```

- **"To latest":** each bundle at its newest tag.

## Before moving anything

**Save the warning set of every target.** Build and read `--aarch64`, `--agnos` and `--win` as well as the host. A conflicting `SYS_IOCTL` warning sat in `--aarch64` output for about 30 releases because nobody read it, and four call sites issued the wrong syscall on arm64 the whole time.

```bash
cyrius build src/main.cyr build/w 2>&1 | sed 's/^compile .*\] //' | grep '^warning' | sed -E 's/:[0-9]+:[0-9]+:/:/' | sort -u > build/warn-x86_64.old
```

The first `sed` matters. The compiler prints its first warning on the `compile … ->` line, so a plain `grep ^warning` loses whichever warning sorts first, and a reorder reads as a fix.

**Read the floor for contract changes.** A large range runs to tens of thousands of changelog lines, so don't read it straight through. Start at the dep's `docs/development/ecosystem-migration.md` at the tag, then diff only the `lib/` modules thoth compiles, then the headlines. A background reader briefed on contract changes works well if it lists what it did not cover. Verify every claim yourself, especially severity words and "unchanged" or "identical". Read a bundle's "behaviour callers will see" section as closely as the floor's notes.

**Diff the symbols.** Do this for `fn`, for `private fn`, for top-level `var`, and for enum members, which are as silent as a duplicate `var`:

```bash
for v in OLD NEW; do grep -rhoE '^\s*(public |private )?fn [A-Za-z_][A-Za-z0-9_]*' ~/.cyrius/versions/$v/lib/*.cyr | sed -E 's/.*fn //' | sort -u > build/fns-$v.txt; done
```

```bash
comm -23 build/fns-OLD.txt build/fns-NEW.txt
```

```bash
for v in OLD NEW; do awk '/^enum /,/}/' ~/.cyrius/versions/$v/lib/*.cyr | grep -oE '[A-Za-z_][A-Za-z0-9_]* *=' | sed 's/ *=//' | sort -u > build/enum-$v.txt; done
```

Grep each removed name against `src/`. Read the added names too: a pin bump delivers capabilities as well as risks, and `O_NOFOLLOW` arriving at 6.6.4 is what closed a symlink-swap residual.

**A contract can change with no symbol diff.** These all happened with nothing in the symbol sweep:

- A rewritten bayan TOML parser began pushing an empty root section, and every config reported a phantom unknown key.
- `file_write_all` stopped returning a partial count, so `rc < len` branches went dead and the suite stayed green. Grep for them whenever a writer changes.
- `bayan_toml_parse` stopped ending the process and returned 0, which made a vanished authority config silent. When an error path gets gentler, re-read its callers: an unchecked return was safe only while the crash stood in front of it.

**Check the dep's `docs/development/issues/archived/`,** not only your own filing. Two limitations thoth carried as open had been fixed below the pin it was already on.

## The bump

1. Move the pin first, then re-vendor. A big bundle on an old toolchain can overrun tables the new one raised.
2. Sync the whole snapshot, then compare every file. `cyrius lib sync` once skipped any file of equal size, and its shadow warning names only versioned bundles, so it is not a completeness check:

   ```bash
   cyrius lib sync --full
   ```

   ```bash
   P=~/.cyrius/versions/$(grep '^cyrius = ' cyrius.cyml | cut -d'"' -f2)/lib; for f in $P/*.cyr; do cmp -s "$f" "lib/$(basename $f)" || echo "DIFFERS: $(basename $f)"; done
   ```

   For an offender, remove it from `lib/` and sync again. `lib sync` never deletes, so repo-local files survive.
3. **Run every suite before touching source,** on x86_64 and as aarch64 binaries under `qemu-aarch64` (the build line is in `verification-pass.md`, V-4). A wrong native syscall number builds without a warning and fails only there. Several assertions off by exactly one usually mean a single extra element, not several bugs.

`cyrius build` itself re-resolves `[deps]` and rewrites `lib/`, so expect an A/B baseline build to dirty the tree.

## After the bump

- **Diff the warning set per target,** then again after each bundle. A new `undefined function` line is never noise: a reachable one refuses the build, and an unreachable one leaves placeholder bytes in a live binary, so it usually means a missing `[deps].stdlib` entry. A target that loses warnings is a result too: confirm it is a fix, then re-baseline.
- **Grep `scripts/` for quoted compiler text.** Compiler wording is not an API. 6.6.10 reworded a message and `build.sh`'s reachable-undefined check saw nothing for several releases. Pair any such grep with an independent witness, such as the compiler's own count.
- **Re-read the caps, both numbers.** `CYRIUS_STATS=1 cyrius build src/main.cyr build/w` prints `fn_table`, `identifiers`, `var_table` and `fixup_table`. A roadmap once tracked a tightest cap at 60% when the denominator had grown 128 times.
- **Re-read every list that excuses a failure,** and probe what is left. `build.sh`'s `ARCH_GAP` and `VENDOR_GAP` are the first place to look. An "architectural" Windows gap had been gone for a while before anyone tried.
- **Expire your stopgaps.** A consumer's native-number stopgap breaks when upstream adds the translation row: thoth's literal `46` for `ftruncate` became `sendmsg` at 6.6.5, with a warning-free build.
- **Probe security controls with realistic payloads through the real entry point,** A/B across the bump. t-ron's rewritten scanner passed every suite because the fixtures were short words. Ordinary commands showed the change. Report a security trade-off to the maintainer: don't resolve it yourself.
- **Run `scripts/toolchain-sums.sh`** and read the diff. CI trusts that file, and `tests/cases/vendor.cyr` holds it to the pin.
- **Tell the maintainer about new files.** A first `cyrius.lock` or new `lib/` files land untracked and belong in the same commit.

## Bundles

- **Use `scripts/sync-*.sh`, never `cp` from a `dist/`.** The scripts apply collision renames a bundle cannot know about (`entry_hash` → `_sit_entry_hash` against libro, `_reg_ieq` in vyakarana). Copying by hand brought two last-definition-wins collisions back, and they nearly went upstream as a regression.
- **`*_LOCAL=` copies a checkout's HEAD,** which can sit on a newer toolchain line than the tag you want. Prefer the default fetch, then `cmp` the result against the tag.
- **Generated bundles carry `Requires` include lines.** These dedupe against `[deps].stdlib`, except where thoth vendors a lean profile of something the stdlib also ships: sit-read's `lib/sankoch.cyr` against the zlib profile gave 161 duplicate functions, with the older copy winning.
- **Update the pins in `tests/cases/vendor.cyr`.** See `writing-tests.md`.
- **File an upstream ask** at `~/Repos/cyrius/docs/development/issues/YYYY-MM-DD-<slug>.md`, from the template in that directory's `README.md`, and name the full surface needed.

## Proving a floor change

A `lib/` edit cannot be a break test: `cyrius build` re-syncs it from the pin, even with `--no-deps`, and that flag also drops the stdlib prepend. Copy the tree to scratch instead, set `cyrius = "<older>"` there (any version under `~/.cyrius/versions/`), run `cyrius lib sync --full`, and build the suite. The new test must fail on the old floor.

To show a cross-target failure was already there, `git archive HEAD` into scratch, set only the pin, and build both on the host. That separates the dep from the compiler.

The Mac cannot fetch a toolchain: see `verification-pass.md`, V-5.
