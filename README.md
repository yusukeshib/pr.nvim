# pr.nvim

Read-only GitHub pull request reviews in ordinary Neovim buffers.

The plugin checks a PR out into an isolated workspace, keeps source buffers read-only, uses Gitsigns for the unified diff, renders review threads between source lines, and uses nvim-tree as the changed-file pane. Because reviewed files are real files, LSP navigation and the rest of your normal Neovim workflow remain available.

## Status

Early prototype. GitHub.com pull requests with up to 100 review threads are supported. Right-side, non-outdated threads are rendered inline; deleted-file and outdated-thread UI is not implemented yet.

## Requirements

- Neovim 0.10+
- `gh`, authenticated
- `git`
- `gitsigns.nvim`
- `nvim-tree.lua`

## Installation

With Neovim's built-in package manager:

```lua
vim.pack.add({
  { src = "https://github.com/yusukeshib/pr.nvim" },
})
```

## Setup

```lua
require("pr").setup()
```

Add the review-aware custom filter to nvim-tree:

```lua
require("nvim-tree").setup({
  filters = {
    custom = function(path)
      local ok, review = pcall(require, "pr")
      return ok and review.filter_file(path) or false
    end,
  },
})
```

During a review the custom filter shows only changed files and their parent directories. Press nvim-tree's default `U` mapping to disable the filter and browse every sibling file.

## Commands

```vim
:PROpen owner/repo/123
:PROpen owner/repo#123
:PROpen https://github.com/owner/repo/pull/123
:PROpen 123

:PRRefresh
:PRClose
```

A bare PR number uses the repository containing the current working directory.

## Review mappings

| Mapping | Action |
| --- | --- |
| `gc` | Comment on the current line |
| `gr` | Reply to the thread on the current line |
| `gR` | Resolve or unresolve the thread |
| `]t` / `[t` | Next or previous thread in the current file |
| `R` | Refresh review threads |
| `<C-s>` | Submit from a comment editor |

## Design

Review workspaces are cached under `stdpath("state")/pr.nvim/worktrees`. A local repository uses `git worktree`; another repository is cloned into the cache. Closing a review keeps the workspace for fast reopening.
