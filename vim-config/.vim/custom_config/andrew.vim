" Color scheme
set background=dark
set t_Co=256
colorscheme jellybeans

" Remap keys
imap jj <Esc>
imap ii <Esc>
imap jk <Esc>
imap kk <Esc>

" Highlight over 80 chars
set colorcolumn=80
highlight ColorColumn ctermbg=DarkBlue guibg=DarkBlue

" Copy and paste with system clipboard
nmap pp :set paste<CR>:r !pbpaste<CR>:set nopaste<CR>
imap <F1> <Esc>:set paste<CR>:r !pbpaste<CR>:set nopaste<CR>
nmap cc :.w !pbcopy<CR><CR>
vmap cc :w !pbcopy<CR><CR>

"folding settings
set foldmethod=indent   "fold based on indent
set foldnestmax=10      "deepest fold is 10 levels
set nofoldenable        "dont fold by default
set foldlevel=2         "this is just what i use

" set custom cursor -- vertical bar in insert mode (iTerm2)
" from http://www.iterm2.com/#/section/documentation/escape_codes
if !has("gui_running")
  let &t_SI = "\<Esc>]50;CursorShape=1\x7"
  let &t_EI = "\<Esc>]50;CursorShape=0\x7"
endif
