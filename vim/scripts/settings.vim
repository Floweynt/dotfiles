set tabstop=8 softtabstop=0 expandtab shiftwidth=4 smarttab
syntax on
set t_Co=256 
if &term =~ '256color'
    set t_ut=
endif

set encoding=UTF-8
set number relativenumber
set nu rnu
set guifont=CaskaydiaCove\ Nerd\ Font\ Mono\ 14
set colorcolumn=125
set mouse=a
set exrc
set foldmethod=syntax
set list
set listchars=eol:¬,space:⋅
autocmd filetype nerdtree set listchars=
set nofoldenable

set nobackup
set nowritebackup
set updatetime=300
set signcolumn=yes
