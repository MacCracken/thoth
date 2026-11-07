# 005 — A relative path is not the kernel's to resolve

> Non-obvious invariant — *what's true about the code*. Since 0.55.1: every path thoth treats as project-relative goes through `fs_path`
> (`src/util.cyr`) before it reaches the filesystem, and every "is this a link?" goes through `fs_is_link`.

AGNOS has no working directory: "CWD is userland-owned", and a relative name is rooted at `/`. A jail that says "relative, with no `..`" only means "the project" where the kernel supplies the project. On AGNOS it meant the disk, and thoth shipped that way until the first hostile pass there: `read_file("etc/x")` read `/etc/x`.

So a tool works in two steps:

1. **Check the spelling.** `_project_read_ok`, `_project_jail_ok`, `_project_sensitive` and `_project_git_path` read the path as the model wrote it. They are pure, and they must stay relative: the checks are about what was asked for.
2. **Resolve, then touch the disk.** `fs_path(path)` gives the path the filesystem gets. Use it on every `file_*`, `is_dir`, `xstat`, `xunlink` and listing call. Keep the relative spelling for messages, the checkpoint table and the edit log.

`_project_no_symlink` resolves for itself, and skips `$PWD`'s own spelling: that part is the operator's.

On a target with a kernel cwd `fs_path` is the identity, so a call site that forgets it passes every suite on Linux and is a jail escape on AGNOS. **`test_fs_no_cwd` flips `_fs_no_cwd` so the logic runs on every lane, and `./scripts/agnos-run.sh --hostile` is the proof.** A new tool that reads a path belongs in both.

`fs_path` never falls back to the relative form, on an oversized path or a failed allocation. On AGNOS that fallback is the same name at the disk root.
