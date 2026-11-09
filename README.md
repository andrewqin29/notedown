# notedown

A note format for Neovim, built on markdown and rendered in the buffer.

notedown started as a fork of
[render-markdown.nvim](https://github.com/MeanderingProgrammer/render-markdown.nvim)
and keeps its markdown rendering (headings, lists, checkboxes, tables, quotes,
links), adding a note format of its own on top and removing the markdown
syntax that format replaces.

Early development: expect changes.

## The format

| Write                               | Shows                                                       |
| ----------------------------------- | ----------------------------------------------------------- |
| `>> note` … `<<`                    | a callout (also `tip`, `important`, `warning`, `caution`)   |
| `>> python` … `<<`                  | highlighted code (also `c`, `cpp`, `java`, `rust`, `ocaml`) |
| `>> latex` … `<<`                   | typeset formulas, one per line                              |
| `>> mermaid` … `<<`                 | a mermaid diagram                                           |
| `>> boxed` … `<<`                   | its lines in a box                                          |
| `*bold*` `_italic_` `==highlight==` | bold, italic, highlighted                                   |
| `#` `##`                            | larger headings, drawn as images                            |
| `![caption](picture.png)`           | the picture, centered, with its caption                     |
| `--` `"quotes"` `1/2` `(c) 2026`    | — “quotes” ½ ©                                              |

Paragraphs are justified, a breadcrumb at the top of the window shows the
headings above the cursor, and the line under the cursor shows as typed.

Markdown syntax the format replaces does nothing: `> [!NOTE]` callouts,
```` ``` ```` code blocks, `$$` math, setext headings, `**bold**` and `__bold__`.

## Commands

| Command          | Does                              |
| ---------------- | --------------------------------- |
| `:toc` or `gO`   | table of contents popup           |
| `:read`          | toggle reading mode               |
| `:Notedown`      | enable, disable or toggle rendering |

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    'andrewqin29/notedown',
    lazy = false,
    dependencies = {
        'nvim-treesitter/nvim-treesitter',
        'nvim-tree/nvim-web-devicons',
        { 'folke/snacks.nvim', opts = { image = { enabled = true } } },
    },
    opts = {},
}
```

It loads at startup because it sets how nvim-treesitter highlights markdown
before any file opens.

## Requirements

- Neovim 0.11+, nvim-treesitter with the `markdown` and `markdown_inline`
  parsers, and the parsers of any `>> language` you use.
- Images (formulas, diagrams, headings, pictures): snacks.nvim with
  `image = { enabled = true }`, in a terminal with kitty's graphics protocol
  (Ghostty, kitty), and ImageMagick.
- Formulas: `pdflatex`.
- Diagrams: [mermaid-cli](https://github.com/mermaid-js/mermaid-cli) (`mmdc`)
  and Google Chrome.

## Configuration

`opts` takes render-markdown.nvim's settings (see `lua/notedown/settings.lua`).
`notes = false` turns the note format off, leaving plain markdown rendering.

## Development

- The format is in `lua/notedown/notes/`; the markdown renderer is the rest of
  `lua/notedown/`.
- Tests: `just test`. They need plenary.nvim, nvim-treesitter and mini.icons in
  Neovim's data directory, and test the markdown renderer (`notes = false`).
- `upstream` is render-markdown.nvim. To bring in its changes:
  `git fetch upstream && git merge upstream/main`.

## License

MIT. Based on render-markdown.nvim by MeanderingProgrammer.
