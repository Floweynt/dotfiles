"Redo and Undo
noremap <C-Z> u
inoremap <C-Z> <C-O>u
noremap <C-Y> <C-R>
inoremap <C-Y> <C-O><C-R>

"Select all variations
noremap <C-A> gggH<C-O>G
inoremap <C-A> <C-O>gg<C-O>gH<C-O>G
cnoremap <C-A> <C-C>gggH<C-endO>G
onoremap <C-A> <C-C>gggH<C-O>G
snoremap <C-A> <C-C>gggH<C-O>G
xnoremap <C-A> <C-C>ggVG

"Control-S for saving
noremap <silent> <C-S> :update<CR>
vnoremap <silent> <C-S> <C-C>:update<CR>
inoremap <silent> <C-S> <C-O>:update<CR>

"clipboard stuff
if has("clipboard")
    vnoremap <C-X> "+x
    vnoremap <C-C> "+y
    map <C-V> "+gP
    cmap <C-V> <C-R>+
    inoremap <C-V> <Esc>"+pi
endif

"misc
vnoremap <tab> >
tnoremap <Esc><Esc> <C-\><C-n>

" Use tab for trigger completion with characters ahead and navigate.
inoremap <F9> <C-O>za
nnoremap <F9> za
onoremap <F9> <C-C>za
vnoremap <F9> zf

vnoremap <C-Down> :m '>+1<CR>gv=gv
vnoremap <C-Up> :m '<-2<CR>gv=gv

imap <C-L> <Esc>V
nmap <C-L> V

nnoremap <F5> :UndotreeToggle<CR>

so $HOME/.dotfiles/nvim/scripts/coc_keybind.vim
