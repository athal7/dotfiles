set nocompatible
call plug#begin('~/.vim/plugged')

" Set leader
  let mapleader=","
  let maplocalleader=","

syntax on                        " enable syntax highlighting
set cursorline                   " Highlight current line
set wrap                         " wrap long lines
set showcmd                      " show commands as we type them
set showmatch                    " highlight matching brackets
set scrolloff=4 sidescrolloff=10 " scroll the window when we get near the edge
set incsearch                    " show the first match as search strings are typed
set hlsearch                     " highlight the search matches
set ignorecase smartcase         " searching is case insensitive when all lowercase
set directory=/tmp/              " set temporary directory (don't litter local dir with swp/tmp files)
set autoread                     " pick up external file modifications
set autoindent                   " match indentation of previous line
set laststatus=2                 " show status line
set display=lastline             " When lines are cropped at the screen bottom, show as much as possible
set backspace=indent,eol,start   " make backspace work in insert mode
set wildmode=list:longest,full   " use tab-complete to see a list of possiblities when entering commands
set clipboard^=unnamed           " Use system clipboard
set shell=zsh                    " Use login shell for commands
set encoding=utf-8               " utf encoding
set number                       " line numbers

" flip the default split directions to sane ones
  set splitright
  set splitbelow

"folding settings
  set foldmethod=indent   "fold based on indent
  set foldnestmax=10      "deepest fold is 10 levels
  set nofoldenable        "dont fold by default

" remember last position in file
  au BufReadPost * if line("'\"") > 0 && line("'\"") <= line("$") | exe "normal g'\"" | endif

" default color scheme
  colorscheme bubblegum

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
  Plug 'leafgarland/typescript-vim'
  Plug 'tpope/vim-haml'
  Plug 'mitsuhiko/vim-python-combined'
  Plug 'elmcast/elm-vim'
    let g:elm_setup_keybindings = 0
  Plug 'prettier/vim-prettier', { 'do': 'yarn install' }
    let g:prettier#config#trailing_comma = 'all'
    let g:prettier#config#semi = 'false'
    let g:prettier#config#print_width = 120
    let g:prettier#config#single_quote = 'true'
    let g:prettier#config#bracket_spacing = 'true'

" linting
  Plug 'w0rp/ale'
  let g:ale_linters = {'python': ['flake8'], 'elixir': ['credo'], 'json': ['fixjson'], 'ruby': ['rubocop']}

" ctrlp
  Plug 'kien/ctrlp.vim'
  nnoremap <leader>b :CtrlPBuffer<CR>
  let g:ctrlp_working_path_mode = '' " enables search of entire filesystem
  let g:ctrlp_max_files = 0
  let g:ctrlp_follow_symlinks=1
  let g:ctrlp_max_depth = 40
  let g:ctrlp_custom_ignore = {
    \ 'dir': '\v[\/](\.git|node_modules|_build|site-packages|deps|__pycache__)$',
    \ 'file': '\v\.(pyc|beam|log)$',
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

" Markdown preview
  Plug 'JamshedVesuna/vim-markdown-preview'
  let vim_markdown_preview_toggle=1
  let vim_markdown_preview_hotkey='<C-m>'
  let vim_markdown_preview_github=1

" Use airline for tmux status bar
  Plug 'edkolev/tmuxline.vim'
  let g:tmuxline_preset = {
    \'win'    : '#I #W',
    \'cwin'    : '#I #W #F'}
  let g:tmuxline_powerline_separators = 0

" Airline status line
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  let g:airline_theme='bubblegum'
  let g:airline_extensions = ['ctrlp', 'tmuxline', 'ale', 'tabline']
  let g:airline_detect_spell=1

" Use airline for the shell prompt
  Plug 'edkolev/promptline.vim'

  call plug#end()

  let g:promptline_powerline_symbols = 0
  let g:promptline_theme = 'airline'
  let g:promptline_preset = {
         \'a'    : [ promptline#slices#cwd() ],
         \'b'    : [ promptline#slices#vcs_branch(), promptline#slices#git_status()]}
