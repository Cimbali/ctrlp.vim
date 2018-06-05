" =============================================================================
" File:          autoload/ctrlp/tag.vim
" Description:   Tag file extension
" Author:        Kien Nguyen <github.com/kien>
" =============================================================================

" Init {{{1
if exists('g:loaded_ctrlp_tag') && g:loaded_ctrlp_tag
	fini
en
let g:loaded_ctrlp_tag = 1

cal add(g:ctrlp_ext_vars, {
	\ 'init': 'ctrlp#tag#init()',
	\ 'accept': 'ctrlp#tag#accept',
	\ 'lname': 'tags',
	\ 'sname': 'tag',
	\ 'enter': 'ctrlp#tag#enter()',
	\ 'type': 'tabs',
	\ })

let s:id = g:ctrlp_builtins + len(g:ctrlp_ext_vars)
" Utilities {{{1
fu! s:findcount(tag, file, addr)
	" get potential tags (with current file to match :tselect ordering), number them
	let list = map(taglist('^' . escape(a:tag, '^$.*~\') . '$', expand('%:p')), 'extend(v:val, {"id": v:key + 1})')

	if len(list) == 1
		retu list[0].id
	endi

	" filter by filename
	let find_fname = escape(fnamemodify(simplify(a:file), ':s?^\(\.\.[/\\]\)*??'), '^$.*~\') . '$'
	let fnm = filter(copy(list), 'fnamemodify(v:val["filename"], ":p") =~ "'.find_fname.'"')
	if len(fnm) == 1
		retu fnm[0].id
	endi

	" re-filter by cmd
	let cmd = filter(copy(fnm), 'v:val["cmd"] == "'.a:addr.'"'})
	if len(cmd) == 1
		retu cmd[0].id
	endi

	" sometimes commands are ill-formed, e.g. space before/between ;" or non-tab
	" separated fields: filter by cmd prefix (see #92)
	let pfx = filter(copy(fnm), {key, val -> 'v:val["cmd"] =~ "^'.escape(a:addr, '^$.*~"\').'\(\s*;\s*".*\)\?$"'})
	if len(pfx) == 1
		retu pfx[0].id
	endi

	" NB in the usual case we do not get beyond here. If 2+ tags have the
	" same file & cmd, then only optional fields (kind etc.) can differentiate
	" them but they will both match to the first occurence of cmd when using :ta.
	"
	" Alternately, 2+ tags have the same command and different filenames, both
	" having a:file as suffix. This can probably only be solved using absolute
	" paths in the CtrlPTag() display.
	"
	" Finally we might have a mismatch in file/cmd, but that should not happen (?)
	if len(cmd) > 1
		let same = filter(copy(cmd), 'v:val["filename"] == cmd[0].filename && v:val["cmd"] == cmd[0].cmd')
		if len(same) > 1
			let v:warningmsg=len(same).' undistinguishable tags: '.string({'filename': cmd[0].filename, 'cmd':cmd[0].cmd})
			echom v:warningmsg
			retu 0
		endi
	endi

	" failed to find a candidate, try again with current file
	let fnm = filter(copy(list), 'fnamemodify(v:val["filename"], ":p") == "'.expand('%:p').'"')
	if len(fnm) == 1
		retu fnm[0].id
	endi

	let cmd = filter(fnm, 'v:val["cmd"] == "'.a:addr.'"'})
	if len(cmd) == 1
		retu cmd[0].id
	endi

	" no cmd matches in any filtered files, so try non-matching files (?)
	let cmd = filter(list, 'v:val["cmd"] == "'.a:addr.'"'})
	if len(cmd) == 1
		retu cmd[0].id
	endi

	retu 0
endf

fu! s:filter(tags)
	let nr = 0
	wh 0 < 1
		if a:tags == [] | brea | en
		if a:tags[nr] =~ '^!' && a:tags[nr] !~# '^!_TAG_'
			let nr += 1
			con
		en
		if a:tags[nr] =~# '^!_TAG_' && len(a:tags) > nr
			cal remove(a:tags, nr)
		el
			brea
		en
	endw
	retu a:tags
endf

fu! s:formattag(line, tagdir)
	" parse string
	let [tag, filename; command] = split(a:line, "\t")
	retu join([tag, fnamemodify((filename[0] != '/' ? a:tagdir . '/' : '') . filename, ':p:~:.')] + command, "\t")
endf

fu! s:syntax()
	if !ctrlp#nosy()
		cal ctrlp#hicheck('CtrlPTagComment',  'Comment')
		cal ctrlp#hicheck('CtrlPTagName',     'Identifier')
		cal ctrlp#hicheck('CtrlPTagPath',     'PreProc')
		cal ctrlp#hicheck('CtrlPTagDir',      'PreProc')
		cal ctrlp#hicheck('CtrlPTagLine',     'Identifier')
		cal ctrlp#hicheck('CtrlPTagSlash',    'Conceal')
		cal ctrlp#hicheck('CtrlPTagKind',     'Special')
		cal ctrlp#hicheck('CtrlPTagField',    'Constant')
		cal ctrlp#hicheck('CtrlPTagContent',  'Statement')

		sy match  CtrlPTagPrompt               '^>'        nextgroup=CtrlPTagName
		sy match  CtrlPTagName                 '\s[^\t]\+'ms=s+1        nextgroup=CtrlPTagPath
		sy match  CtrlPTagPath       skipwhite '\t[^\t]\+'ms=s+1        nextgroup=CtrlPTagLine,CtrlPTagFind contains=CtrlPTagDir
		sy match  CtrlPTagDir        contained '/\?\([^/\\\t]\+[/\\]\)*'
		sy match  CtrlPTagLine       contained '\t\d\+'ms=s+1           nextgroup=CtrlPTagComment
		sy region CtrlPTagFind       concealends matchgroup=Ignore start='\t/^\?'ms=s+1 skip='\(\\\\\)*\\/' end='\$\?/'
		                                                              \ nextgroup=CtrlPTagComment contains=CtrlPTagSlash
		sy match  CtrlPTagSlash      contained '\\[/\\^$]'he=s+1 conceal
		sy region CtrlPTagComment    concealends matchgroup=Ignore oneline start=';"' excludenl end='$'
		                                                              \ contains=CtrlPTagKind,CtrlPTagField
		sy match  CtrlPTagKind       contained '\t[a-zA-Z]\>'ms=s+1
		sy match  CtrlPTagField      contained '\t[a-z]*:[^\t]*'ms=s+1  contains=CtrlPTagContent
		sy match  CtrlPTagContent    contained ':[^\t]*'ms=s+1
	en
endf
" Public {{{1
fu! ctrlp#tag#init()
	if empty(s:tagfiles) | retu [] | en
	let g:ctrlp_alltags = []
	let tagfiles = sort(filter(s:tagfiles, 'count(s:tagfiles, v:val) == 1'))
	for each in tagfiles
		let alltags = s:filter(ctrlp#utils#readfile(each))
		let dir = &tr ? fnamemodify(each, ':p:h') : getcwd()
		cal extend(g:ctrlp_alltags, map(alltags, 's:formattag(v:val, "'.dir.'")'))
	endfo
	cal s:syntax()
	retu g:ctrlp_alltags
endf

fu! ctrlp#tag#accept(mode, str)
	cal ctrlp#exit()
	" parse string
	let tagend = stridx(a:str, "\t")
	let fileend = stridx(a:str, "\t", tagend + 1)
	let addrend = match(a:str, ';"\(\t\|$\)', fileend + 1)
	let tag = a:str[:tagend - 1]
	let file = a:str[tagend + 1:fileend - 1]
	let addr = a:str[fileend + 1:addrend - 1]

	" find tag in list to call :[count]tag
	let candidate = s:findcount(tag, file, addr)

	" Don't abandon changes (see also tag-!)
	if a:mode == 'e' && ctrlp#modfilecond(!&aw)
		let a:mode = 'h'
	endi

	" Open target window/buffer according to mode.
	" lhs splits then we call :tag, rhs does tjump
	let cmd = {
		\ 't': ctrlp#tabcount() . 'tab sp',
		\ 'h': 'sp',
		\ 'v': 'vs',
		\ 'e': '',
		\ }[a:mode]

	" Go to the tag found with the filtering, if any
	if candidate > 0
		if cmd != ''
			exe cmd
		en

		let save_cst = &cst
		set nocst
		try
			exe candidate.'ta '.tag
		cat
			" Sometimes, the taglist() returns tags that none of :ta :tj :ts can find
			" (even though this typically indicates the tag file is out of date)
			let candidate = 0
		fina
			let &cst = save_cst
		endt
	en

	if candidate <= 0
		" Fall back to just opening the file and going to the line as specified by
		" the tag that we found. Does not add the tag to the taglist, so mark context.
		mark '
		exe (cmd != '' ? cmd : 'e').' '.file
		san addr
	en

	" unfold + center
	cal feedkeys('zvzz', 'nt')
	cal ctrlp#setlcdir()
endf

fu! ctrlp#tag#id()
	retu s:id
endf

fu! ctrlp#tag#enter()
	let tfs = get(g:, 'ctrlp_custom_tag_files', tagfiles())
	let s:tagfiles = type(tfs) == 3 && tfs != [] ? filter(map(tfs, 'fnamemodify(v:val, ":p")'),
		\ 'filereadable(v:val)') : []
endf
"}}}

" vim:fen:fdm=marker:fmr={{{,}}}:fdl=0:fdc=1:ts=2:sw=2:sts=2
