if exists("b:current_syntax")
  finish
endif

" inform C syntax that the file was included from cpp.vim
let b:filetype_in_cpp_family = 1

" Read the C syntax to start with
runtime! syntax/cpp.vim
unlet b:current_syntax

syn region cDefine start="^\s*\zs\(%:\|#\)\s*\(cmakedefine\|mesondefine\)\>" skip="\\$" end=" " keepend contains=ALLBUT,@cPreProcGroup,@Spell
syn region cSpecial start="@" end="@" keepend
