# 006 — The AGNOS console is not a terminal, and a channel is not a tty

> Non-obvious invariant — *what's true about the code*. Since 0.55.2: every byte bound for fd 1 goes through `fd1_write`, and the
> TUI reaches AGNOS's keys, console and channels through `src/term.cyr` alone.

thoth's TUI assumes a VT: raw keys on fd 0, escapes on fd 1, `SIGWINCH` when the window changes. AGNOS has none of that as such, and
the TUI runs there anyway, because `src/term.cyr` turns what AGNOS does have into what the TUI expects. Nothing above that module
knows the difference. These are the rules that keep it so.

## Every byte for fd 1 goes through `fd1_write`

`emit`, `emit_n`, `emit_raw`, `emit_raw_n`, `oprintln`, the frame buffer, the spinner's worker and `/copy` all end there. Darshana's
`tty_*` writers and the stdlib's `println` do not, so thoth uses neither for anything that reaches the screen: `frame_move`,
`frame_clear`, `frame_clear_eol`, `term_alt_enter`, `term_alt_leave` and `term_cursor_show` are the same bytes by a route that passes
the seam. On Linux, macOS and Windows the seam is one compare. A new direct `syscall(SYS_WRITE, 1, ...)` works on those three and
breaks AGNOS twice over: it skips the console's filter, and one write takes only 64 bytes of a channel.

`ofmt_int` still uses the stdlib. Digits need no filter and fit a record, and it is the one exception.

## Two routes, and how thoth picks

`term_raw` decides, from what the kernel says about the fd:

| fd 0 and fd 1 | Keys | Output |
|---|---|---|
| The console (`FDK_CONSOLE`) | `kbscan`#42, through the decoder | The filter |
| A sized terminal end (`FDK_CHAN`, and `CH_WINSZ_GET` above 0) | `read`#5, as the emulator sends them | The emulator's VT, paced |
| Anything else, an unsized end included | None: `term_raw` answers -1 and the session is the line REPL | As written |

The size is what makes a channel a terminal: it is the ring-3 answer to "is this fd a terminal", as a failing `TIOCGWINSZ` is on
Linux. It also keeps thoth out of a window it cannot drive. puka 0.6.25 sets no size and runs its own line discipline, so a program in
a puka window gets whole cooked lines, and Esc, the arrows and every Ctrl key never arrive. The line REPL is the right surface there.

**An emulator that sets a size is taken to deliver keys.** A cooked emulator that started sizing its child would get a TUI with no
Esc and no Ctrl keys, and thoth has no way to tell. When puka adopts `CH_WINSZ_SET`, it needs a raw path for its child at the same
time. The other way round holds too: `--tier=simple` and `NO_COLOR` read cooked lines, so under a raw emulator nothing would echo or
end a line. No such emulator exists yet outside the test host, so that case is unproven.

No TERM is needed on either route. kybernet seeds none, so on AGNOS `term_kernel_terminal` stands in for it, and a TERM that is set
is still honoured, `dumb` included.

## The decoder is what a terminal would have sent

`term_kbd_feed` turns Set-1 scancodes into xterm's bytes, so `tui_read_key` stays one parser and the modals never learn where a key
came from. The kernel keeps no key state, so Shift, Ctrl, Alt, Caps and the `0xE0` prefix live here, and they outlast a drain: a batch
can end anywhere. The layout is US, as the kernel's own cooked line is. `kbscan` drains the ring whoever else wants it, so a backgrounded
`thoth &` would take the shell's keys, which is the convention `kbscan` documents.

Prompts read the same keys through `term_line_read`, because with the keys in hand nothing below thoth cooks a line. That holds on
a channel too, where the bytes are the emulator's and Enter is CR. `term_flush_input` drains them first, so S-3 holds there as well.

## The filter models the console, not a terminal

`_tc_*` turns what the TUI writes into what `fb_console` can draw. The agnos filing
`2026-11-06-the-console-is-short-of-a-terminal` lists each gap, and each comes out of the filter when the kernel takes it.

- **One ASCII cell per glyph.** The TUI measures a glyph as one column, so a row keeps its width. Bytes the console would drop must not
  be dropped here: the rest of the row would slide left.
- **A frame never wraps or scrolls.** Inside the alternate screen a glyph past the right edge is dropped, and so is an LF on the last row.
- **Outside a frame it stays out of the way.** EL and relative moves are dropped there, and the tracked cursor is only a guess, because
  `ofmt_int` writes past it and the kernel prints to the same screen. Text wraps and scrolls as the console does.
- **The grid holds one byte a cell, for two readers.** EL paints only up to the row's last inked cell on the default background, because a
  repaint is every row. The caret needs the glyph under it. Colour is not kept, so a caret's old cell comes back in the default colour.
- **The caret is a private mode, `?7777h`.** `tui_park_cursor` is the frame's last word, so the marker travels in the byte stream and lands
  in order whatever the frame buffer does. `term_caret` sends it only when the filter is on, so no terminal ever sees it.
- **Eight parameters.** The kernel keeps eight of a CSI, so a fg and bg pair must be two sequences.

## Threads run inline, so nothing may wait on a worker

`THREADS_CONCURRENT` is 0 on AGNOS: `thread_create` runs the body before it returns. Two paths broke on that, and both now check it.
`_net_start` declines, so a surface's network call is the plain blocking call, and `spin_anim_arm` declines, because its worker loops
until told to stop. So on AGNOS a wait does not pump the surface: the spinner moves when a frame arrives, and Esc is read at the next
frame. Any new worker that loops or parks needs the same check.

The stray `d` this put on the console is worth knowing: `sys_pipe` writes two u64s on AGNOS and two ints everywhere else, so
`_net_pipe` read a write end of 0 and poked `NET_POKE_DONE`, byte 100, into stdin. `_net_pipe` reads both layouts now, but it stays
unreachable on AGNOS while threads are serial.

## Paint at the price the console charges

Each console byte costs a glyph and a COM1 write, so a full frame takes about 0.3 s at 128x64 under QEMU. `feed_stream_tick` holds a
stream's paints to a quarter of its time there. Keystrokes repaint the composer alone, about 700 bytes.

A channel has no back-pressure at all. A full inbox drops its oldest record and nobody is told, so `fd1_write` keeps to 2 KB per 17 ms,
on every channel write and not only the TUI's. That holds only while the emulator keeps up: a reader that stalls for 34 ms loses bytes
anyway. Text markers do not show the loss, because a session that lost half its bytes still mostly matched them, so
`tests/agnos/tuihost.cyr` drains at 60 Hz as puka does and checks every row of a repainted frame. It also holds its own results until
the child exits: a console line that scrolls the framebuffer cost it 200 ms, and that cost a frame its head.

## Proved where

The decoder and the filter are pure and compiled on every target, so `tests/cases/tui.cyr` runs them on a host. Everything that needs
the kernel is `scripts/agnos-run.sh --tui`: keys through QEMU's `sendkey` to the real agnsh, the console read back from the serial log
and from screendumps, a real puka window, then a ring-3 emulator on a channel.
