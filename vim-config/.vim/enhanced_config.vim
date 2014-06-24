" PLUGINS
  Bundle "git://github.com/tpope/vim-git.git"
  Bundle "git://github.com/nelstrom/vim-textobj-rubyblock.git"
  Bundle "git://github.com/wgibbs/vim-irblack.git"
  Bundle "git://github.com/tpope/vim-repeat.git"
  Bundle "git://github.com/kien/ctrlp.vim.git"
  Bundle "git://github.com/Lokaltog/vim-powerline.git"

" ACK
  Bundle "git://github.com/mileszs/ack.vim.git"
    nmap g/ :Ack!<space>
    nmap g* :Ack! -w <C-R><C-W><space>
    nmap ga :AckAdd!<space>
    nmap gn :cnext<CR>
    nmap gp :cprev<CR>
    nmap gq :ccl<CR>
    nmap gl :cwindow<CR>

" Tagbar for navigation by tags using CTags
  Bundle "git://github.com/majutsushi/tagbar.git"
    let g:tagbar_autofocus = 1
    map <Leader>rt :!ctags --extra=+f -R *<CR><CR>
    map <Leader>. :TagbarToggle<CR>

" Ruby focused unit test (wrapped in an if-loaded because it doesn't like
" being loaded twice)
  if !exists(':RunRubyFocusedUnitTest')
    Bundle "git://github.com/drewolson/ruby_focused_unit_test_vim.git"
      nmap <Leader>ra :wa<CR> :RunAllRubyTests<CR>
      nmap <Leader>rc :wa<CR> :RunRubyFocusedContext<CR>
      nmap <Leader>rf :wa<CR> :RunRubyFocusedUnitTest<CR>
      nmap <Leader>rl :wa<CR> :RunLastRubyTest<CR>
  endif

" Rspec tests"
  Bundle 'thoughtbot/vim-rspec'
  map <Leader>v :call RunCurrentSpecFile()<CR>
  map <Leader>s :call RunNearestSpec()<CR>
  " map <Leader>l :call RunLastSpec()<CR>

" Markdown preview to quickly preview markdown files
  Bundle "git://github.com/maba/vim-markdown-preview.git"
  map <buffer> <Leader>mp :Mm<CR>

" NERDTree for project drawer
  Bundle "git://github.com/scrooloose/nerdtree.git"
    let NERDTreeHijackNetrw = 0

    nmap <Leader>w :NERDTreeToggle<CR>
    nmap g :NERDTree \| NERDTreeToggle \| NERDTreeFind<CR>

" Tabular for aligning text
  Bundle "git://github.com/godlygeek/tabular.git"
    function! CustomTabularPatterns()
      if exists('g:tabular_loaded')
        AddTabularPattern! symbols         / :/l0
        AddTabularPattern! hash            /^[^>]*\zs=>/
        AddTabularPattern! chunks          / \S\+/l0
        AddTabularPattern! assignment      / = /l0
        AddTabularPattern! comma           /^[^,]*,/l1
        AddTabularPattern! colon           /:\zs /l0
        AddTabularPattern! options_hashes  /:\w\+ =>/
      endif
    endfunction

    autocmd VimEnter * call CustomTabularPatterns()

    " shortcut to align text with Tabular
    map <Leader>a :Tabularize<space>

" Fuzzy finder for quickling opening files / buffers
  Bundle "git://github.com/clones/vim-fuzzyfinder.git"
    let g:fuf_coveragefile_prompt = '>GoToFile[]>'
    let g:fuf_coveragefile_exclude = '\v\~$|' .
    \                                '\.(o|exe|dll|bak|swp|log|sqlite3|png|gif|jpg)$|' .
    \                                '(^|[/\\])\.(hg|git|bzr|bundle)($|[/\\])|' .
    \                                '(^|[/\\])(log|tmp|vendor|system|doc|coverage|build|generated|node_modules)($|[/\\])'

    let g:fuf_keyOpenTabpage = '<D-CR>'

    nmap <Leader>t :FufCoverageFile<CR>
    nmap <Leader>b :FufBuffer<CR>
    nmap <Leader>f :FufRenewCache<CR>
    nmap <Leader>T :FufTagWithCursorWord!<CR>


" ZoomWin to fullscreen a particular buffer without losing others
  Bundle "git://github.com/vim-scripts/ZoomWin.git"
    map <Leader>z :ZoomWin<CR>


" Unimpaired for keymaps for quicky manipulating lines and files
  Bundle "git://github.com/tpope/vim-unimpaired.git"
    " Bubble single lines
    nmap <C-Up> [e
    nmap <C-Down> ]e

    " Bubble multiple lines
    vmap <C-Up> [egv
    vmap <C-Down> ]egv

" rails.vim, nuff' said
  Bundle "git://github.com/tpope/vim-rails.git"
    map <Leader>oc :Rcontroller<Space>
    map <Leader>ov :Rview<Space>
    map <Leader>om :Rmodel<Space>
    map <Leader>oh :Rhelper<Space>
    map <Leader>oj :Rjavascript<Space>
    map <Leader>os :Rstylesheet<Space>
    map <Leader>oi :Rintegrationtest<Space>
    map <Leader>ou :Runittest<Space>
    map <Leader>of :Rfunctionaltest<Space>
    map <Leader>osp :Rspec<Space>
    map <Leader>oin :Rinitializer<Space>

" surround for adding surround 'physics'
  Bundle "git://github.com/tpope/vim-surround.git"
    " # to surround with ruby string interpolation
    let g:surround_35 = "#{\r}" " #
    " - to surround with no-output erb tag
    let g:surround_45 = "<% \r %>" " -
    " = to surround with output erb tag
    let g:surround_61 = "<%= \r %>" " =
    " v...s#  Wrap the selection in #{}
    let g:surround_113 = "#{\r}" " v

" KEY MAPPINGS
" get out of insert mode easier
  imap <D-i> <Esc>
  imap jj <Esc>
  imap jk <Esc>
  imap kk <Esc>

" easy wrap toggling
  nmap <Leader>W :set wrap!<cr>

" close all other windows (in the current tab)
  nmap gW :only<cr>

" go to the alternate file (previous buffer) with g-enter
  nmap g 

" shortcuts for frequenly used files
  nmap gs :e db/schema.rb<cr>
  nmap gr :e config/routes.rb<cr>

" insert blank lines without going into insert mode
  nmap go o<esc>
  nmap gO O<esc>

" shortcut for =>
  imap <C-l> <Space>=><Space>

" handy macro expansion
  iabbrev Lipsum Lorem ipsum dolor sit amet, consectetur adipisicing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum
  iabbrev rdebug require 'ruby-debug'; Debugger.start; Debugger.settings[:autoeval] = 1; Debugger.settings[:autolist] = 1; debugger; 0;
  abbrev hte the

" Yank from the cursor to the end of the line, to be consistent with C and D.
  nnoremap Y y$

" clean up trailing whitespace
  map <Leader>c :%s/\s\+$<cr>

" compress excess whitespace on current line
  map <Leader>l :s/\v(\S+)\s+/\1 /<cr>:nohl<cr>

" delete all buffers
  map <Leader>d :bufdo bd<cr>

" map spacebar to clear search highlight
  nnoremap <Leader><space> :noh<cr>

" make tab key match bracket pairs
  nnoremap <tab> %
  vnoremap <tab> %

" reindent the entire file
  map <Leader>I gg=G``<cr>

" insert the path of currently edited file into a command
" Command mode: Ctrl-P
  cmap <C-S-P> <C-R>=expand("%:p:h") . "/" <cr>

" allow semicolon for colon
nmap ; :

""" ctrlp, fuzzyfind, NERDTree refresh
function Refresh()
  echo "refreshing files..."

  if exists(":CtrlPClearAllCaches") == 2
    CtrlPClearAllCaches
  endif

  if exists("FufRenewCache")
    FufRenewCache
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
