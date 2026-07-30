local folds = require("pr.folds")

local function same(expected, actual)
  assert(vim.deep_equal(expected, actual), ("expected %s, got %s"):format(vim.inspect(expected), vim.inspect(actual)))
end

same({}, folds.build(30, {}, 3, 2))
same(
  { { 1, 6 }, { 15, 30 } },
  folds.build(30, {
    { added = { start = 10, count = 2 } },
  }, 3, 2)
)
same(
  { { 1, 6 }, { 22, 30 } },
  folds.build(30, {
    { added = { start = 10, count = 2 } },
    { added = { start = 18, count = 1 } },
  }, 3, 2)
)
same(
  { { 5, 20 } },
  folds.build(20, {
    { added = { start = 1, count = 0 } },
  }, 3, 2)
)
same(
  { { 9, 10 } },
  folds.build(10, {
    { added = { start = 5, count = 1 } },
  }, 3, 2)
)

print("folds_spec: ok")
vim.cmd.qa()
