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
set gdefault                     " assume the /g flag on substitutions to replace all matches in a line
set directory=/tmp/              " set temporary directory (don't litter local dir with swp/tmp files)
set autoread                     " pick up external file modifications
set hidden                       " don't abandon buffers when unloading
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

" color scheme
  Plug 'rakr/vim-one'
  set background=dark
  colorscheme one

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

" Universal comment plugin
  Plug 'tomtom/tcomment_vim'

" Syntax highlighting
  " Plug 'tpope/vim-markdown'
  "   augroup mkd
  "     autocmd BufNewFile,BufRead *.mkd      set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
  "     autocmd BufNewFile,BufRead *.md       set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
  "     autocmd BufNewFile,BufRead *.markdown set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
  "   augroup END
  " Plug 'elixir-lang/vim-elixir'
  "   autocmd BufNewFile,BufRead *.exs,*.ex set filetype=elixir
  "   autocmd BufWritePost *.exs,*.ex execute ':!mix format <afile>'
  " Plug 'fatih/vim-go'
  "   au BufRead,BufNewFile *.go set filetype=go
  " Plug 'othree/yajs'
  "   au BufNewFile,BufRead *.json set ai filetype=javascript
  Plug 'leafgarland/typescript-vim'
  Plug 'mitsuhiko/vim-python-combined'

  Plug 'editorconfig/editorconfig-vim'
  let g:EditorConfig_exclude_patterns = ['fugitive://.\*', 'scp://.\*']

" linting, auto-formatting, and completion
  Plug 'w0rp/ale'
  let g:ale_linters = {'python': ['flake8'], 'elixir': ['credo'], 'json': ['fixjson'], 'ruby': ['rubocop'], 'javascript': ['eslint']}
  let g:ale_fixers =  ['prettier', 'eslint']
  let g:ale_fix_on_save = 1
  let g:ale_completion_tsserver_autoimport = 1
  let g:ale_completion_enabled = 1
  set omnifunc=ale#completion#OmniFunc

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

" Aligning text
  Plug 'godlygeek/tabular'

" Project drawer
  Plug 'scrooloose/nerdtree'
    let NERDTreeHijackNetrw = 0
    let NERDTreeShowHidden=1
    nmap <Leader>w :NERDTreeToggle<CR>

" ZoomWin to fullscreen a particular buffer without losing others
  Plug 'vim-scripts/ZoomWin'
    map <Leader>z :ZoomWin<CR>

" Markdown preview
  Plug 'JamshedVesuna/vim-markdown-preview'
  let vim_markdown_preview_toggle=1
  let vim_markdown_preview_hotkey='<C-m>'
  let vim_markdown_preview_github=1

" Tmux status bar
  Plug 'edkolev/tmuxline.vim'
  let g:tmuxline_preset = {
    \'win'    : '#I #W',
    \'cwin'    : '#I #W #F'}
  let g:tmuxline_powerline_separators = 0

" Status line
  Plug 'vim-airline/vim-airline'
  Plug 'vim-airline/vim-airline-themes'
  let g:airline_theme='one'
  let g:airline_extensions = ['ctrlp', 'tmuxline', 'ale', 'tabline']
  let g:airline_detect_spell=1

" Shell prompt
  Plug 'edkolev/promptline.vim'

  call plug#end()

  let g:promptline_powerline_symbols = 0
  let g:promptline_theme = 'airline'
  let g:promptline_preset = {
         \'a'    : [ promptline#slices#cwd() ],
         \'b'    : [ promptline#slices#vcs_branch(), promptline#slices#git_status()]}
