# cmp-pypi

Complete versions of dependencies in `pyproject.toml`. Works with Neovim and [nvim-cmp](https://github.com/hrsh7th/nvim-cmp).

## Installation

Requires:

- Neovim >=0.9.0
- curl on your system
- TOML tree-sitter parser (via [nvim-treesitter/nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter))

Install with [Lazy](https://github.com/folke/lazy.nvim):

```lua
{
  "vrslev/cmp-pypi",
  dependencies = { "nvim-lua/plenary.nvim" },
  ft = "toml",
}
```

And add the source:

```lua
cmp.setup({
  ...,
  sources = {
    { name = "pypi", keyword_length = 4 },
    ...
  }
})
```
