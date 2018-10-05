set nocompatible
call plug#begin('~/.vim/plugged')

" Set leader
  let mapleader=","
  let maplocalleader=","

syntax on                        " enable syntax highlighting
set cursorline                   " Highlight current line
set nowrap                       " don't wrap long lines
set showcmd                      " show commands as we type them
set showmatch                    " highlight matching brackets
set scrolloff=4 sidescrolloff=10 " scroll the window when we get near the edge
set incsearch                    " show the first match as search strings are typed
set hlsearch                     " highlight the search matches
set ignorecase smartcase         " searching is case insensitive when all lowercase
set gdefault                     " assume the /g flag on substitutions to replace all matches in a line
set directory=/tmp/              " set temporary directory (don't litter local dir with swp/tmp files)
set autoread                     " pick up external file modifications
set hidden                       " don't abandon buffers when unloading
set autoindent                   " match indentation of previous line
set ruler rulerformat=%=%l/%L    " show current line info (current/total)
set laststatus=2                 " show status line
set display=lastline             " When lines are cropped at the screen bottom, show as much as possible
set backspace=indent,eol,start   " make backspace work in insert mode
set wildmode=list:longest,full   " use tab-complete to see a list of possiblities when entering commands
set clipboard^=unnamed           " Use system clipboard
set shell=zsh                    " Use login shell for commands
set encoding=utf-8               " utf encoding

" relative line numbers, with absolute on the current line
  set relativenumber
  set number

" flip the default split directions to sane ones
  set splitright
  set splitbelow

" highlight trailing whitespace
  set listchars=tab:>\ ,trail:·,extends:>,precedes:<,nbsp:+
  set list

"folding settings
  set foldmethod=indent   "fold based on indent
  set foldnestmax=10      "deepest fold is 10 levels
  set nofoldenable        "dont fold by default
  set foldlevel=1         "this is just what i use

" remember last position in file
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g'\"" | endif

" default color scheme
  set t_Co=256
  colorscheme hybrid
  highlight Normal ctermbg=none
  highlight LineNR ctermfg=lightgrey
  highlight CursorLine ctermbg=darkgrey
  highlight OverLength ctermbg=lightgrey
  match OverLength /\%121v.\+/

" use 2 spaces for tabs
  set expandtab tabstop=2 softtabstop=2 shiftwidth=2
  set smarttab

" Strip whitespace on save
  autocmd FileType * autocmd BufWritePre <buffer> :%s/\s\+$//e

" mapping the jumping between splits. Hold control while using vim nav.
  nmap <C-J> <C-W>j
  nmap <C-K> <C-W>k
  nmap <C-H> <C-W>h
  nmap <C-L> <C-W>l

" buffer resizing mappings
  nnoremap <S-H> :vertical resize -10<cr>
  nnoremap <S-L> :vertical resize +10<cr>

" buffer movement and closing
  nnoremap <Tab> :bnext<CR>
  nnoremap <S-Tab> :bprevious<CR>
  cnoreabbrev x w<bar>bd

" reindent the entire file
  map <Leader>I gg=G``<cr>

" format JSON
  command FormatJSON %!jq '.'

" Yank from the cursor to the end of the line, to be consistent with C and D.
  nnoremap Y y$

" refresh ctrlp and nerdtree
  function Refresh()
    echo "refreshing files..."

    if exists(":CtrlPClearAllCaches") == 2
      CtrlPClearAllCaches
    endif

    if exists("t:NERDTreeBufName")
      let nr = bufwinnr(t:NERDTreeBufName)
      if nr != -1
        exe nr . "wincmd w"
        exe substitute(mapcheck("R"), "<CR>", "", "")
        wincmd p
      endif
    endif
  endfunction
  map <Leader>r :call Refresh()<cr>

" Adds 'end' in ruby
  Plug 'tpope/vim-endwise'

" Git wrapper
  Plug 'tpope/vim-fugitive'

" Insert-mode auto-completion with 'tab'
  Plug 'ervandew/supertab'

" Universal comment plugin
  Plug 'tomtom/tcomment_vim'

" Syntax highlighting
    au BufRead,BufNewFile {Gemfile,Rakefile,Vagrantfile,Thorfile,config.ru} set ft=ruby
  Plug 'groenewege/vim-less'
    au BufNewFile,BufRead *.less set filetype=less
  Plug 'cakebaker/scss-syntax.vim'
    au BufRead,BufNewFile *.scss set filetype=scss
  Plug 'juvenn/mustache.vim'
    au BufNewFile,BufRead *.mustache,*.handlebars,*.hbs set filetype=mustache
  Plug 'nono/vim-handlebars'
    au BufNewFile,BufRead *.hbs set filetype=handlebars
  Plug 'kchmck/vim-coffee-script'
    au BufNewFile,BufRead *.coffee,*.eco set filetype=coffee
  Plug 'rosstimson/scala-vim-support'
    au BufNewFile,BufRead *.scala set filetype=scala
  Plug 'tpope/vim-markdown'
    augroup mkd
      autocmd BufNewFile,BufRead *.mkd      set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.md       set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.markdown set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
    augroup END
  Plug 'vim-scripts/VimClojure'
    autocmd BufNewFile,BufRead *.clj set filetype=clojure
  Plug 'elixir-lang/vim-elixir'
    autocmd BufNewFile,BufRead *.exs,*.ex set filetype=elixir
    autocmd BufWritePost *.exs,*.ex execute ":!mix format <afile>"
  Plug 'fatih/vim-go'
    au BufRead,BufNewFile *.go set filetype=go
  Plug 'slim-template/vim-slim'
    autocmd BufNewFile,BufRead *.slim set filetype=haml
  Plug 'othree/yajs'
    au BufNewFile,BufRead *.json set ai filetype=javascript
  Plug 'tpope/vim-haml'
  Plug 'mitsuhiko/vim-python-combined'
  Plug 'elmcast/elm-vim'
    let g:elm_setup_keybindings = 0

" linting
  Plug 'w0rp/ale'
  let g:ale_linters = {'python': ['flake8'], 'elixir': ['credo'], 'json': ['fixjson']}

" xmpfilter
  Plug 't9md/vim-ruby-xmpfilter'
  nmap <Leader>x <Plug>(xmpfilter-mark) <Plug>(xmpfilter-run)

" ctrlp
  Plug 'kien/ctrlp.vim'
  nnoremap <leader>b :CtrlPBuffer<CR>
  let g:ctrlp_working_path_mode = '' " enables search of entire filesystem
  let g:ctrlp_max_files = 0
  let g:ctrlp_follow_symlinks=1
  let g:ctrlp_max_depth = 40
  let g:ctrlp_custom_ignore = {
    \ 'dir': '\v[\/](\.git|node_modules|_build|site-packages|deps|__pycache__)$',
    \ 'file': '\v\.(pyc|beam)$',
    \ }

" Ack
  Plug 'mileszs/ack.vim'
    nmap g/ :Ack<space>
    nmap g* :Ack -w <C-R><C-W><space>

" Tabular for aligning text
  Plug 'godlygeek/tabular'
    map <Leader>a :Tabularize<space>

" NERDTree for project drawer
  Plug 'scrooloose/nerdtree'
    let NERDTreeHijackNetrw = 0
    nmap <Leader>w :NERDTreeToggle<CR>

" ZoomWin to fullscreen a particular buffer without losing others
  Plug 'vim-scripts/ZoomWin'
    map <Leader>z :ZoomWin<CR>

" Use airline for the shell prompt
  Plug 'edkolev/promptline.vim'

" Use airline for tmux status bar
  Plug 'edkolev/tmuxline.vim'
  let g:tmuxline_preset = {
    \'a'      : '#h',
    \'b'      : "kube: #(kubectl config get-contexts | grep \"*\" | awk '{print $3, $5}')",
    \'win'    : '#I #W',
    \'cwin'    : '#I #W',
    \'y'    : "sync-panes: #(tmux show-window-options | grep synchronize-panes | awk '{print $2}')",
    \'z'    : '%a %l:%M%p '}

" Airline status line
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  let g:airline_theme='hybrid'
  let g:airline_powerline_fonts = 1
  let g:airline_extensions = ['ctrlp', 'tmuxline', 'tabline', 'ale']

" Time tracking
  Plug 'wakatime/vim-wakatime'

" Markdown preview
  Plug 'JamshedVesuna/vim-markdown-preview'
  let vim_markdown_preview_github=1
  let vim_markdown_preview_hotkey='<C-m>'

  call plug#end()

  let g:promptline_theme = 'airline'
  let g:promptline_preset = {
         \'a'    : [ promptline#slices#cwd() ],
         \'b'    : [ promptline#slices#vcs_branch(), promptline#slices#git_status()]}
