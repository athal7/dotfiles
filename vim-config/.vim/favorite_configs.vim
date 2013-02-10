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

" map spacebar to clear search highlight
  nnoremap <Leader><space> :noh<cr>

  Bundle "git://github.com/tomtom/tcomment_vim.git"

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
