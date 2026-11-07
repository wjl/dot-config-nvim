" Plain text, highlighted with a small markdown-like set.
" The markdown filetype is the wrong default here: its plugin turns on
" expandtab, HTML comments, and heading motions, and its syntax treats a
" tab-indented line as code and an underscore inside a word as an error.
" Markers that are rare in prose get a color. The characters stay visible.

if exists('b:current_syntax')
	finish
endif

syn case match
syn spell toplevel
" A fenced block can be taller than the default look-back.
syn sync minlines=200

syn match textListMarker '^\s*\%([-*+]\|\d\+\.\)\s\+' contains=@NoSpell
syn match textQuoteMarker '^\s*>\+' contains=@NoSpell
" Fold markers are part of the note, not just a fold setting.
syn match textFoldMarker '{{{[0-9]*' contains=@NoSpell
syn match textFoldMarker '}}}[0-9]*' contains=@NoSpell
syn match textRule '^\s*\%(-\s*\)\{3,}$' contains=@NoSpell
syn match textRule '^\s*\%(\*\s*\)\{3,}$' contains=@NoSpell
syn match textRule '^\s*\%(=\s*\)\{3,}$' contains=@NoSpell

syn region textCode matchgroup=textCodeDelimiter start='`' end='`' oneline keepend contains=@NoSpell
" \z keeps a longer opening fence from closing on a shorter one.
" The end pattern is a whole line, and it does not match the opening
" backticks because the search starts after them.
syn region textCodeBlock matchgroup=textCodeDelimiter start='^\s*\z(`\{3,}\)' end='^\s*\z1\s*$' keepend contains=@NoSpell
syn region textCodeBlock matchgroup=textCodeDelimiter start='^\s*\z(\~\{3,}\)' end='^\s*\z1\s*$' keepend contains=@NoSpell

" A closing mark is required on the same line. A stray * does not paint
" the rest of the line. ** is bold only when it hugs the words. A spaced
" ** is not emphasis. Underscores are left alone.
syn region textItalic matchgroup=textItalicDelimiter start='\*\*\@!\S\@=' end='\S\@<=\*\*\@!' oneline keepend contains=textCode,@Spell
syn region textBold matchgroup=textBoldDelimiter start='\*\*\S\@=' end='\S\@<=\*\*' oneline keepend contains=textItalic,textCode,@Spell

syn region textHeading matchgroup=textHeadingDelimiter start='^#\{1,6}\s\+' end='$' oneline keepend contains=textBold,textItalic,textCode,textFoldMarker,@Spell

syn match textLink '!\?\[[^]]*\]\s*([^)]*)' contains=@NoSpell
syn match textUrl '\<\%(https\?\|ftp\)://[^[:space:]>]\+' contains=@NoSpell

function! s:links() abort
	highlight! link textHeading Title
	highlight! link textHeadingDelimiter PreProc
	highlight! link textQuoteMarker Comment
	highlight! link textListMarker PreProc
	highlight! link textFoldMarker Special
	highlight! link textRule PreProc
	highlight! link textCode String
	highlight! link textCodeDelimiter Delimiter
	highlight! link textCodeBlock String
	highlight! link textLink Underlined
	highlight! link textUrl Underlined
	" Emphasis changes the face, not the color.
	highlight textBold term=bold cterm=bold gui=bold
	highlight textItalic term=italic cterm=italic gui=italic
	highlight! link textBoldDelimiter textBold
	highlight! link textItalicDelimiter textItalic
endfunction

call s:links()

augroup text_syntax_links
	autocmd! ColorScheme <buffer>
	execute 'autocmd ColorScheme <buffer> call ' . expand('<SID>') . 'links()'
augroup END

let b:current_syntax = 'text'
