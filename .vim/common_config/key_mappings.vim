" Set leader
  let mapleader=","
  let maplocalleader=","

" mapping the jumping between splits. Hold control while using vim nav.
  nmap <C-J> <C-W>j
  nmap <C-K> <C-W>k
  nmap <C-H> <C-W>h
  nmap <C-L> <C-W>l

" buffer resizing mappings
  " nnoremap + :res +10<cr>
  " nnoremap - :res -10<cr>
  " nnoremap _ :res -10<cr>
  nnoremap <S-H> :vertical resize -10<cr>
  nnoremap <S-L> :vertical resize +10<cr>

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

" for pasting large amounts of information
set pastetoggle=<F2>

nnoremap <Leader>n :call NumberToggle()<cr>

" reindent the entire file
  map <Leader>I gg=G``<cr>

" delete all buffers
  map <Leader>d :bufdo bd<cr>

" Yank from the cursor to the end of the line, to be consistent with C and D.
  nnoremap Y y$

" easy wrap toggling
  nmap <Leader>W :set wrap!<cr>

" clean up trailing whitespace
  map <Leader>c :%s/\s\+$<cr>

" compress excess whitespace on current line
  map <Leader>l :s/\v(\S+)\s+/\1 /<cr>:nohl<cr>
