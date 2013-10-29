nnoremap <CR> :nohlsearch<CR>

" easy tabs
map <leader>tn :tabnew<CR>

" hide quickfix window
nnoremap q :ccl<CR>

" easy close
map <leader>x :x<CR>

" easy quit
map <leader>qa :qa<CR>

" indent and tab switching
" Map command-[ and command-] to indenting or outdenting
" while keeping the original selection in visual mode
vmap <A-]> >gv
vmap <A-[> <gv

nmap <A-]> >>
nmap <A-[> <<

omap <A-]> >>
omap <A-[> <<

imap <A-]> <Esc>>>i
imap <A-[> <Esc><<i

" Map Control-# to switch tabs
map  <C-0> 0gt
imap <C-0> <Esc>0gt
map  <C-1> 1gt
imap <C-1> <Esc>1gt
map  <C-2> 2gt
imap <C-2> <Esc>2gt
map  <C-3> 3gt
imap <C-3> <Esc>3gt
map  <C-4> 4gt
imap <C-4> <Esc>4gt
map  <C-5> 5gt
imap <C-5> <Esc>5gt
map  <C-6> 6gt
imap <C-6> <Esc>6gt
map  <C-7> 7gt
imap <C-7> <Esc>7gt
map  <C-8> 8gt
imap <C-8> <Esc>8gt
map  <C-9> 9gt
imap <C-9> <Esc>9gt

map <C-p> gt
map <C-n> gT

" tab movement setup, via ara howard

function TabMove(n)
    let nr = tabpagenr()
    let size = tabpagenr('$')
    " do we want to go left?
    if (a:n != 0)
        let nr = nr - 2
    endif
    " crossed left border?
    if (nr < 0)
        let nr = size-1
        " crossed right border?
    elseif (nr == size)
        let nr = 0
    endif
    " fire move command
    exec 'tabm'.nr
endfunction

map <C-Left> :call TabMove(1)<CR>
map <C-Right> :call TabMove(0)<CR>
" map <C-p> :call TabMove(1)<CR>
" map <C-n> :call TabMove(0)<CR>

" detect filetype if vim failed auto-detection.
let g:gist_detect_filetype = 1

