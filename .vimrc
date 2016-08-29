set nocompatible
filetype off

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/vundle
call vundle#begin()

" let Vundle manage Vundle, required
  Plugin 'VundleVim/Vundle.vim'

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
set shell=bash\ -l               " Use login shell for commands
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
  set background=light
  colorscheme papercolor
  highlight Normal ctermbg=None

" Highlight long lines
  highlight OverLength ctermbg=darkgrey
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

" buffer movement
  nnoremap <Tab> :bnext<CR>
  nnoremap <S-Tab> :bprevious<CR>

" allow use of keypad
  :inoremap <Esc>Oq 1
  :inoremap <Esc>Or 2
  :inoremap <Esc>Os 3
  :inoremap <Esc>Ot 4
  :inoremap <Esc>Ou 5
  :inoremap <Esc>Ov 6
  :inoremap <Esc>Ow 7
  :inoremap <Esc>Ox 8
  :inoremap <Esc>Oy 9
  :inoremap <Esc>Op 0
  :inoremap <Esc>On .
  :inoremap <Esc>OQ /
  :inoremap <Esc>OR *
  :inoremap <Esc>Ol +
  :inoremap <Esc>OS -

" reindent the entire file
  map <Leader>I gg=G``<cr>

" Yank from the cursor to the end of the line, to be consistent with C and D.
  nnoremap Y y$

" clean up trailing whitespace
  map <Leader>c :%s/\s\+$<cr>

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
  Plugin 'tpope/vim-endwise'

" Git wrapper
  Plugin 'tpope/vim-fugitive'

" Insert-mode auto-completion with 'tab'
  Plugin 'ervandew/supertab'

" Universal comment plugin
  Plugin 'tomtom/tcomment_vim'

" Syntax highlighting
    au BufRead,BufNewFile {Gemfile,Rakefile,Vagrantfile,Thorfile,config.ru} set ft=ruby
  Plugin 'groenewege/vim-less'
    au BufNewFile,BufRead *.less set filetype=less
  Plugin 'cakebaker/scss-syntax.vim'
    au BufRead,BufNewFile *.scss set filetype=scss
  Plugin 'juvenn/mustache.vim'
    au BufNewFile,BufRead *.mustache,*.handlebars,*.hbs set filetype=mustache
  Plugin 'nono/vim-handlebars'
    au BufNewFile,BufRead *.hbs set filetype=handlebars
  Plugin 'kchmck/vim-coffee-script'
    au BufNewFile,BufRead *.coffee,*.eco set filetype=coffee
  Plugin 'rosstimson/scala-vim-support'
    au BufNewFile,BufRead *.scala set filetype=scala
  Plugin 'tpope/vim-markdown'
    augroup mkd
      autocmd BufNewFile,BufRead *.mkd      set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.md       set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.markdown set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
    augroup END
  Plugin 'vim-scripts/VimClojure'
    autocmd BufNewFile,BufRead *.clj set filetype=clojure
  Plugin 'elixir-lang/vim-elixir'
    autocmd BufNewFile,BufRead *.exs,*.ex set filetype=elixir
  Plugin 'fatih/vim-go'
    au BufRead,BufNewFile *.go set filetype=go
  Plugin 'slim-template/vim-slim'
    autocmd BufNewFile,BufRead *.slim set filetype=haml
  Plugin 'othree/yajs'
    au BufNewFile,BufRead *.json set ai filetype=javascript
  Plugin 'tpope/vim-haml'

" xmpfilter
  Plugin 't9md/vim-ruby-xmpfilter'
  nmap <Leader>x <Plug>(xmpfilter-mark) <Plug>(xmpfilter-run)

" ctrlp
  Plugin 'kien/ctrlp.vim'
  nnoremap <leader>b :CtrlPBuffer<CR>
  let g:ctrlp_working_path_mode = '' " enables search of entire filesystem
  let g:ctrlp_max_files = 0
  let g:ctrlp_follow_symlinks=1
  let g:ctrlp_max_depth = 40
  let g:ctrlp_user_command = "ag %s -i --nocolor --nogroup --hidden --ignore  --ignore .svn --ignore .hg --ignore .DS_Store --ignore '**/*.pyc' -g ''"

" AG, The Silver Searcher
  Plugin 'rking/ag.vim'
    nmap g/ :Ag<space>
    nmap g* :Ag -w <C-R><C-W><space>

" Tabular for aligning text
  Plugin 'godlygeek/tabular'
    map <Leader>a :Tabularize<space>

" NERDTree for project drawer
  Plugin 'scrooloose/nerdtree'
    let NERDTreeHijackNetrw = 0
    nmap <Leader>w :NERDTreeToggle<CR>

" ZoomWin to fullscreen a particular buffer without losing others
  Plugin 'vim-scripts/ZoomWin'
    map <Leader>z :ZoomWin<CR>

" Airline status line
  Plugin 'vim-airline/vim-airline'
  Plugin 'vim-airline/vim-airline-themes'
  let g:airline_theme='papercolor'
  let g:airline_powerline_fonts = 1
  let g:airline_extensions = ['ctrlp']

" Use airline for tmux status bar
  Plugin 'edkolev/tmuxline.vim'
  let g:tmuxline_theme = 'airline'
  let g:tmuxline_preset = {
    \'a'    : '#S',
    \'b'    : '',
    \'c'    : '',
    \'win'  : '#I #W',
    \'cwin' : '#I #W',
    \'x'    : '',
    \'y'    : '#{battery_icon} #{battery_percentage} #{battery_remain}',
    \'z'    : '%a %l:%M%p '}

" Use airline for shell prompt
  Plugin 'edkolev/promptline.vim'
  let g:promptline_theme = 'airline'

  call vundle#end()
  filetype plugin indent on

  let g:promptline_preset = {
      \'a'    : [ promptline#slices#cwd() ],
      \'b'    : [ promptline#slices#vcs_branch(), promptline#slices#git_status()]}
