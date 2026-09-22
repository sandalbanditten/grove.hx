# Limit the Entry palette to safe foreground parts

An `LS_COLORS` rule can carry a background, a reversing or hiding attribute, and
an underline style. `vivid` uses backgrounds freely: its gruvbox-dark `fi` rule
is `0;38;2;235;219;178;48;2;40;40;40`, so an unmatched file would paint its own
background behind every label.

ADR 0010 resolves one background per row and then draws only foreground changes
over it, which is what keeps the Cursor, Pinned ancestor, and Active file rows
legible. A per-label background or a reversing attribute would replace that
background for part of the row. Grove therefore reads only the foreground and
the bold, dim, and italic attributes from a rule, and drops the rest. Steel
exposes no `UnderlineStyle` constructor, so underline is unreachable regardless.
No `vivid` theme uses the reversing, hiding, blinking, or crossed-out attributes
on a key a File tree can reach.

Steel's `fs-metadata` exposes no permission bits, so Grove cannot tell that a
file is executable and the `ex` rule never applies. An executable file takes its
filename pattern, or `fi`.

Revisit when Steel exposes safe native Style patching along with file mode
metadata, and Grove can paint a label background without disturbing the row
background that ADR 0010 resolves.
