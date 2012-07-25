" Color scheme
set background=dark
set t_Co=256
colorscheme jellybeans

" Remap keys
imap jj <Esc>
imap ii <Esc>

" Highlight over 80 chars
  "highlight OverLength ctermbg=Gray
  "match OverLength /\%81v.\/
set colorcolumn=80
highlight ColorColumn ctermbg=DarkGray guibg=DarkGray


" don't wrap long lines
  set wrap
