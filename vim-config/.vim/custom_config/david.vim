map :vs :vsplit<cr><c-w>l

" fast zoom for a split
map <C-_> <C-w>_

" use ,F to jump to tag in a vertical split
nnoremap <silent> ,F :let word=expand("<cword>")<CR>:vsp<CR>:wincmd w<cr>:exec("tag ". word)<cr>

" use ,gf to go to file in a vertical split
nnoremap <silent> ,gf :vertical botright wincmd f<CR>

" get the last pasted text (via evilchelu)
nnoremap gb '[V']

" strip leading tabs and trailing whitespace
command Tr %s/\s\+$//ge | %s/\t/  /ge | nohlsearch

" replace the selected text
vnoremap <C-r> "hy:%s/\V<C-r>=escape(@h,'/')<CR>//gc<left><left><left>

" search for the selected text in the current file
" this is useful for more complex strings than #/* can search
vnoremap <C-f> "hy:/\V<C-r>=escape(@h,'/')<CR>/<CR>

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


""" plugin-specific settings

""" NERDTree

" auto-change CWD when changing tree root
let NERDTreeChDirMode=2
command -n=? -complete=dir NT NERDTreeToggle <args>

let NERDTreeIgnore=['\.pyc$', '\.rbc$', '\~$', '^tags$']
let NERDTreeDirArrows=1

" map <leader>w :NERDTreeToggle<CR><space>


""" NERDCommenter

" include space in comments
let g:NERDSpaceDelims = 1
let g:NERDRemoveExtraSpaces = 1

map <C-_> <Esc><leader>c<space>

""" vimclojure
let vimclojure#HighlightBuiltins=1
let vimclojure#ParenRainbow=1
let vimclojure#WantNailgun=1
let vimclojure#SplitPos="bottom"
let vimclojure#SplitSize=10
imap <buffer> <silent> <C-,> <Plug>ClojureReplUpHistory
imap <buffer> <silent> <C-.> <Plug>ClojureReplDownHistory

""" autocmd FileType * if &ft == "clojure" && exists("b:vimclojure_repl") | call SetupMyVCRepl() | endif
""" autocmd FileType * if &ft == "clojure" | call SetupMyVCRepl() | endif

""" tagbar
map <silent> <Leader>tb :TagbarOpen<CR>
" map <Leader>t :TagbarToggle<CR>

""" gist
" post gists privately by default
" let g:gist_private = 1
" show private gists by default
let g:gist_show_privates = 1


""" copy-as-rtf/TOhtml
" tell TOhtml to disable line numbering when generating HTML
let g:html_number_lines=0
" and to use a reasonable font
let g:html_font="Menlo"


""" gist
if executable("pbcopy")
  " The copy command
  let g:gist_clip_command = 'pbcopy'
elseif executable("xclip")
  " The copy command
  let g:gist_clip_command = 'xclip -selection clipboard'
elseif executable("putclip")
  " The copy command
  let g:gist_clip_command = 'putclip'
end

" detect filetype if vim failed auto-detection.
let g:gist_detect_filetype = 1

