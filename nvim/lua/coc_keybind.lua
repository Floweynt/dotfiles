utils = require("lua_utils");

vim.cmd([[
inoremap <silent><expr> <TAB>
      \ coc#pum#visible() ? coc#pum#next(1) :
      \ CheckBackspace() ? "\<Tab>" :
      \ coc#refresh()
inoremap <expr><S-TAB> coc#pum#visible() ? coc#pum#prev(1) : "\<C-h>"

" Make <CR> to accept selected completion item or notify coc.nvim to format
" <C-g>u breaks current undo, please make your own choice
inoremap <silent><expr> <CR> coc#pum#visible() ? coc#pum#confirm()
                              \: "\<C-g>u\<CR>\<c-r>=coc#on_enter()\<CR>"

function! CheckBackspace() abort
  let col = col('.') - 1
  return !col || getline('.')[col - 1]  =~# '\s'
endfunction

" Use <c-space> to trigger completion
if has('nvim')
  inoremap <silent><expr> <c-space> coc#refresh()
else
  inoremap <silent><expr> <c-@> coc#refresh()
endif

nnoremap <silent> K :call ShowDocumentation()<CR>

function! ShowDocumentation()
  if CocAction('hasProvider', 'hover')
    call CocActionAsync('doHover')
  else
    call feedkeys('K', 'in')
  endif
endfunction
]])

for key, value in pairs({
    ["if"] = "coc-funcobj-i",
    ["af"] = "coc-funcobj-a",
    ["ic"] = "coc-classobj-i",
    ["ac"] = "coc-classobj-a",
}) do
    utils.map("x", key, "<Plug>(" .. value .. ")");
    utils.map("o", key, "<Plug>(" .. value .. ")");
end

for key, value in pairs({
    ["[g"] = "diagnosticPrevious",
    ["]g"] = "diagnosticNext",
    ["gd"] = "jumpDefinition",
    ["gy"] = "jumpTypeDefinition",
    ["gi"] = "jumpImplementation",
    ["gr"] = "jumpReferences",
    ["<leader>rn"] = "rename",
    ["<leader>qf"] = "doQuickfix",
}) do
    vim.keymap.set(
        "n",
        key,
        function() vim.api.nvim_call_function("CocActionAsync", { value }) end,
        { remap = true, silent = true}
    );
end

for key, value in pairs({
    ["<C-F>"] = "doQuickfix",
    ["<C-R>"] = "rename",
    ["<C-D>"] = "jumpDefinition",
}) do
    vim.keymap.set(
        "i",
        key,
        function() vim.api.nvim_call_function("CocActionAsync", { value }) end,
        { remap = false, silent = false }
    );
end

for key, value in pairs({
    ["a"] = "CocList diagnostics",
    ["e"] = "CocList extensions",
    ["c"] = "CocList commands",
    ["o"] = "CocList outline",
    ["s"] = "CocList -I symbols",
    ["j"] = "CocNext",
    ["k"] = "CocPrev",
    ["p"] = "CocListResume",
}) do
    vim.keymap.set(
        "n",
        "<leader>" .. key,
        utils.cmd_callback(value),
            {
            remap = false,
            nowait = true,
            silent = true
        }
    );
end

