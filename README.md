# pr.nvim

Read-only GitHub pull request reviews in ordinary Neovim buffers.

The plugin checks a PR out into an isolated workspace, keeps source buffers read-only, uses Gitsigns for the unified diff, folds unchanged regions with three lines of context, and renders review threads between source lines. nvim-tree remains an unfiltered project tree for normal navigation, while `:PRFiles` provides a focused changed-file picker. Because reviewed files are real files, LSP navigation and the rest of your normal Neovim workflow remain available.

## Status

Early prototype. GitHub.com pull requests with up to 100 review threads are supported. Right-side, non-outdated threads are rendered inline; deleted-file and outdated-thread UI is not implemented yet.

## Requirements

- Neovim 0.10+
- `gh`, authenticated
- `git`
- `gitsigns.nvim`
- `nvim-tree.lua`
- `telescope.nvim` (optional; falls back to `vim.ui.select`)

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

nvim-tree is rooted at the isolated PR workspace without filtering, so unchanged sibling files remain available.

## Commands

```vim
:PROpen owner/repo/123
:PROpen owner/repo#123
:PROpen https://github.com/owner/repo/pull/123
:PROpen 123

:PRFiles
:PRRefresh
:PRClose
```

A bare PR number uses the repository containing the current working directory.

## Review mappings

| Mapping | Action |
| --- | --- |
| `<leader>pf` | List changed files and review-thread counts |
| `gc` | Comment on the current line |
| `gr` | Reply to the thread on the current line |
| `gR` | Resolve or unresolve the thread |
| `]t` / `[t` | Next or previous thread in the current file |
| `R` | Refresh review threads |
| `<C-s>` | Submit from a comment editor |
| `za` | Toggle the unchanged region under the cursor |
| `zR` / `zM` | Open or close all unchanged regions |

`:PRFiles` opens a compact bottom list without a preview pane. Moving the selection updates the source buffer immediately. `●N` means the file has N unresolved review threads and `✓N` means all N threads are resolved.

Unchanged regions are folded by default while preserving three context lines around every Gitsigns hunk. Configure this with `folds.context`, or disable it with `folds.enabled = false`.

## Design

Review workspaces are cached under `stdpath("state")/pr.nvim/worktrees`. A local repository uses `git worktree`; another repository is cloned into the cache. Closing a review keeps the workspace for fast reopening.
