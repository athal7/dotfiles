require("lazy").setup({
  -- Colorscheme
  {
    "projekt0n/github-nvim-theme",
    priority = 1000,
    config = function()
      require("github-theme").setup({})
      vim.cmd.colorscheme("github_dark_default")
    end,
  },

  -- File explorer
  {
    "nvim-tree/nvim-tree.lua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    keys = {
      { "<leader>n", "<cmd>NvimTreeToggle<CR>", desc = "Toggle file tree" },
    },
    config = function()
      require("nvim-tree").setup({
        view = { width = 35 },
        filters = { dotfiles = false },
      })
    end,
  },

  -- Fuzzy finder
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>ff", "<cmd>Telescope find_files<CR>", desc = "Find files" },
      { "<leader>fg", "<cmd>Telescope live_grep<CR>", desc = "Live grep" },
      { "<leader>fb", "<cmd>Telescope buffers<CR>", desc = "Buffers" },
      { "<leader>fh", "<cmd>Telescope help_tags<CR>", desc = "Help tags" },
      { "<leader>fr", "<cmd>Telescope oldfiles<CR>", desc = "Recent files" },
    },
  },

  -- Syntax highlighting
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    main = "nvim-treesitter",
    opts = {
      ensure_installed = {
        "bash", "css", "dockerfile", "go", "html", "javascript",
        "json", "lua", "markdown", "python", "rust", "toml",
        "tsx", "typescript", "yaml",
      },
    },
  },

  -- LSP
  {
    "williamboman/mason.nvim",
    config = true,
  },
  {
    "williamboman/mason-lspconfig.nvim",
    dependencies = { "williamboman/mason.nvim" },
    opts = {
      ensure_installed = { "lua_ls", "ts_ls" },
    },
  },
  {
    "neovim/nvim-lspconfig",
    dependencies = { "williamboman/mason-lspconfig.nvim" },
    config = function()
      -- LSP keymaps on attach
      vim.api.nvim_create_autocmd("LspAttach", {
        callback = function(args)
          local map = function(keys, func, desc)
            vim.keymap.set("n", keys, func, { buffer = args.buf, desc = desc })
          end
          map("gd", vim.lsp.buf.definition, "Go to definition")
          map("gr", vim.lsp.buf.references, "Go to references")
          map("K", vim.lsp.buf.hover, "Hover docs")
          map("<leader>ca", vim.lsp.buf.code_action, "Code action")
          map("<leader>rn", vim.lsp.buf.rename, "Rename")
        end,
      })

      -- Configure LSP servers using vim.lsp.config (Neovim 0.11+)
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })
      vim.lsp.config("ts_ls", {})

      -- Enable configured servers
      vim.lsp.enable({ "lua_ls", "ts_ls" })
    end,
  },

  -- Autocompletion
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "hrsh7th/cmp-buffer",
      "hrsh7th/cmp-path",
      "L3MON4D3/LuaSnip",
      "saadparwaiz1/cmp_luasnip",
    },
    config = function()
      local cmp = require("cmp")
      local luasnip = require("luasnip")

      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ["<C-b>"] = cmp.mapping.scroll_docs(-4),
          ["<C-f>"] = cmp.mapping.scroll_docs(4),
          ["<C-Space>"] = cmp.mapping.complete(),
          ["<C-e>"] = cmp.mapping.abort(),
          ["<CR>"] = cmp.mapping.confirm({ select = true }),
          ["<Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { "i", "s" }),
          ["<S-Tab>"] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { "i", "s" }),
        }),
        sources = cmp.config.sources({
          { name = "nvim_lsp" },
          { name = "luasnip" },
          { name = "buffer" },
          { name = "path" },
        }),
      })
    end,
  },

  -- Git signs
  {
    "lewis6991/gitsigns.nvim",
    config = function()
      require("gitsigns").setup({
        signs = {
          add = { text = "+" },
          change = { text = "~" },
          delete = { text = "_" },
          topdelete = { text = "‾" },
          changedelete = { text = "~" },
        },
      })
    end,
  },

  -- Status line
  {
    "nvim-lualine/lualine.nvim",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    config = function()
      require("lualine").setup({
        options = { theme = "github_dark_default" },
      })
    end,
  },

  -- Auto pairs
  {
    "windwp/nvim-autopairs",
    event = "InsertEnter",
    config = true,
  },

  -- Comment toggle
  {
    "numToStr/Comment.nvim",
    keys = {
      { "gcc", mode = "n", desc = "Comment line" },
      { "gc", mode = "v", desc = "Comment selection" },
    },
    config = true,
  },

  -- Which-key (shows available keybindings)
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    config = function()
      local wk = require("which-key")
      wk.setup({
        preset = "classic",
        win = {
          border = "single",
          padding = { 1, 2 },
        },
        layout = {
          width = { min = 20, max = 50 },
          spacing = 3,
        },
        icons = {
          breadcrumb = ">>",
          separator = "->",
          group = "+",
          ellipsis = "...",
          mappings = false,
          keys = {
            Up = "Up ", Down = "Down ", Left = "Left ", Right = "Right ",
            C = "C-", M = "M-", D = "D-", S = "S-",
            CR = "Enter ", Esc = "Esc ", BS = "BS ", Space = "SPC ", Tab = "Tab ",
            NL = "NL ", ScrollWheelDown = "ScrollDn ", ScrollWheelUp = "ScrollUp ",
            F1 = "F1", F2 = "F2", F3 = "F3", F4 = "F4", F5 = "F5", F6 = "F6",
            F7 = "F7", F8 = "F8", F9 = "F9", F10 = "F10", F11 = "F11", F12 = "F12",
          },
        },
      })
      wk.add({
        -- Groups
        { "<leader>f", group = "find" },
        { "<leader>b", group = "buffer" },
        { "<leader>c", group = "code" },
        { "<leader>o", group = "opencode" },

        -- File explorer
        { "<leader>n", desc = "Toggle file tree" },

        -- Find (Telescope)
        { "<leader>ff", desc = "Find files" },
        { "<leader>fg", desc = "Live grep" },
        { "<leader>fb", desc = "Buffers" },
        { "<leader>fh", desc = "Help tags" },
        { "<leader>fr", desc = "Recent files" },

        -- Buffer
        { "<leader>bd", desc = "Delete buffer" },

        -- LSP/Code
        { "<leader>ca", desc = "Code action" },
        { "<leader>rn", desc = "Rename symbol" },

        -- Diagnostics
        { "<leader>e", desc = "Show diagnostic" },

        -- Save
        { "<leader>w", desc = "Save file" },

        -- Paste
        { "<leader>p", desc = "Paste without yank", mode = "x" },

        -- OpenCode
        { "<leader>oo", desc = "Toggle opencode" },
        { "<leader>oa", desc = "Ask opencode" },
        { "<leader>os", desc = "Select action" },
        { "<leader>or", desc = "Review code" },
        { "<leader>oe", desc = "Explain code" },
        { "<leader>of", desc = "Fix diagnostics" },

        -- Comments
        { "gc", desc = "Comment (motion/visual)" },
        { "gcc", desc = "Comment line" },

        -- LSP navigation (shown when LSP attached)
        { "gd", desc = "Go to definition" },
        { "gr", desc = "Go to references" },
        { "K", desc = "Hover docs" },

        -- Diagnostics navigation
        { "[d", desc = "Prev diagnostic" },
        { "]d", desc = "Next diagnostic" },

        -- Buffer navigation
        { "<S-h>", desc = "Prev buffer" },
        { "<S-l>", desc = "Next buffer" },

        -- Window navigation
        { "<C-h>", desc = "Go to left window" },
        { "<C-j>", desc = "Go to lower window" },
        { "<C-k>", desc = "Go to upper window" },
        { "<C-l>", desc = "Go to right window" },
      })
    end,
  },

  -- OpenCode AI integration
  {
    "NickvanDyke/opencode.nvim",
    dependencies = {
      { "folke/snacks.nvim", opts = { input = {}, picker = {}, terminal = {} } },
    },
    config = function()
      vim.o.autoread = true
      vim.keymap.set({ "n", "x" }, "<leader>oa", function() require("opencode").ask("@this: ", { submit = false }) end, { desc = "Ask opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>os", function() require("opencode").select() end, { desc = "Select opencode action" })
      vim.keymap.set({ "n", "t" }, "<leader>oo", function() require("opencode").toggle() end, { desc = "Toggle opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>or", function() require("opencode").ask("Review @this for correctness and readability", { submit = true }) end, { desc = "Review with opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>oe", function() require("opencode").ask("Explain @this and its context", { submit = true }) end, { desc = "Explain with opencode" })
      vim.keymap.set({ "n", "x" }, "<leader>of", function() require("opencode").ask("Fix @diagnostics", { submit = true }) end, { desc = "Fix diagnostics with opencode" })
    end,
  },
})
