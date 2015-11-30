" Plugins are managed by Vundle. Once VIM is open run :BundleInstall to
" install plugins.

" Plugins requiring no additional configuration or keymaps
  Bundle "git://github.com/vim-scripts/Color-Sampler-Pack.git"
  Bundle "git://github.com/oscarh/vimerl.git"
  Bundle "git://github.com/harleypig/vcscommand.vim.git"
  Bundle "git://github.com/altercation/vim-colors-solarized.git"
  Bundle "git://github.com/tpope/vim-cucumber.git"
  Bundle "git://github.com/tpope/vim-endwise.git"
  Bundle "git://github.com/tpope/vim-fugitive.git"
  Bundle "git://github.com/tpope/vim-haml.git"
  Bundle "git://github.com/pangloss/vim-javascript.git"
  Bundle "git://github.com/vim-scripts/L9.git"
  Bundle "git://github.com/tpope/vim-rake.git"
  Bundle "git://github.com/vim-ruby/vim-ruby.git"
  Bundle "git://github.com/michaeljsmith/vim-indent-object.git"
  Bundle "git://github.com/vim-scripts/matchit.zip.git"
  Bundle "git://github.com/kana/vim-textobj-user.git"
  Bundle "git://github.com/vim-scripts/ruby-matchit.git"
  Bundle "git://github.com/ervandew/supertab.git"
  Bundle "git://github.com/tomtom/tcomment_vim.git"

  Bundle "git://github.com/smerrill/vim-arduino.git"
    au BufNewFile,BufRead *.pde set filetype=arduino
    au BufNewFile,BufRead *.ino set filetype=arduino

" Less
  Bundle "git://github.com/groenewege/vim-less.git"
    au BufNewFile,BufRead *.less set filetype=less

" SCSS
  Bundle "git://github.com/cakebaker/scss-syntax.vim.git"
  au BufRead,BufNewFile *.scss set filetype=scss

" Mustache
  Bundle "git://github.com/juvenn/mustache.vim.git"
    " Copied from the plugin; not sure why it isn't working normally
    au BufNewFile,BufRead *.mustache,*.handlebars,*.hbs set filetype=mustache

" Handlebars
  Bundle "git://github.com/nono/vim-handlebars.git"
    au BufNewFile,BufRead *.hbs set filetype=handlebars

" Stylus
  Bundle "git://github.com/wavded/vim-stylus.git"
    au BufNewFile,BufRead *.styl set filetype=stylus

" Coffee script
  Bundle "git://github.com/kchmck/vim-coffee-script.git"
    au BufNewFile,BufRead *.coffee,*.eco set filetype=coffee

" Scala
  Bundle "https://github.com/rosstimson/scala-vim-support.git"
    au BufNewFile,BufRead *.scala set filetype=scala

" Markdown syntax highlighting
  Bundle "git://github.com/tpope/vim-markdown.git"
    augroup mkd
      autocmd BufNewFile,BufRead *.mkd      set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.md       set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
      autocmd BufNewFile,BufRead *.markdown set ai formatoptions=tcroqn2 comments=n:> filetype=markdown
    augroup END


" Syntastic for catching syntax errors on save
  Bundle "git://github.com/scrooloose/syntastic.git"
    let g:syntastic_enable_signs=1
    let g:syntastic_quiet_messages = { 'level': 'warnings' }
    let g:syntastic_disabled_filetypes = ['sass']

" Clojure Highlighting"
  Bundle "https://github.com/vim-scripts/VimClojure.git"
  autocmd BufNewFile,BufRead *.clj set filetype=clojure

" Jade Highlighting"
  Bundle "git://github.com/digitaltoad/vim-jade.git"
  autocmd BufNewFile,BufRead *.jade set filetype=jade

" Elixir Highlighting
  Bundle "git://github.com/elixir-lang/vim-elixir.git"
  autocmd BufNewFile,BufRead *.exs set filetype=elixir

" Go Highlighting
  Bundle "git://github.com/fatih/vim-go.git"

" Slim highlighting
  Bundle "git://github.com/slim-template/vim-slim.git"
  autocmd BufNewFile,BufRead *.slim set filetype=haml

" Multiple pasteboard"
" Bundle 'git://github.com/vim-scripts/Yankring.vim.git'

" xmpfilter
  Bundle 't9md/vim-ruby-xmpfilter'
  nmap <Leader>x <Plug>(xmpfilter-mark) <Plug>(xmpfilter-run)

" ctrlp
  Bundle "git://github.com/kien/ctrlp.vim.git"
  nnoremap <leader>b :CtrlPBuffer<CR>
  let g:ctrlp_working_path_mode = '' " enables search of entire filesystem
  let g:ctrlp_max_files = 0
  let g:ctrlp_follow_symlinks=1
  let g:ctrlp_max_depth = 40
  let g:ctrlp_user_command = 'ag %s -i --nocolor --nogroup --hidden --ignore .git --ignore .svn --ignore .hg --ignore .DS_Store --ignore "**/*.pyc" -g ""'

" ctrlp, NERDTree refresh
  function Refresh()
    echo "refreshing files..."

    if exists(":CtrlPClearAllCaches") == 2
      CtrlPClearAllCaches
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

" AG, The Silver Searcher
  Bundle "git://github.com/rking/ag.vim.git"
    nmap g/ :Ag<space>
    nmap g* :Ag -w <C-R><C-W><space>

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

" NERDTree for project drawer
  Bundle "git://github.com/scrooloose/nerdtree.git"
    let NERDTreeHijackNetrw = 0

    nmap <Leader>w :NERDTreeToggle<CR>
    nmap g :NERDTree \| NERDTreeToggle \| NERDTreeFind<CR>

" ZoomWin to fullscreen a particular buffer without losing others
  Bundle "git://github.com/vim-scripts/ZoomWin.git"
    map <Leader>z :ZoomWin<CR>

" Rspec tests"
  Bundle 'thoughtbot/vim-rspec'
  map <Leader>f :call RunCurrentSpecFile()<CR>
  map <Leader>s :call RunNearestSpec()<CR>
  let g:rspec_runner = "os_x_iterm"
  let g:rspec_command = "!bundle exec rspec -f d -c {spec}"

  " map <Leader>l :call RunLastSpec()<CR>

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

" vim ruby refactoring
  Bundle "git://github.com/ecomba/vim-ruby-refactoring"
  nnoremap <leader>rap  :RAddParameter<cr>
  nnoremap <leader>rcpc :RConvertPostConditional<cr>
  nnoremap <leader>rel  :RExtractLet<cr>
  vnoremap <leader>rec  :RExtractConstant<cr>
  vnoremap <leader>relv :RExtractLocalVariable<cr>
  nnoremap <leader>rit  :RInlineTemp<cr>
  vnoremap <leader>rrlv :RRenameLocalVariable<cr>
  vnoremap <leader>rriv :RRenameInstanceVariable<cr>
  vnoremap <leader>rem  :RExtractMethod<cr>

" autojump for vim
  Bundle "git://github.com/trotter/autojump.vim.git"
