let g:terminal_ansi_colors = ['#f65b5b', '#e74c4c', '#6bb05d', '#e59e67', '#5b98a9', '#b185db', '#51a39f', '#c4c4c4', '#343636', '#c26f6f', '#8dc776', '#e7ac7e', '#7ab3c3', '#bb84e5', '#6db0ad', '#cccccc']
hi SpecialKey guifg=#343636
hi NonText guifg=#343636 guibg=NONE
hi Folded guibg=#343636 guifg=#8ccf7e
hi MatchParen guibg=#6cd0ca guifg=#c4c4c4 gui=none
hi CppObjType guifg=#6cd0ca 
hi CocSemMacro guifg=#c47fd5

" token types
hi      CocSemVariable          guifg=#c4c4c4
hi      CocSemParameter         guifg=#e5e5e5
hi      CocSemFunction          guifg=#e57474
hi      CocSemMethod            guifg=#e57474 
hi      CocSemProperty          guifg=#c4c4c4 
hi link CocSemClass             CppObjType
hi link CocSemInterface         CppObjType
hi link CocSemEnum              CppObjType
hi      CocSemEnumMember        guifg=#c47fd5
hi link CocSemType              CppObjType
hi      CocSemUnknown           guifg=#e74c4c
hi      CocSemNamespace         guifg=#6cd0ca
hi link CocSemTypeParameter     CppObjType
hi      CocSemConcept           guifg=#e5c76b
hi      CocSemMacro             guifg=#c47fd5
hi link CocSemModifier          StorageClass
hi      CocSemOperator          guifg=#e59e67
hi link CocSemComment           cComment


"hi      CocSemDeclaration
"hi      CocSemDefinition
hi      CocSemDeprecated        gui=strikethrough term=strikethrough cterm=strikethrough
"hi      CocSemDeduced           guifg=#6cd0ca gui=undercurl term=undercurl cterm=undercurl
"hi      CocSemReadonly
"hi      CocSemAbstract          gui=underline term=underline cterm=underline
hi      CocSemVirtual           guifg=#e57474
"hi      CocSemDependentName
"hi      CocSemDefaultLibrary
"hi      CocSemUsedAsMutablePointer
"hi      CocSemUsedAsMutableReference
"hi      CocSemConstructorOrDestructor
"hi      CocSemUserDefined


hi Number guifg=#8ccf7e

hi CocMenuSel guibg=#242626 gui=italic,bold term=italic,bold cterm=italic,bold

hi CocHighlightText guibg=#343434

hi CocErrorSign guifg=#e74c4c guibg=#232a2d
hi CocInfoSign guifg=#5b98a9 guibg=#232a2d
hi CocHintSign guifg=#6bb05d guibg=#232a2d
hi CocWarningSign guifg=#e59e67 guibg=#232a2d
