let g:terminal_ansi_colors = ['#f65b5b', '#e74c4c', '#6bb05d', '#e59e67', '#5b98a9', '#b185db', '#51a39f', '#c4c4c4', '#343636', '#c26f6f', '#8dc776', '#e7ac7e', '#7ab3c3', '#bb84e5', '#6db0ad', '#cccccc']
hi SpecialKey guifg=#343636
hi NonText guifg=#343636 guibg=NONE
hi Folded guibg=#343636 guifg=#8ccf7e
hi MatchParen guibg=#6cd0ca guifg=#c4c4c4 gui=none
hi CppObjType guifg=#6cd0ca gui=bold
hi CocSemMacro guifg=#c47fd5

hi CocSemVariable guifg=#c4c4c4
hi CocSemParameter guifg=#e5e5e5
hi CocSemFunction guifg=#e57474
hi CocSemMethod guifg=#e57474 gui=italic,bold term=italic,bold cterm=italic,bold
hi CocSemProperty guifg=#c4c4c4 gui=italic,bold term=italic,bold cterm=italic,bold
hi link CocSemClass CppObjType
hi link CocSemInterface CppObjType
hi link CocSemEnum CppObjType
hi CocSemEnumMember guifg=#c47fd5 gui=italic,bold term=italic,bold cterm=italic,bold
hi link CocSemType CppObjType
hi CocSemNamespace guifg=#6cd0ca
hi link CocSemTypeParameter CppObjType
hi CocSemConcept guifg=#e5c76b gui=italic,bold term=italic,bold cterm=italic,bold
hi CocSemMacro guifg=#c47fd5
hi link CocSemComment cComment
hi Number guifg=#8ccf7e
hi CocSemVirtual guifg=#e57474 gui=italic,bold,underline term=italic,bold,underline cterm=italic,bold,underline

hi CocMenuSel guibg=#242626 gui=italic,bold term=italic,bold cterm=italic,bold
"hi CocSemDeclaration gui=italic term=italic cterm=italic

hi CocSemDeprecated gui=strikethrough term=strikethrough cterm=strikethrough
hi CocHighlightText guibg=#343434
