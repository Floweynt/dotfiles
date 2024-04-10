vim.cmd([[
"vista
function! NearestMethodOrFunction() abort
  return get(b:, 'vista_nearest_method_or_function', '')
endfunction

set statusline+=%{NearestMethodOrFunction()}
autocmd VimEnter * call vista#RunForNearestMethodOrFunction()
]]);

sema_syms = require("sema_syms");

vim.g["vista#renderer#icons"] = {
    func = sema_syms.func,
    ["function"] = sema_syms.func,
    functions = sema_syms.func,
    var = sema_syms.variable,
    variable = sema_syms.variable,
    variables = sema_syms.variable,
    const = sema_syms.const,
    constant = sema_syms.const,
    constructor = sema_syms.ctor,
    method = sema_syms.func,
    package = sema_syms.namespace,
    packages = sema_syms.namespace,
    enum = sema_syms.enum,
    enummember = sema_syms.enumerator,
    enumerator = sema_syms.enumerator,
    module = sema_syms.namespace,
    modules = sema_syms.namespace,
    type = sema_syms.type,
    typedef = sema_syms.type,
    types = sema_syms.type,
    macro = "!",
    macros = "!",
    map = "!",
    class = sema_syms.type,
    augroup = "!",
    struct = sema_syms.type,
    union = sema_syms.type,
    member = sema_syms.variable,
    target = "!",
    property = sema_syms.variable,
    interface = sema_syms.type,
    namespace = sema_syms.namespace,
    subroutine = sema_syms.func,
    implementation = sema_syms.type,
    typeParameter = sema_syms.type,
    default = "?"
}

vim.g.vista_icon_indent = { "╰─▸ ", "├─▸ " };


