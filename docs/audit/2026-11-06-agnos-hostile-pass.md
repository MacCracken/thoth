# thoth — the AGNOS hostile pass, 2026-11-06 (0.55.1)

The 2026-11-05 audit's attacks ran on Linux only, and its "Not covered" list said so. With a real turn running on AGNOS since 0.55.0, this moves them to ring 3: thoth 0.55.1 on agnos 1.57.17 with daimon 2.5.5, under QEMU.

Method: `./scripts/agnos-run.sh --hostile`. One boot works through 198 scenarios from a run list, read by `tests/agnos/hostile.cyr`, each scenario with its own `HOME` and `PWD`. thoth talks to the hostile gateway on the host directly, over QEMU's network. Verdicts come from the exit status, the host's log of what crossed the wire, and the image read back afterwards. Every store has a positive control.

## Findings

| ID | Sev | Finding | Repair |
|---|---|---|---|
| H-1 | HIGH | **The jail was the disk.** AGNOS has no working directory, so `.` is `/`. `read_file("etc/secret.txt")` returned the file, `list_dir(".")` listed the disk root, `search` walked every file, and `create_file("etc/x")` was stopped only by a missing checkpoint directory, which the spine smoke stages. A relative `@mention`, `/read`, `/write`, `-o` and a project's own config were rooted at `/` too. | `fs_path` resolves a relative path against `$PWD`, as AGNOS's userland ABI asks. [Note 005](../architecture/005-a-relative-path-is-not-the-kernels-to-resolve.md). |
| H-2 | HIGH | **A link with a target over 8 bytes read as no link.** `is_symlink` asks `readlink#70` with an 8-byte buffer, and agnos refuses a short buffer where Linux truncates. `read_file` and `search` followed `link-out -> /etc/secret.txt`. Every link defence on AGNOS stood on this; `O_NOFOLLOW` saved the stores and the logs. | `fs_is_link` asks `lstat#102`. The kernel's half is filed. |

## Corrected

The roadmap said a gateway that never read its socket took 38 s against a 15 s deadline "because AGNOS's `sock_connect` blocks on its own clock". That was stock hoosh's `sleep_ms` loop holding the CPU, in the run where the gateway was hoosh 2.10.0. A listener that never accepts takes about 8 s, inside the 10 s connect deadline.

## Verified clean

- **Wire:** all 151 scenarios: no crash, no hang, no invalid JSON, no kernel fault. Slowest about 3 s, a 5 MB reply.
- **Silence, with a 2.5 s deadline:** accepted and silent 2.9 s, silent mid-stream 2.9 s, refused 0.4 s, blackholed 8.4 s, never accepted 7.9 s.
- **Stores:** the pin store as a link, garbage, truncated, empty, oversized and a directory; the session store as a link, garbage, a newer format and a directory; `--logs` and `[log].file` as links. Each is refused by name, its victim unchanged on the image, and a control proves the path is written when nothing is wrong.
- **Capture:** a model naming `shell` is refused. `[verify]` claims nothing. A `pre_tool` hook cannot run and says so, as ruled at 0.44.2.
- **The line REPL** runs on AGNOS on a scripted stdin, for the first time, and a project's own config is read from `$PWD`.
- **The kit itself:** with the seam removed it flags 9 scenarios, and with `is_symlink` back it flags exactly the two link scenarios.

## Filed with agnos

`readlink#70` truncating, a readiness wait on one fd, a kernel-held working directory (for a ruling) and a create mode on `open`.

## Residuals

- **Keep-alive:** with no `fd_wait_ready` on AGNOS the stall deadline cannot run, and a stalled stream with comments ran until the gateway hung up, 10.4 s against a 2.5 s deadline.
- **A `pre_tool` hook does not run.** The tool proceeds, announced. This is the ruling, and it is still a control that is absent there.

## Not covered

- A real provider, which means TLS from the guest, and hoosh or daimon as targets of the wire kit.
- Modes and owners: `getuid` is a stub and thoth's checks skip AGNOS, so there is no second user to attack with.
- FIFOs, which AGNOS does not have, and the capture attacks that need a shell.
- The TUI, which has no raw terminal there, and two sessions at once.
- Iron: all of this ran under QEMU.
