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
        "json", "lua", "markdown", "python", "ruby", "rust", "toml",
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
      ensure_installed = { "lua_ls", "ts_ls", "pyright", "rust_analyzer", "yamlls" },
      automatic_enable = true,
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
          map("<leader>cr", vim.lsp.buf.rename, "Rename")
        end,
      })

      -- Server-specific configs
      vim.lsp.config("lua_ls", {
        settings = {
          Lua = {
            diagnostics = { globals = { "vim" } },
          },
        },
      })

      -- Ruby LSP: use rbenv shim instead of Mason (handles .ruby-version)
      vim.lsp.config("ruby_lsp", {
        cmd = { vim.fn.expand("~/.rbenv/shims/ruby-lsp") },
      })
      vim.lsp.enable("ruby_lsp")
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
            elseif vim.fn["copilot#GetDisplayedSuggestion"]().text ~= "" then
              vim.api.nvim_feedkeys(vim.fn["copilot#Accept"](), "n", true)
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

  -- GitHub PR comments
  {
    "pwntester/octo.nvim",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-telescope/telescope.nvim",
      "nvim-tree/nvim-web-devicons",
    },
    keys = {
      {
        "<leader>gc",
        function()
          local file = vim.fn.expand("%:.")
          local comments = vim.fn.system("gh pr view --json reviewThreads --jq '.reviewThreads[] | select(.path == \"" .. file .. "\") | \"L\\(.line): \\(.comments[0].body)\"' 2>/dev/null")
          if comments == "" then
            vim.notify("No PR comments for this file", vim.log.levels.INFO)
            return
          end
          -- Show in a floating window
          local lines = vim.split(comments, "\n", { trimempty = true })
          local buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
          vim.api.nvim_open_win(buf, true, {
            relative = "editor",
            width = math.min(80, vim.o.columns - 4),
            height = math.min(#lines, 20),
            row = 2,
            col = 2,
            style = "minimal",
            border = "rounded",
            title = " PR Comments: " .. file .. " ",
          })
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf })
        end,
        desc = "PR comments",
      },
      {
        "<leader>gp",
        function()
          local pr = vim.fn.system("gh pr view --json number -q .number 2>/dev/null"):gsub("%s+", "")
          if pr == "" then
            vim.notify("No PR found for this branch", vim.log.levels.ERROR)
            return
          end
          vim.cmd("Octo pr edit " .. pr)
        end,
        desc = "Open PR",
      },
    },
    config = function()
      require("octo").setup({
        suppress_missing_scope = {
          projects_v2 = true,
        },
        mappings = {
          pull_request = {
            goto_file = { lhs = "<leader>gf", desc = "go to file" },
          },
          review_diff = {
            goto_file = { lhs = "<leader>gf", desc = "go to file" },
          },
          file_panel = {
            select_entry = { lhs = "<leader>gf", desc = "go to file" },
          },
        },
      })
    end,
  },

  -- Git diff viewer
  {
    "sindrets/diffview.nvim",
    dependencies = { "nvim-lua/plenary.nvim" },
    keys = {
      { "<leader>gd", "<cmd>DiffviewOpen<CR>", desc = "Diff uncommitted" },
      { "<leader>gD", "<cmd>DiffviewOpen main<CR>", desc = "Diff from main" },
      { "<leader>gq", "<cmd>DiffviewClose<CR>", desc = "Close diff" },
    },
    opts = {},
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

  -- GitHub Copilot (official - inline ghost text)
  {
    "github/copilot.vim",
    event = "InsertEnter",
    init = function()
      -- Disable default Tab map (we handle it in cmp)
      vim.g.copilot_no_tab_map = true
      -- Enable for markdown/yaml (disabled by default)
      vim.g.copilot_filetypes = { markdown = true, yaml = true }
    end,
    config = function()
      vim.keymap.set("i", "<M-Right>", "<Plug>(copilot-accept-word)")
      vim.keymap.set("i", "<M-Down>", "<Plug>(copilot-accept-line)")
      vim.keymap.set("i", "<M-]>", "<Plug>(copilot-next)")
      vim.keymap.set("i", "<M-[>", "<Plug>(copilot-previous)")
      vim.keymap.set("i", "<C-]>", "<Plug>(copilot-dismiss)")
    end,
  },

  -- Autoformatting
  {
    "stevearc/conform.nvim",
    event = { "BufWritePre" },
    cmd = { "ConformInfo" },
    keys = {
      { "<leader>cf", function() require("conform").format({ async = true }) end, desc = "Format buffer" },
    },
    opts = {
      formatters_by_ft = {
        ruby = { "standardrb" },
        javascript = { "prettier" },
        typescript = { "prettier" },
        javascriptreact = { "prettier" },
        typescriptreact = { "prettier" },
        css = { "prettier" },
        html = { "prettier" },
        json = { "prettier" },
        yaml = { "prettier" },
        markdown = { "prettier" },
        lua = { "stylua" },
      },
      format_on_save = {
        timeout_ms = 3000,
        lsp_format = "fallback",
      },
      formatters = {
        standardrb = {
          -- Use bundle exec to respect project's Gemfile version
          command = "bundle",
          args = { "exec", "standardrb", "--fix", "--stdin", "$FILENAME" },
          stdin = true,
        },
      },
    },
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
        { "<leader>g", group = "github" },
        { "<leader>x", group = "execute" },
        { "<leader>t", group = "test" },

        -- File explorer
        { "<leader>n", desc = "Toggle file tree" },

        -- Find (Telescope)
        { "<leader>ff", desc = "Find files" },
        { "<leader>fg", desc = "Live grep" },
        { "<leader>fb", desc = "Buffers" },
        { "<leader>fh", desc = "Help tags" },
        { "<leader>fr", desc = "Recent files" },

        -- Buffer
        { "<leader>bb", desc = "Switch buffer" },
        { "<leader>bd", desc = "Delete buffer" },
        { "<leader>bn", desc = "Next buffer" },
        { "<leader>bp", desc = "Prev buffer" },
        { "<leader>bo", desc = "Delete other buffers" },

        -- Window/split management
        { "<leader>b+", desc = "Increase height" },
        { "<leader>b-", desc = "Decrease height" },
        { "<leader>b>", desc = "Increase width" },
        { "<leader>b<", desc = "Decrease width" },
        { "<leader>b=", desc = "Equalize splits" },
        { "<leader>bm", desc = "Maximize split" },
        { "<leader>bv", desc = "Vertical split" },
        { "<leader>bs", desc = "Horizontal split" },
        { "<leader>bc", desc = "Close split" },

        -- LSP/Code
        { "<leader>ca", desc = "Code action" },
        { "<leader>cf", desc = "Format buffer" },
        { "<leader>cr", desc = "Rename symbol" },

        -- Diagnostics
        { "<leader>e", desc = "Show diagnostic" },

        -- Save
        { "<leader>w", desc = "Save file" },

        -- Paste
        { "<leader>p", desc = "Paste without yank", mode = "x" },

        -- Git/GitHub
        { "<leader>gc", desc = "PR comments" },
        { "<leader>gD", desc = "Diff from main" },
        { "<leader>gd", desc = "Diff uncommitted" },
        { "<leader>gf", desc = "Go to file" },
        { "<leader>gp", desc = "Open PR" },
        { "<leader>gq", desc = "Close diff" },

        -- Execute / AI
        { "<leader>xo", desc = "OpenCode" },
        { "<leader>xt", desc = "Terminal" },
        { "<leader>xa", desc = "Ask AI" },
        { "<leader>xe", desc = "Explain cursor" },
        { "<leader>xr", desc = "Review file" },
        { "<leader>xf", desc = "Fix diagnostics" },
        { "<leader>xp", desc = "Optimize selection", mode = "v" },
        { "<leader>xd", desc = "Document selection", mode = "v" },
        { "<leader>xs", desc = "Test selection", mode = "v" },

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

  -- Testing (vim-test with convention-based file mapping)
  {
    "vim-test/vim-test",
    keys = {
      { "<leader>tt", function() require("test-utils").run_nearest() end, desc = "Run nearest" },
      { "<leader>tf", function() require("test-utils").run_file() end, desc = "Run file" },
      { "<leader>tl", "<cmd>TestLast<cr>", desc = "Run last" },
      { "<leader>ts", "<cmd>TestSuite<cr>", desc = "Run suite" },
      { "<leader>ta", function() require("test-utils").alternate() end, desc = "Alternate file" },
    },
    config = function()
      vim.g["test#strategy"] = "neovim"
      vim.g["test#neovim#start_normal"] = 1
      -- Use binstubs (bin/rspec, bin/rails) if present, otherwise bundle exec
      vim.g["test#ruby#use_binstubs"] = 1
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
      local oc = require("opencode")

      -- Toggle and terminal
      vim.keymap.set({ "n", "t" }, "<leader>xo", oc.toggle, { desc = "OpenCode" })
      vim.keymap.set("n", "<leader>xt", function() Snacks.terminal() end, { desc = "Terminal" })
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

      -- AI code actions (normal mode)
      vim.keymap.set("n", "<leader>xa", function() oc.ask() end, { desc = "Ask AI" })
      vim.keymap.set("n", "<leader>xe", function() oc.prompt("Explain @cursor and its context") end, { desc = "Explain cursor" })
      vim.keymap.set("n", "<leader>xr", function() oc.prompt("Review @file for correctness and readability") end, { desc = "Review file" })
      vim.keymap.set("n", "<leader>xf", function() oc.prompt("Fix these @diagnostics") end, { desc = "Fix diagnostics" })

      -- AI code actions (visual mode - on selection)
      vim.keymap.set("v", "<leader>xa", function() oc.ask() end, { desc = "Ask AI about selection" })
      vim.keymap.set("v", "<leader>xe", function() oc.prompt("Explain @selection") end, { desc = "Explain selection" })
      vim.keymap.set("v", "<leader>xr", function() oc.prompt("Review @selection for correctness and readability") end, { desc = "Review selection" })
      vim.keymap.set("v", "<leader>xp", function() oc.prompt("Optimize @selection for performance and readability") end, { desc = "Optimize selection" })
      vim.keymap.set("v", "<leader>xd", function() oc.prompt("Add documentation comments for @selection") end, { desc = "Document selection" })
      vim.keymap.set("v", "<leader>xs", function() oc.prompt("Add tests for @selection") end, { desc = "Test selection" })
    end,
  },
})
