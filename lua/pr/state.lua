local M = {
  session = nil,
}

function M.get()
  return M.session
end

function M.set(session)
  M.session = session
end

function M.clear()
  M.session = nil
end

function M.active()
  return M.session ~= nil
end

return M
