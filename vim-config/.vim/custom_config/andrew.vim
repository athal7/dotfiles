" Color scheme
set t_Co=256
set background=dark
if has("gui")
  colorscheme Tomorrow-Night
" colorscheme jellybeans
else
  colorscheme Tomorrow-Night
" colorscheme jellybeans
endif
set cursorline

" Remap keys
imap jj <Esc>
imap jk <Esc>
imap kk <Esc>

" Highlight over 80 chars
set colorcolumn=80
highlight ColorColumn ctermbg=darkblue guibg=darkblue

"folding settings
set foldmethod=indent   "fold based on indent
set foldnestmax=10      "deepest fold is 10 levels
set nofoldenable        "dont fold by default
set foldlevel=2         "this is just what i use

" set custom cursor
if !has("gui_running")
  if exists('$TMUX')
    let &t_SI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=1\x7\<Esc>\\"
    let &t_EI = "\<Esc>Ptmux;\<Esc>\<Esc>]50;CursorShape=0\x7\<Esc>\\"
  else
    let &t_SI = "\<Esc>]50;CursorShape=1\x7"
    let &t_EI = "\<Esc>]50;CursorShape=0\x7"
  endif
endif

" Use system clipboard, requires +clipboard when you type vim --version
set clipboard=unnamed
