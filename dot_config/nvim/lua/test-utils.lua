-- Convention-based test file mapping
-- No per-repo config needed - uses standard conventions per language

local M = {}

local function file_exists(path)
  return vim.fn.filereadable(path) == 1
end

local function try_paths(candidates)
  for _, path in ipairs(candidates) do
    if file_exists(path) then return path end
  end
  return nil
end

-- Check if current file is already a test file
local function is_test_file(file)
  return file:match("_test%.go$")
      or file:match("_spec%.rb$")
      or file:match("_test%.rb$")
      or file:match("test_.*%.py$")
      or file:match("_test%.py$")
      or file:match("%.test%.[jt]sx?$")
      or file:match("%.spec%.[jt]sx?$")
      or file:match("__tests__/")
end

-- Find test file for implementation file (returns nil if already in test file)
local function find_test_file(file)
  if is_test_file(file) then return nil end

  local dir = vim.fn.fnamemodify(file, ":h")
  local name = vim.fn.fnamemodify(file, ":t:r")
  local ext = vim.fn.fnamemodify(file, ":e")

  -- Go: foo.go -> foo_test.go (same directory)
  if ext == "go" then
    return try_paths({ dir .. "/" .. name .. "_test.go" })
  end

  -- Rust: inline tests (same file), so return nil
  if ext == "rs" then
    return nil
  end

  -- Ruby/Rails: app/foo.rb -> spec/foo_spec.rb
  if ext == "rb" then
    local spec_path = file:gsub("/app/", "/spec/"):gsub("%.rb$", "_spec.rb")
    local test_path = file:gsub("/app/", "/test/"):gsub("%.rb$", "_test.rb")
    return try_paths({ spec_path, test_path })
  end

  -- Python: pkg/foo.py -> tests/test_foo.py or test_foo.py
  if ext == "py" then
    return try_paths({
      dir .. "/test_" .. name .. ".py",
      dir:gsub("/[^/]+$", "") .. "/tests/test_" .. name .. ".py",
      "tests/test_" .. name .. ".py",
    })
  end

  -- JS/TS: src/foo.ts -> src/foo.test.ts, src/foo.spec.ts, __tests__/foo.test.ts
  if ext:match("^[jt]sx?$") then
    return try_paths({
      dir .. "/" .. name .. ".test." .. ext,
      dir .. "/" .. name .. ".spec." .. ext,
      dir .. "/__tests__/" .. name .. ".test." .. ext,
      dir .. "/__tests__/" .. name .. ".spec." .. ext,
    })
  end

  return nil
end

-- Find implementation file for test file (returns nil if already in impl file)
local function find_impl_file(file)
  if not is_test_file(file) then return nil end

  local dir = vim.fn.fnamemodify(file, ":h")
  local name = vim.fn.fnamemodify(file, ":t:r")
  local ext = vim.fn.fnamemodify(file, ":e")

  -- Go: foo_test.go -> foo.go
  if ext == "go" then
    local impl_name = name:gsub("_test$", "")
    return try_paths({ dir .. "/" .. impl_name .. ".go" })
  end

  -- Ruby/Rails: spec/foo_spec.rb or test/foo_test.rb -> app/foo.rb
  if ext == "rb" then
    local impl_name = name:gsub("_spec$", ""):gsub("_test$", "")
    local from_spec = file:gsub("/spec/", "/app/"):gsub("/" .. name .. "%.rb$", "/" .. impl_name .. ".rb")
    local from_test = file:gsub("/test/", "/app/"):gsub("/" .. name .. "%.rb$", "/" .. impl_name .. ".rb")
    return try_paths({ from_spec, from_test })
  end

  -- Python: tests/test_foo.py -> pkg/foo.py
  if ext == "py" then
    local impl_name = name:gsub("^test_", ""):gsub("_test$", "")
    return try_paths({
      dir .. "/" .. impl_name .. ".py",
      dir:gsub("/tests$", "") .. "/" .. impl_name .. ".py",
      dir:gsub("/tests/", "/") .. "/" .. impl_name .. ".py",
    })
  end

  -- JS/TS: foo.test.ts -> foo.ts
  if ext:match("^[jt]sx?$") then
    local impl_name = name:gsub("%.test$", ""):gsub("%.spec$", "")
    local impl_dir = dir:gsub("/__tests__$", "")
    return try_paths({
      impl_dir .. "/" .. impl_name .. "." .. ext,
    })
  end

  return nil
end

-- Toggle between test and implementation file
function M.alternate()
  local file = vim.fn.expand("%:p")
  local target = find_test_file(file) or find_impl_file(file)
  if target then
    vim.cmd("edit " .. target)
  else
    vim.notify("No alternate file found", vim.log.levels.WARN)
  end
end

local function run_test(cmd)
  local file = vim.fn.expand("%:p")

  -- Already in a test file? Just run it.
  if is_test_file(file) then
    vim.cmd(cmd)
    return
  end

  -- Try to find corresponding test file
  local test_file = find_test_file(file)
  if test_file then
    local orig_buf = vim.api.nvim_get_current_buf()
    local orig_win = vim.api.nvim_get_current_win()
    vim.cmd("edit " .. test_file)
    vim.cmd(cmd)
    vim.api.nvim_win_set_buf(orig_win, orig_buf)
  else
    vim.notify("No test file found for " .. vim.fn.fnamemodify(file, ":t"), vim.log.levels.WARN)
  end
end

function M.run_nearest()
  run_test("TestNearest")
end

function M.run_file()
  run_test("TestFile")
end

return M
