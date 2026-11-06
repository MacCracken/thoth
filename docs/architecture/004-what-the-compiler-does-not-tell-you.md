# 004 — What the compiler does not tell you

> Non-obvious invariant — *how the world is*, not *what we chose*. These are properties of Cyrius and of a project
> that vendors many bundles into one namespace. The array sizes were measured on cyrius 6.7.18. `toolchain-refresh.md`
> is the procedure that keeps these from biting at a pin bump.

## `var b[N]` means two different sizes

| Where | `var b[N]` reserves | Measured |
|---|---|---|
| Module scope | N i64 **slots**, 8N bytes | `var ga[16]` spans 128 bytes, `var gc[1024]` spans 8192 |
| Inside a function | N **bytes**, rounded up | `var la[16]` spans 16, `var ld[100]` spans 112, `var a[1]` spans 8 |

Size a module-global buffer in slots and say so in its comment (`# 32 i64 slots (module-global: 256 bytes)`). Size a local in bytes.

- Assuming 8N for a local is a stack overflow.
- A global that looks too small for its reader often isn't. `gwl_wl_rbuf[1024]` holding 8192 bytes is correct.
- An undersized local can be harmless because of the rounding, but widening it still states the intent.

## The last definition wins

Every source file and vendored bundle shares one namespace. Nothing warns reliably:

| Duplicate | What the compiler says |
|---|---|
| `fn` | A warning, and the last one silently replaces the other everywhere. `path_is_regular` in `src/util.cyr` replaced sit's own |
| `fn` at a different arity | Can stop the build (`_reg_ieq` in bote-core and vyakarana) |
| `var` or enum member, same value | **Nothing** (`DER_TAG_INTEGER` in libro and `lib/sigil.cyr`) |
| `var` or enum member, different value | A `conflicting value` warning, only on the target where they differ |

Two failures show the cost:

- darshana defined `var SYS_IOCTL = 16;`, which won on arm64, where the right number is 29.
- sandhi's server and client enums shared `SANDHI_CONN_OFF_*` names at different offsets. The client wrote its fd at the wrong offset, then `tls_ctx = 0` over it, so every request went to fd 0.

So a vendored bundle never defines a `SYS_*` constant, a helper checks for the name before taking it, and the sync scripts rename what collides. `tests/cases/vendor.cyr` pins those renames.

## A raw number is a portability claim

This covers syscall numbers and flag values alike.

- **arm64 Linux has no pre-`*at` syscalls.** `SYS_RENAME` and `SYS_ACCESS` do not exist there, and the check is static: an unreachable call still refuses to compile. Reach for `sys_rename` and `sys_access`. `SYS_IOCTL` exists at a different number, so it comes from the per-arch enum.
- **AGNOS differs for real.** Its `rename` takes four arguments, and it has no Linux-number translation at all: #41 is `sleep_ms` and #7 is `open`.
- **macOS renumbers flags as well.** `sys_open(path, 193, 384)` never created its file on Darwin, so `shell`, `[hooks]` and `[verify]` all failed there, and `[hooks]` failed open. Write `O_WRONLY | O_CREAT | O_EXCL`.
- **A target guard written as prose does not expire loudly.** `DECLARED x86_64-ONLY` in a comment stayed true-looking after the lane opened. Only a build or a test fails when the assumption ends.

### How ESYSXLAT decides

For ELF aarch64, a raw x86_64 number is renumbered only if **both** `lib/syscalls_x86_64_linux.cyr` and `lib/syscalls_aarch64_linux.cyr` name that syscall, plus hand rows such as `poll` → `ppoll` and the private-alias band from 1000. Anything else passes through silently.

That is how the Wayland window had no buffer on aarch64 for about 20 releases with an `OK` lane: `memfd_create` 319 was an unknown syscall, `ftruncate` 77 ran `tee`, and `sendmsg` 46 ran `ftruncate`. A native number is safe only while it stays unnamed, and it stops being safe when upstream adds a row.

To see what actually runs, no ARM hardware needed:

```bash
cyrius build --aarch64 probe.cyr p && qemu-aarch64 -strace ./p
```

## A reserved word can surface as "undefined"

`mod`, `match`, `trait`, `dyn`, `const`, `do`, `true` and `false` are keywords. A parameter named `mod` gives `expected identifier, got reserved keyword`, and the failed parse then reports the callers below it as `undefined`, so the error shown is not the real one. When a block of functions suddenly goes undefined, look for a keyword used as a name first. The tree uses `modk` and `matched` for this reason.
