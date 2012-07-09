" Color scheme
set background=dark
set t_Co=256
colorscheme jellybeans

" Remap keys
imap jj <Esc>
imap ii <Esc>

" Highlight over 80 chars
  highlight OverLength ctermbg=Blue guibg=#592929
  match OverLength /\%81v.\+/


" don't wrap long lines
  set wrap
