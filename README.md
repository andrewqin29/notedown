# notedown

A note format for Neovim, built on markdown and rendered in the buffer.

Early development: expect changes.

## The format

| Write                                            | Shows                                                       |
| ------------------------------------------------ | ----------------------------------------------------------- |
| `>> note` … `<<`                                 | a callout (also `tip`, `important`, `warning`, `caution`)   |
| `>> python` … `<<`                               | highlighted code (also `c`, `cpp`, `java`, `rust`, `ocaml`) |
| `>> latex` … `<<`                                | typeset formulas, one per line                              |
| `>> mermaid` … `<<`                              | a mermaid diagram                                           |
| `>> boxed` … `<<`                                | its lines in a box                                          |
| `#` `##`                                         | larger headings, drawn as images                            |
| `###` to `######`                                | headings on a colored bar                                   |
| `-` `1.` `- [ ]` `>` `---`                       | bullets, numbers, checkboxes, quote bars, a line            |
| `*bold*` `_italic_` `==highlight==` `--struck--` | bold, italic, highlighted, struck through                   |
| `![caption](picture.png)`                        | the picture, centered, with its caption                     |
| `[^label]`                                       | a numbered footnote (below)                                 |
| `--` `"quotes"` `1/2` `(c) 2026`                 | — “quotes” ½ ©                                              |

Paragraphs are justified, a breadcrumb at the top of the window shows the
headings above the cursor, and the line under the cursor shows as typed. In
insert mode the whole block you're editing (paragraph, list, `>>` block)
shows as typed, and the rest of the note stays rendered. Only
markdown files are rendered: not other buffers holding markdown, such as LSP
hover popups.

Footnotes are numbered by first use, with any label: `[^bits]` shows as ¹.
Their definitions, `[^bits]: text`, are kept at the end of the note: a stub
is added for each new label, they're put in the order they're used, and a
definition whose label is no longer used is deleted with its text (one `u`
undoes the edit and the change to the footnotes together).

Markdown syntax the format replaces does nothing: `> [!NOTE]` callouts,
```` ``` ```` code blocks, `$$` math, setext headings, `**bold**`,
`__bold__` and `~~struck~~`. Tables show as typed.

## Commands

| Command          | Does                                  |
| ---------------- | ------------------------------------- |
| `:help` or `F1`  | what to write and the commands, popup |
| `:toc` or `gO`   | table of contents popup               |
| `:read`          | toggle reading mode                   |
| `:raw`           | toggle reading mode, nothing rendered |
| `:Notedown`      | toggle rendering                      |

In a markdown file `:help` on its own is notedown's; `:help topic` is still
nvim's help.

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "andrewqin29/notedown",
  lazy = false,
  dependencies = {
    "nvim-treesitter/nvim-treesitter",
    "nvim-tree/nvim-web-devicons",
    { "folke/snacks.nvim", opts = { image = { enabled = true } } },
  },
}
```

It loads at startup because it changes how nvim-treesitter highlights
markdown before any file opens. There is nothing to configure; colors are
highlight groups (`lua/notedown/highlights.lua`) that a colorscheme can set.

## Requirements

- Neovim 0.11+, nvim-treesitter with the `markdown` and `markdown_inline`
  parsers, and the parsers of any `>> language` you use.
- Images (formulas, diagrams, headings, pictures): snacks.nvim with
  `image = { enabled = true }`, in a terminal with kitty's graphics protocol
  (Ghostty, kitty), and ImageMagick.
- Formulas: `pdflatex`.
- Diagrams: [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) (`mmdc`)
  and Google Chrome.

## How it's built

`lua/notedown/init.lua` lists the parts. `render.lua` draws each note: every
part returns marks (extmarks) for the whole buffer after a change, and the
marks on the cursor's line give way so it shows as typed.

## Tests

```sh
nvim --headless --clean -u tests/run.lua               # all
nvim --headless --clean -u tests/run.lua -- toc        # names containing "toc"
nvim --headless --clean -u tests/run.lua -- --update   # rewrite the snapshots
```

They need only Neovim. Rendering tests compare the screen and marks with
`tests/snapshots/`, drawn from `tests/fixtures/`; review a snapshot's diff
before committing it. Images can't be checked headless: open
`tests/manual/images.md` in Ghostty or kitty and go through it.

## License

MIT. notedown began as a fork of
[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
by MeanderingProgrammer.
