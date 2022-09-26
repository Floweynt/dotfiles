" cSpell:ignore phydesc

if exists("b:current_syntax")
  finish
endif

syn match phydescIdentifier '[a-zA-Z][a-zA-Z_0-9]*'

syn match phydescObjectType '[a-zA-Z][a-zA-Z_0-9]*' contained
syn match phydescControlType '[a-zA-Z][a-zA-Z_0-9]*' contained  
syn match phydescSpecialFunction '[a-zA-Z][a-zA-Z_0-9]*' contained

syn keyword phydescKeywords objtype nextgroup=phydescObjectType skipwhite
syn keyword phydescKeywords control nextgroup=phydescControlType skipwhite
syn keyword phydescKeywords force renderer nextgroup=phydescSpecialFunction skipwhite

syn case ignore
syn match phydescNumber '[+-]\?\d\+'
syn match phydescNumber '[+-]\?\d\+\.\d*\%(e[-+]\=\d\+\)\='
syn match phydescNumber '[+-]\?\.\d*\%(e[-+]\=\d\+\)\='
syn match phydescNumber '[+-]\?0x\x+'
syn match phydescNumber '[+-]\?\x\+\.\x*\%(e[-+]\=\x\+\)\='
syn match phydescNumber '[+-]\?\.\x*\%(e[-+]\=\x\+\)\='
syn case match

syn match phydescString '"[^"\\]*\(\\.[^"\\]*\)*"'
syn match phydescKey '[a-zA-Z][a-zA-Z_0-9]* *:\@='
syn match phydescFunctionCall '[a-zA-Z][a-zA-Z_0-9]* *(\@='

hi link phydescObjectType Type
hi link phydescControlType Type
hi link phydescSpecialFunction Type 
hi link phydescKeywords Keyword
hi link phydescNumber Number 
hi link phydescString String 
hi link phydescKey Identifier
hi link phydescFunctionCall cType
hi link phydescIdentifier Identifier
let b:current_syntax = "phydesc"
