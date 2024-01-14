# cmp-pypi

This is an additional source for [nvim-cmp](https://github.com/hrsh7th/nvim-cmp), it allows you to
autocomplete [pypi](https://pypi.org/) packages and its versions.
The source is only active if you're in a `pyproject.toml` file.

TODO: Demo

## Installation

TODO: You have to get treesitter plugin and nvim-cmp

```
{
  "vrslev/cmp-pypi",
  dependencies = { 'nvim-lua/plenary.nvim' },
  ft = "toml",
}
```

Run the `setup` function and add the source
```lua
cmp.setup({
  ...,
  sources = {
    { name = 'pypi', keyword_length = 4 },
    ...
  }
})
```

## Limitations
TODO
The versions are not correctly sorted (depends on `nvim-cmp`'s sorting algorithm).
