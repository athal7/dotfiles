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
highlight ColorColumn ctermbg=DarkGray guibg=DarkGray

" Copy and paste with system clipboard
nmap pp :set paste<CR>:r !pbpaste<CR>:set nopaste<CR>
imap pp <Esc>:set paste<CR>:r !pbpaste<CR>:set nopaste<CR>
nmap cc :.w !pbcopy<CR><CR>
vmap cc :w !pbcopy<CR><CR>
