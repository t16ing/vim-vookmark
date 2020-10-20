"------------------------------------------------------------------------------
"    Plugin Name: vookmark.vim
"
"    Description: Vim plugin to manage bookmarks.
"
"         Author: t16ing <t16ing@users.noreply.github.com>
"
"    Last Change: 2013 Dec 9
"        Version: 1.0.2
"
"      Copyright: GPL Version 2, June 1991
"
"        Install: 1. Recommend to install by vundle.
"                 2. Remap hotkeys and modify options in your vimrc file.
"------------------------------------------------------------------------------

" History: {{{1

"------------------------------------------------------------------------------
" 20131205 - v1.0.1, minor changes and fixes:
"            New command 'VmkFactoryReset', to reset Vookmark plugin.
"            New options 'g:vookmark_mapkeys' to decide mapping keys or not.
"            Fix a potential bug for parsing 'sign' content.
"            Fix ghost bookmarks by s:VookmarkCorrectVmks().
" 20131202 - First draft version.

"}}}

" Module: Begin of plugin. {{{1
"------------------------------------------------------------------------------

" load script once
"------------------------------------------------------------------------------
if exists('s:plugin_loaded')
	finish
endif
let s:plugin_loaded=1

"}}}

" Options: {{{1
"------------------------------------------------------------------------------

" g:vookmark_savepath is default at $HOME
if !exists('g:vookmark_savepath')
	let g:vookmark_savepath=$HOME.'/.vookmark'
endif

" g:vookmark_mapkeys is default 1
" 'let g:vookmark_mapkeys=0' to disable key mapping
if !exists('g:vookmark_mapkeys')
	let g:vookmark_mapkeys=1
endif

"}}}

" Global Variables: {{{1
"------------------------------------------------------------------------------

" Color the bookmarked line
"------------------------------------------------------------------------------
highlight VmkColor term=bold ctermfg=black ctermbg=darkcyan guifg=black guibg=darkcyan
sign define vookmark text=>> texthl=VmkColor linehl=VmkColor

"}}}

" Function: Object 'vmk' Management {{{1
"------------------------------------------------------------------------------
" vmk, the script object of a bookmark

function! s:VmkCreate(id, file, line, text)
	return {'id': a:id, 'file': a:file, 'line': a:line, 'text': a:text}
endfunction

function! s:VmkGetDummy()
	return s:vmk_dummy
endfunction

function! s:VmkSignPlace(vmk)
	silent! execute 'sign place '
		\ . a:vmk.id
		\ . ' line=' . a:vmk.line
		\ . ' name=vookmark'
		\ . ' file=' . a:vmk.file
endfunction

function! s:VmkSignUnplace(vmk)
	silent! execute 'sign unplace '
		\ . a:vmk.id
		\ . ' file=' . a:vmk.file
endfunction

function! s:VmkSignJump(vmk)
	silent! execute 'sign jump '
		\ . a:vmk.id
		\ . ' file=' . a:vmk.file
endfunction

function! s:VmkPersist(vmk)
	let l:persist='{'
	let l:persist.='"id":'.a:vmk.id.','
	let l:persist.='"file":"'.escape(a:vmk.file, '"\').'",'
	let l:persist.='"line":'.a:vmk.line.','
	let l:persist.='"text":"'.escape(a:vmk.text, '"\').'"'
	let l:persist.='}'
	return l:persist
endfunction

"}}}

" Function: Container 'vmks' Management {{{1
"------------------------------------------------------------------------------
" vmks, the list data structure of vmk

function! s:VmksCreate()
	return []
endfunction

function! s:VmksGetDummy()
	return s:vmks_dummy
endfunction

function! s:VmksAdd(vmks, vmk)
	call add(a:vmks, a:vmk)
endfunction

function! s:VmksRemove(vmks, vmk)
	let l:vmks=filter(copy(a:vmks), 'v:val.id=='.a:vmk.id)
	for vmk in l:vmks
		call s:VmkSignUnplace(vmk)
	endfor
	return filter(a:vmks, 'v:val.id!='.a:vmk.id)
endfunction

function! s:VmksSortingCompareLine(vmk1, vmk2)
	return a:vmk1.line - a:vmk2.line
endfunction

function! s:VmksSortedList(vmks)
	let l:sorted=sort(a:vmks, 's:VmksSortingCompareLine')
	return l:sorted
endfunction

function! s:VmksNextLine(vmks, cursorline)
	let l:lines=map(copy(a:vmks), 'v:val.line')
	let l:nextlines=filter(l:lines, 'v:val>'.a:cursorline)

	if !empty(l:nextlines)
		return min(l:nextlines)
	endif

	if !empty(a:vmks)
		let l:sorted=s:VmksSortedList(a:vmks)
		return l:sorted[0].line
	endif

	return a:cursorline
endfunction

function! s:VmksPrevLine(vmks, cursorline)
	let l:lines=map(copy(a:vmks), 'v:val.line')
	let l:nextlines=filter(l:lines, 'v:val<'.a:cursorline)

	if !empty(l:nextlines)
		return max(l:nextlines)
	endif

	if !empty(a:vmks)
		let l:sorted=s:VmksSortedList(a:vmks)
		return l:sorted[len(l:sorted)-1].line
	endif

	return a:cursorline
endfunction

function! s:VmksFindVmk(vmks, line)
	for vmk in a:vmks
		if vmk.line == a:line
			return vmk
		endif
	endfor
	return s:VmkGetDummy()
endfunction

function! s:VmksPersist(vmks)
	let l:persist='['
	for vmk in a:vmks
		let l:persist.=s:VmkPersist(vmk).','
	endfor
	let l:persist.=']'
	return l:persist
endfunction

"}}}

" Function: Container 'vmksmap' Management {{{1
"------------------------------------------------------------------------------
" vmksmap, the map data structure of vmks; key: filename, obj: vmks

function! s:VmksMapCreate()
	return {}
endfunction

function! s:VmksMapRemoveVmks(vmksmap, file)
	let l:removed=[]
	if s:VmksMapFindVmks(a:vmksmap, a:file) != s:VmksGetDummy()
		let l:vmks=a:vmksmap[a:file]
		for vmk in l:vmks
			call s:VmksRemove(l:vmks, vmk)
			call add(l:removed, vmk)
		endfor
		unlet a:vmksmap[a:file]
	endif
	return l:removed
endfunction

function! s:VmksMapFindVmks(vmksmap, file)
	return get(a:vmksmap, a:file, s:VmksGetDummy())
endfunction

function! s:VmksMapFindVmksOrCreate(vmksmap, file)
	let l:vmks=get(a:vmksmap, a:file, s:VmksGetDummy())

	if l:vmks == s:VmksGetDummy()
		let a:vmksmap[a:file]=s:VmksCreate()
		let l:vmks = a:vmksmap[a:file]
	endif

	return l:vmks
endfunction

function! s:VmksMapPersist(vmksmap)
	let l:persist='{'
	for [file,vmks] in items(a:vmksmap)
		let l:persist.='"'.escape(file, '"\').'":'.s:VmksPersist(vmks).','
	endfor
	let l:persist.='}'
	return l:persist
endfunction

"}}}

" Function: Utilities to handle sign ID in vmksmap and buffer {{{1
"------------------------------------------------------------------------------
" Welcome any possible better implementation here.

function! s:UtilIsSignIdExist(id)
	for [file, vmks] in items(s:vmksmap)
		for vmk in vmks
			if vmk.id == a:id
				return 1
			endif
		endfor
	endfor
	return 0
endfunction

function! s:UtilNextSignId()
	while s:UtilIsSignIdExist(s:seed)
		let s:seed+=1
	endwhile
	return s:seed
endfunction

function! s:UtilFirstBufferSignLineId()
	let l:oldz=@z
	redir @z
	silent! execute 'sign place buffer=' . winbufnr(0)
	let l:signs=@z
	redir END
	let @z=l:oldz

	let g:signs=l:signs
	let l:ids=matchlist(l:signs, '  \+\S\+=\(\d\+\) \+\S\+=\(\d\+\) \+\S\+=vookmark')
	let g:ids=l:ids
	if len(l:ids) > 2
		return [l:ids[1], l:ids[2]]
	else
		return [-1, -1]
	endif
endfunction

function! s:UtilLineFromBufferSignId(id)
	let l:oldz=@z
	redir @z
	silent! execute 'sign place buffer=' . winbufnr(0)
	let l:signs=@z
	redir END
	let @z=l:oldz

	let l:lines=matchlist(l:signs, '  \+\S\+=\(\d\+\) \+\S\+='.a:id.' \+\S\+=vookmark')
	if len(l:lines) > 2
		return l:lines[1]
	else
		return -1
	endif
endfunction

"}}}

" Function: Singleton 'Vookmark' for plugin operations {{{1
"------------------------------------------------------------------------------
" Vookmark, the plugin instance

function! s:VookmarkInit()
	let s:vmk_dummy=s:VmkCreate(0, '', 0, '')
	let s:vmks_dummy=s:VmksCreate()
	let s:seed=1

	let s:vmksmap=s:VmksMapCreate()
endfunction

function! s:VookmarkAddBookmark()
	let l:file=expand("%:p")
	let l:line=line('.')
	let l:text=getline(l:line)

	let l:vmks=s:VmksMapFindVmksOrCreate(s:vmksmap, l:file)
	let l:vmk=s:VmksFindVmk(l:vmks, l:line)

	if l:vmk == s:VmkGetDummy()
		let l:id=s:UtilNextSignId()
		let l:vmk_new=s:VmkCreate(l:id, l:file, l:line, l:text)
		call s:VmkSignPlace(l:vmk_new)
		call s:VmksAdd(l:vmks, l:vmk_new)
	endif
endfunction

function! s:VookmarkRemoveBookmark()
	let l:file=expand("%:p")
	let l:line=line('.')

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:file)

	if l:vmks == s:VmksGetDummy()
		return
	endif

	let l:vmk=s:VmksFindVmk(l:vmks, l:line)

	if l:vmk != s:VmkGetDummy()
		call s:VmksRemove(l:vmks, l:vmk)
	endif
endfunction

function! s:VookmarkToggleBookmark()
	call s:VookmarkCorrectVmks()

	let l:file=expand("%:p")
	let l:line=line('.')

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:file)
	let l:vmk=s:VmksFindVmk(l:vmks, l:line)

	if l:vmk == s:VmkGetDummy()
		call s:VookmarkAddBookmark()
	else
		call s:VookmarkRemoveBookmark()
	endif

	call s:VookmarkRefreshSign()
endfunction

function! s:VookmarkRefreshSign()
	call s:VookmarkCorrectVmks()

	let l:file=expand("%:p")

	let [l:line, l:id]=s:UtilFirstBufferSignLineId()
	while l:id != -1
		let l:vmk=s:VmkCreate(l:id, l:file, 0, '')
		call s:VmkSignUnplace(vmk)
		unlet l:vmk

		let [l:line, l:id]=s:UtilFirstBufferSignLineId()
	endwhile

	for [file, vmks] in items(s:vmksmap)
		for vmk in vmks
			call s:VmkSignPlace(vmk)
		endfor
	endfor
endfunction

function! s:VookmarkMoveToNextBookmark()
	call s:VookmarkCorrectVmks()

	let l:file=expand("%:p")
	let l:line=line('.')

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:file)
	let l:nextline=s:VmksNextLine(l:vmks, l:line)
	execute "normal! ".l:nextline."G"
endfunction

function! s:VookmarkMoveToPrevBookmark()
	call s:VookmarkCorrectVmks()

	let l:file=expand("%:p")
	let l:line=line('.')

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:file)
	let l:prevline=s:VmksPrevLine(l:vmks, l:line)
	execute "normal! ".l:prevline."G"
endfunction

function! s:VookmarkClearInFile()
	let l:file=expand("%:p")

	if !exists('s:undelete_last')
		let s:undelete_last={'file':'', 'list':[]}
	endif

	let l:removed=s:VmksMapRemoveVmks(s:vmksmap, l:file)
	if len(l:removed) == 0 && s:undelete_last.file == l:file
		" if clear nothing, try undo delete
		let l:vmks=s:VmksMapFindVmksOrCreate(s:vmksmap, l:file)
		for vmk in s:undelete_last.list
			let l:id=s:UtilNextSignId()
			let vmk.id = l:id
			call s:VmkSignPlace(vmk)
			call s:VmksAdd(l:vmks, vmk)
		endfor
	endif
	let s:undelete_last={'file':l:file, 'list':l:removed}
endfunction

function! s:VookmarkCorrectVmks()
	let l:file=expand("%:p")
	let l:maxline=line('$')
	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:file)

	let l:vmks=s:VmksSortedList(l:vmks)
	for vmk in l:vmks
		let l:line=s:UtilLineFromBufferSignId(vmk.id)
		if l:line != -1 && l:line != vmk.line
			let vmk.line=l:line
		endif
		if l:line >= l:maxline
			call s:VmkSignUnplace(vmk)
			let vmk.line=l:maxline
			call s:VmkSignPlace(vmk)
		endif
	endfor

	for vmk in copy(l:vmks)
		if exists('l:vmk_prev') && l:vmk_prev.line == vmk.line
			call s:VmksRemove(l:vmks, vmk)
		endif

		let l:vmk_prev=vmk
	endfor
endfunction

function! s:VookmarkSave()
	call s:VookmarkCorrectVmks()
	if len(s:vmksmap) > 0
		let l:vmksmap_persist='let g:__vmksmap__='.s:VmksMapPersist(s:vmksmap)
		let l:seed_persist='let g:__vmkseed__='.s:seed
		call writefile([l:vmksmap_persist,l:seed_persist], g:vookmark_savepath)
	endif
endfunction

autocmd VimLeave * call s:VookmarkSave()

function! s:VookmarkLoad()
	if filereadable(g:vookmark_savepath)
		execute 'source '.g:vookmark_savepath
		if exists('g:__vmksmap__') && exists('g:__vmkseed__')
			let s:vmksmap=g:__vmksmap__
			let s:seed=g:__vmkseed__
			unlet g:__vmksmap__
			unlet g:__vmkseed__
			call s:VookmarkRefreshSign()
		endif
	endif
endfunction

autocmd VimEnter * call s:VookmarkLoad()

autocmd BufReadPost * call s:VookmarkRefreshSign()

"}}}

" Function: Manage bookmark list window {{{1
"------------------------------------------------------------------------------
" VookmarkList functions

function! s:VookmarkList_Exit()
	let l:original_line=b:original_line
	bd!
	execute "normal! ".l:original_line."G"
	normal! zz
endfunction

function! s:VookmarkList_LineNumber()
	if line('.') <= 1
		return -1
	endif

	let l:text=getline(".")
	let l:num=matchstr(l:text, '[0-9]\+')
	if l:num == ''
		return -1
	endif
	return l:num
endfunction

function! s:VookmarkList_Jump()
	let l:jump_line=s:VookmarkList_LineNumber()
	if l:jump_line == -1
		let l:jump_line=b:original_line
	endif
	bd!
	execute "normal! ".l:jump_line."G"
	normal! zz
endfunction

function! s:VookmarkList_UpdatePosition()
	let l:jump_line=s:VookmarkList_LineNumber()
	let l:highlight=1
	if l:jump_line == -1
		let l:jump_line=b:original_line
		let l:highlight=0
	endif
	let l:bookmarklist_bufnr=b:bookmarklist_bufnr
	execute bufwinnr(b:original_bufnr)." wincmd w"
	execute "normal! ".l:jump_line."G"
	if l:highlight == 1
		execute 'match Search /\%'.line(".").'l.*/'
	endif
        normal! zz
	execute bufwinnr(l:bookmarklist_bufnr)." wincmd w"
endfunction

function! s:VookmarkList_CheckPosition()
	if b:selected_line != line(".")
		call s:VookmarkList_UpdatePosition()
		let b:selected_line=line(".")
	endif
endfunction

function! s:VookmarkList_Relocate()
	let l:vmks=s:VmksMapFindVmks(s:vmksmap, b:original_file)
	let l:line=s:VookmarkList_LineNumber()

	if l:line > 0
		" in bookmark list buffer
		let l:original_bufline=line('.')
		let l:vmk=s:VmksFindVmk(l:vmks, l:line)
		let l:bookmarklist_bufnr=b:bookmarklist_bufnr
		execute bufwinnr(b:original_bufnr)." wincmd w"

		" in original file buffer
		call s:VookmarkRemoveBookmark()
		call search(l:vmk.text)
		call s:VookmarkAddBookmark()
		call s:VookmarkRefreshSign()
		execute bufwinnr(l:bookmarklist_bufnr)." wincmd w"

		" in bookmark list buffer
		call s:VookmarkList_Refresh()
		execute "normal! ".l:original_bufline."G"
		call s:VookmarkList_UpdatePosition()
	endif
endfunction

function! s:VookmarkList_Delete()
	let l:line=line('.')
	call s:VookmarkList_Jump()
	call s:VookmarkRemoveBookmark()
	call s:VookmarkList()
	if exists('b:vookmarklist')
		execute "normal! ".l:line."G"
	endif
endfunction

function! s:VookmarkList_Refresh()
	" prepare bookmark list content, in z register
	let l:oldz=@z
	let @z="\" (q)uit (r)elocate (d)elete, '<cr>' to confirm selection.\n"

	let l:original_file=b:original_file
	let l:bookmarklist_bufnr=b:bookmarklist_bufnr
	execute bufwinnr(b:original_bufnr)." wincmd w"
	let l:max=strlen(line('$'))

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:original_file)
	for vmk in l:vmks
		let l:lineno='     '.vmk.line
		let l:text=vmk.text
		let @z.='Ln '.strpart(l:lineno, strlen(l:lineno) - l:max).': '.l:text."\n"
	endfor

	execute bufwinnr(l:bookmarklist_bufnr)." wincmd w"

	" post bookmark list content to buffer
	set noswapfile
	set modifiable
	normal! ggVG
	normal! dd
	normal! "zPGdd
	execute "2,$:sort n"
	normal! gg
	execute "resize ".min([line("$"),12])
	set nomodified
	let @z=l:oldz
endfunction

function! s:VookmarkList()
	call s:VookmarkCorrectVmks()

	let l:original_file=expand("%:p")
	let l:original_bufnr=bufnr('%')
	let l:original_line=line(".")

	let l:vmks=s:VmksMapFindVmks(s:vmksmap, l:original_file)
	if len(l:vmks) == 0
		echo "No bookmarks in this file."
		return
	endif

	" open new bookmark list buffer
	execute 'botright sp -vookmark-'
	let b:vookmarklist=1
	let b:original_file=l:original_file
	let b:original_bufnr=l:original_bufnr
	let b:original_line=l:original_line
	let b:bookmarklist_bufnr=bufnr('%')

	call s:VookmarkList_Refresh()

	" Map buffer exit keys
	nnoremap <buffer> <silent> q :call <sid>VookmarkList_Exit()<cr>
	nnoremap <buffer> <silent> <cr> :call <sid>VookmarkList_Jump()<cr>

	" Map other function keys in bookmark list window
	nnoremap <buffer> <silent> r :call <sid>VookmarkList_Relocate()<cr>
	nnoremap <buffer> <silent> d :call <sid>VookmarkList_Delete()<cr>

	" Setup syntax highlight
	syntax match vookmarkListTitle         /^File:.*$/
	syntax match vookmarkListLineNum       /^Ln\s\+\d\+:/
	syntax match vookmarkListComment       /^".*$/

	highlight def link vookmarkListTitle    Title
	highlight def link vookmarkListLineNum  LineNr
	highlight def link vookmarkListComment  Comment

	" update file position by bookmark
	let b:selected_line = line(".")
	call s:VookmarkList_UpdatePosition()
	autocmd! CursorMoved <buffer> nested call <sid>VookmarkList_CheckPosition()
	autocmd! BufDelete <buffer> nested match none
endfunction

"}}}

" Commands: {{{1
"------------------------------------------------------------------------------

if !exists(':VmkToggle')
	command -nargs=0 VmkToggle :call <sid>VookmarkToggleBookmark()
endif

if !exists(':VmkNext')
	command -nargs=0 VmkNext :call <sid>VookmarkMoveToNextBookmark()
endif

if !exists(':VmkPrev')
	command -nargs=0 VmkPrev :call <sid>VookmarkMoveToPrevBookmark()
endif

if !exists(':VmkClear')
	command -nargs=0 VmkClear :call <sid>VookmarkClearInFile()
endif

if !exists(':VmkSave')
	command -nargs=0 VmkSave :call <sid>VookmarkSave()
endif

if !exists(':VmkLoad')
	command -nargs=0 VmkLoad :call <sid>VookmarkLoad()
endif

if !exists(':VmkList')
	command -nargs=0 VmkList :call <sid>VookmarkList()
endif

if !exists(':VmkRefresh')
	command -nargs=0 VmkRefresh :call <sid>VookmarkRefreshSign()
endif

if !exists(':VmkFactoryReset')
	command -nargs=0 VmkFactoryReset :call <sid>VookmarkInit()|call <sid>VookmarkRefreshSign()
endif

"}}}

" Keymaps: {{{1
"------------------------------------------------------------------------------

if g:vookmark_mapkeys == 1
	nnoremap <silent> mm :VmkToggle<CR>
	nnoremap <silent> mn :VmkNext<CR>
	nnoremap <silent> mp :VmkPrev<CR>
	nnoremap <silent> ma :VmkClear<CR>
	nnoremap <silent> ml :VmkList<CR>
	nnoremap <silent> mr :VmkRefresh<CR>
endif

" }}}

" Module: End of plugin.{{{1
"--------------------------------------------------------------------------

call s:VookmarkInit()

"}}}

" vim:fdm=marker:ff=unix:
