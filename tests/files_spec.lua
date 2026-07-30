local files = require("pr.files")

local entries = files.entries({
  changed_files = {
    { status = "M", path = "src/a.lua" },
    { status = "A", path = "src/b.lua" },
    { status = "M", path = "src/c.lua" },
  },
  threads = {
    { path = "src/a.lua", isResolved = false },
    { path = "src/a.lua", isResolved = true },
    { path = "src/b.lua", isResolved = true },
    { path = vim.NIL, isResolved = false },
  },
})

assert(#entries == 3)
assert(entries[1].thread_count == 2 and entries[1].unresolved_count == 1)
assert(files.comment_badge(entries[1]) == "●1")
assert(entries[2].thread_count == 1 and entries[2].unresolved_count == 0)
assert(files.comment_badge(entries[2]) == "✓1")
assert(files.comment_badge(entries[3]) == "")

local refreshed = files.entries({
  changed_files = { { status = "M", path = "src/a.lua" } },
  threads = {},
})
assert(#refreshed == 1 and files.comment_badge(refreshed[1]) == "")

print("files_spec: ok")
vim.cmd.qa()
