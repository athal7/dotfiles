local opt = vim.opt

-- Line numbers
opt.number = true
opt.relativenumber = true

-- Tabs & indentation
opt.tabstop = 2
opt.shiftwidth = 2
opt.expandtab = true
opt.autoindent = true
opt.smartindent = true

-- Line wrapping
opt.wrap = false

-- Search
opt.ignorecase = true
opt.smartcase = true
opt.hlsearch = true
opt.incsearch = true

-- Appearance
-- Only enable termguicolors if terminal supports it
if vim.fn.has("termguicolors") == 1 and vim.env.COLORTERM == "truecolor" then
  opt.termguicolors = true
end
opt.background = "dark"
opt.signcolumn = "yes"
opt.cursorline = true
opt.scrolloff = 8
opt.sidescrolloff = 8

-- Behavior
opt.hidden = true
opt.mouse = "a"
opt.clipboard = "unnamedplus"
opt.splitbelow = true
opt.splitright = true
opt.timeoutlen = 300
opt.updatetime = 250

-- Undo & backup
opt.undofile = true
opt.swapfile = false
opt.backup = false

-- Completion
opt.completeopt = "menuone,noselect"
