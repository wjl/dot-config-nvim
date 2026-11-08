" Additions to the runtime markdown syntax. *.txt files are markdown too.

" A _ inside a word (snake_case, file_name.txt) is not an error.
syn clear markdownError

" Fold markers are part of the note, not just a fold setting. The link to
" Special is also in config.colorscheme's shared links, so it survives a
" colorscheme change.
syn match markdownFoldMarker '{{{\d*' contains=@NoSpell
syn match markdownFoldMarker '}}}\d*' contains=@NoSpell
syn cluster markdownInline add=markdownFoldMarker
hi def link markdownFoldMarker Special
