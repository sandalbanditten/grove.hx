# Theme Grove

Grove follows the active Helix theme by default. Use `grove-theme` to change
only the parts that need different colors.

## Quick start

Pass Helix theme keys to individual Theme roles:

```scheme
(grove-start!
  #:theme
  (grove-theme
    #:cursor "ui.cursor.primary"
    #:guides-foreground "ui.virtual.whitespace"
    #:git-modified-foreground "warning"))
```

Every role is optional. Omit a role, or set it to `#f`, to use its default.

## Color sources

A string such as `"warning"` names a key from the active Helix theme. The
override changes when you switch themes. Use this form for most overrides.

Pass a Style when you need fixed colors:

```scheme
(require "helix/components.scm")
(require "helix/themes.scm")

(grove-start!
  #:theme
  (grove-theme
    #:cursor
    (style-bg
      (style)
      (string->color "#303446"))

    #:git-modified-foreground
    (style-fg
      (style)
      (string->color "#e5c07b"))))
```

Grove reads only the properties listed in the role table. It ignores modifiers,
underline, and every unlisted property. For example, a background in a Git
foreground role has no effect.

Grove keeps every supplied color. If two roles use the same color, they can look
the same. Choose different theme keys or fixed colors when you need a stronger
distinction.

## Roles

| Role | What it colors | Style properties used | Default | When a property is missing |
| --- | --- | --- | --- | --- |
| `pane-background` | Pane | background | `ui.background` | terminal background |
| `visible-row` | ordinary File tree rows | foreground and background | `ui.text` | terminal foreground; Pane background |
| `pinned-ancestor-row` | Pinned ancestor rows | foreground and background | `ui.virtual.ruler` | matching Visible color |
| `cursor` | Cursor row | foreground and background | `ui.text.focus` | matching Visible color |
| `active-file-background` | Active file row | background | `ui.bufferline.active`, then `ui.statusline.active` | Visible row background |
| `guides-foreground` | Ancestor traces and Leaf marks | foreground | `ui.virtual.indent-guide`, then `ui.virtual.whitespace` | terminal gray |
| `active-file-mark-foreground` | Active file marks | foreground | `info` | matching row foreground |
| `rail` | Rail thumb and track | foreground for thumb, background for track | `ui.menu.scroll` | matching terminal default |
| `filesystem-error-foreground` | Unreadable directory and Broken link icons and labels | foreground | `error` | terminal bright red |
| `git-conflict-foreground` | labels with a conflicting Git status | foreground | `error` | terminal magenta |
| `git-deleted-foreground` | labels with a deleted Git status | foreground | `diff.minus` | terminal red |
| `git-modified-foreground` | labels with a modified Git status | foreground | `diff.delta` | terminal yellow |
| `git-created-foreground` | labels with a created Git status | foreground | `diff.plus` | terminal green |
| `unsaved-mark-foreground` | Unsaved marks | foreground | `info` | terminal cyan |

Helix theme-key lookup can fall back to a broader key. For example,
`ui.menu.scroll` can receive colors from `ui.menu`. Grove uses the colors that
Helix returns.

When `active-file-background` is omitted, Grove takes the first available
background from its two default keys. This means `ui.bufferline.active` can use
`ui.bufferline`, and `ui.statusline.active` can use `ui.statusline`. If none of
them supplies a background, the Active file keeps the Visible row background.
A configured override replaces this default chain.

## Entry palette

Theme roles give every label the same foreground. An Entry palette colors each
label by what the entry is instead, from the `LS_COLORS` format that `vivid`,
`eza`, and GNU `ls` share.

Pass the generated spec directly:

```scheme
(grove-start! #:ls-colors "di=0;38;2;69;133;136:*.rs=0;38;2;152;151;26")
```

Or read whatever the shell exported, which is the usual way to follow a `vivid`
theme:

```sh
# ~/.config/fish/config.fish, or the equivalent for your shell
set -gx LS_COLORS (vivid generate gruvbox-dark)
```

```scheme
(grove-start! #:ls-colors 'environment)
```

`'environment` reads `LS_COLORS` once, when Grove starts. Changing the variable
afterwards needs a new Helix process. When the variable is unset or empty,
Grove keeps its Theme role colors instead of failing to start.

### Rules Grove reads

| Entry | Rule |
| --- | --- |
| Directory, Unreadable directory, Workspace root | `di` |
| File link, Unfollowed directory link | `ln` |
| Broken link | `or` |
| File matching a filename pattern | that pattern |
| Every other file | `fi` |

Only files consult filename patterns, so a directory named `docs.md` stays a
directory. When several patterns match, the longest wins, which is what lets
`*README.md` beat `*.md`. Matching is case sensitive, as it is in `eza`.

Grove reads the foreground and the bold, dim, and italic attributes from a
rule. It ignores the background, the reversing and hiding attributes, and
underline. See
[ADR 0014](docs/adr/0014-limit-the-entry-palette-to-safe-foreground-parts.md)
for why.

Grove cannot read a file's permission bits through Steel, so the executable
rule `ex` never applies. An executable file takes its filename pattern, or
`fi`.

## Overlap

Row roles apply in this order:

1. Cursor
2. Pinned ancestor row
3. Active file
4. Visible row

Label foregrounds apply in this order:

1. Filesystem error
2. Git status
3. Entry palette
4. Row foreground

Entry palette modifiers say what kind of entry a row holds, so they stay
applied even when a status above them replaces the foreground. Guides and
Unsaved marks use their own foregrounds. Ignored Git status dims only the exact
label.

Cursor marks use their row colors. Active file marks use their Theme role
foreground and the row background. Git status does not recolor either mark.

File icons keep their selected palette colors on Visible, Pinned, and Cursor
rows. Neither Git status nor an Entry palette recolors them. A filesystem error
can replace the affected error icon foreground.

## Invalid values

`#:theme` must receive a `grove-theme`. Each role must contain `#f`, a non-empty
theme key, or a Style. `#:ls-colors` must contain `#f`, `'environment`, or a
string. Grove reports invalid values during startup.

An unreadable rule inside an otherwise valid spec is skipped rather than
rejected, because `LS_COLORS` in the wild collects entries from many tools.
