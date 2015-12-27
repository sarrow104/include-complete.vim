"==================================================
" File:         include_complete.vim
" Brief:        include file name complete.
" Author:       Sarrow
" Last Change:  2008十二月11
" Version:      0.6
"
" Install:      Unzip or Unrar all files to plugin directory.
"
" Usage:
" 		#include <\<C-X>\<C-U>
" User Defined:
" 		.\include_complete\include.ini
"
" 		3rd party library include directory entry file
" 		modify it to satisfy your need.
"
if !exists('s:path_sep')
    let s:path_sep = '/'
endif

if !exists('g:IncludeHeaderForest')
    function! s:Get_IncludeHeaderForest()
        " NOTE: 关于规则的数目 {{{1
        " 'base'表示某库的头文件目录入口路径
        "       若用环境变量表示，将自动展开
        " 'exclude': ['**2/readme.txt']
        " 这表示忽略的列表。第一级的"**2"表示文件处于二级目录中。
        " 另：单个的星号表示第一级子目录
        "     双星号表示任意级别的子目录
        " 'max_depth'表示相对base的最大探索深度。
	" 	0：仅当前include根目录，即不再包括文件夹
	" 	1：可以搜索第一层子目录中的文件，但不包括子目录中的文件夹
	" 	n：按上，以此类推
        "
        " 'suffix'表示后缀情况，允许的值为no_ext，c，cpp以及它们的组合
	" 	用|分割即可，比如
	" 	suffix = no_ext | cpp
	" 	表示允许无后缀和c++风格头文件后缀
        " }}}1
	let ini_file = readfile(globpath(&rtp, 'plugin/include_complete/include.ini'))

	let extension_dict = {
		    \'no_ext': [''],
		    \'h': ['h', 'H' ],
		    \'hpp': ['hpp', 'HPP']}
	let tree = {}
	let status = ''

        let out = []
	for line in ini_file
	    if line == '' || line =~ '^;'
		" 空行或者注释行
		continue
	    endif

	    let pattern = '^\[\zs.*\ze\]$'
	    if line =~ pattern
		if tree != {}
		    " echohl WarningMsg
		    " 	echomsg string(tree)
		    " echohl none
		    call add(out, tree)
		    let tree = {}
		endif
		let tree['base'] = expand(matchstr(line, pattern))
		let tree['root'] = {}
		let status = '[]'
		continue
	    endif

	    let pattern = '^exclude=$'
	    if line =~ pattern
		let tree['exclude'] = {}
		let status = 'exclude'
		continue
	    endif

	    if status == 'exclude'
		let pattern = '^\([^=:]\+\)\%(:\(\d\+\|any\)\)\=$'
		if line =~ pattern
		    let key = substitute(line, pattern, '\1', '')
		    let val = substitute(line, pattern, '\2', '')
		    if val == ''
			let val = 0
		    endif
		    let tree['exclude'][key]=val
		    " no change status
		    continue
		endif
	    endif

	    " 'suffix=hpp|h' =~ '^suffix=\zs\(no_ext\|h\|hpp\||\)\+$'
	    let pattern = '^suffix=\zs\(no_ext\|h\|hpp\||\)\+$'
	    if line =~ pattern
		let status = ''
		let suffix = matchstr(line, pattern)
		let suffixs = split(suffix, '|')
		if suffixs == []
		    let suffixs = ['h', 'hpp', 'H', 'HPP']
		endif
		let usr_exts = []
		for suffix in suffixs
		    let usr_exts += extension_dict[suffix]
		endfor
		let tree['extension_pattern'] = '^\c\('.join(usr_exts, '\|').'\)$'
		continue
	    endif

	    let pattern = '^max_depth=\zs\d\+$'
	    if line =~ pattern
		let status = ''
		let tree['max_depth'] = matchstr(line, pattern)
		continue
	    endif

	endfor

	if tree != {}
	    " echohl WarningMsg
	    "     echomsg string(tree)
	    " echohl none
	    call add(out, tree)
	    let tree = {}
	endif
	" {{{1
        " call add(out, {
        "             \'base': $MINGW_INC,
        "             \'root': {},
        "             \'exclude': { "c++": 0, 'tags': 'any' },
	" 	    \'extension_pattern': '^\(\|h\)$',
        "             \'max_depth': 3})
        " call add(out, {
        "             \'base': $MINGW_INC.'\c++\3.4.5',
        "             \'root': {},
        "             \'exclude': {'tags': 'any' },
	" 	    \'extension_pattern': '^\(\)$',
        "             \'suffix': 'no_ext',
        "             \'max_depth': 0})
	" call add(out, {
	" 	    \'base': $BOOST_INC,
	" 	    \'root': {},
	" 	    \'exclude': {'tags': 'any' },
	" 	    \'extension_pattern': '^\(hpp\)$',
	" 	    \'max_depth': 5})
        " call add(out, {
        "             \'base': $SSS_INC,
        "             \'root': {},
        "             \'exclude': {'readme.txt': 2 },
	" 	    \'extension_pattern': '^\(h\|hpp\)$',
        "             \'max_depth': 2})
        "             "'exclude': ['**2/readme.txt'],
	"}}}1
        return out
    endfunction
    let g:IncludeHeaderForest = s:Get_IncludeHeaderForest()
endif

" 根据paths:List<String>，返回匹配的头文件列表
function! s:Get_Matched_HeaderFiles(paths)
    " 数据是保存在一个‘森林’: List<Dict>里面。
    " 森林由一个List管理，其中的每一株树由一个Dict来表示
    " 每棵树的根部需要保存额外的信息，如base:String，表示
    " 该树表示的目录的根结点的绝对目录地址。（或者说，外部文件提供的rule就可以保存于此）
    " 为了避免‘自定义的键值’和‘库目录文件名’发生撞车事件，该树的
    " 实际分支信息，保存于其内部的'value'（或root,tree,head）键值下面。该键值下面直接保存‘base’目录
    " 下的‘直系’入口结点——如文件夹、头文件等。文件夹与文件的区别就是前者多在后面缀上了
    " 一个目录分隔符（/或者\），其名字就是键名，如果是文件夹，其对应的键值就是该文件夹下的
    " 目录列表；若是文件，则即为叶子节点。
    let stem = extend(['root'], a:paths[0:-2])
    let leaf_pat = '^' . escape(a:paths[-1], '.')
    " echohl WarningMsg
    "     echomsg 'stem:'.string(stem)
    "     echomsg 'leaf_pat:'.leaf_pat
    " echohl none

    " Matched-Header，匹配的头文件/路径列表
    " 即，最后的返回值
    let match_list = []

    for tree in g:IncludeHeaderForest

	" 当前查找深度cur_depth
	let cur_depth = 0
	" 控制循环用
        let has_find = 1
	" 利用Dict的引用机制
        let Sub_tree = tree

	" 本循环至少进去一次
        for node in stem
	    " echohl WarningMsg
	    "     echomsg 'loop node > '.node
	    " echohl none
	    if Sub_tree == {}
                call s:Create_sub_node(Sub_tree, tree, stem, cur_depth)
	    endif
	    if !has_key(Sub_tree, node) || s:Is_leaf_node(Sub_tree, node)
		" echohl WarningMsg
		"     echomsg 'quit loop at node > '.node
		" echohl none
                let has_find = 0
		break
	    endif
            let Sub_tree = Sub_tree[node]
            let cur_depth += 1
	endfor

        if !has_find
	    " 当前header树中没有找到匹配
	    " ，继续看下一棵树
            continue
        endif

        if Sub_tree == {}
            call s:Create_sub_node(Sub_tree, tree, stem, cur_depth)
        endif

        let pre_path = len(stem) > 1 ? join(stem[1:-1], s:path_sep) . s:path_sep : ''
        for node in sort(keys(Sub_tree))
            if node =~ leaf_pat
                call add(match_list, pre_path . node . (s:Is_leaf_node(Sub_tree, node)? "" : s:path_sep))
            endif
        endfor

	" echohl WarningMsg
	"     echomsg string(tree['root'])
	" echohl none

    endfor " for tree in g:IncludeHeaderForest

    return match_list

endfunction

function! s:Is_leaf_node(Sub_tree, node)
    return type(a:Sub_tree[a:node]) == type(0)
endfunction

function! s:Create_sub_node(notes, tree, stem, cur_depth)
    let srh_path = join([a:tree['base']] + a:stem[1 : a:cur_depth], s:path_sep)
    " echoerr 'search under :'.srh_path
    let paths = split(globpath(srh_path, '*'), "\n")
    if a:tree['max_depth'] < a:cur_depth
	call filter(paths, 'isdirectory(v:val) == 0')
    endif
    for path in paths
	let exclude_this = 0
	let note = fnamemodify(path, ":t")
	if has_key(a:tree['exclude'], note) &&
		    \(a:tree['exclude'][note] == 'any'  ||
		    \ a:tree['exclude'][note] == a:cur_depth - 1)
	    let exclude_this = 1
	endif
	if !isdirectory(path)
	    let extension = fnamemodify(note, ":e")
	    if extension !~ a:tree['extension_pattern']
		let exclude_this = 1
	    endif
	endif
	if !exclude_this
	    let a:notes[note] = (isdirectory(path)?{}:0)
	endif
    endfor
endfunction

" Complete:
" #include <\<C-x>\<C-u>
" Author: Sarrow
" Date: 2008 Nov 30
function! CompleteIncludedHeaderFile(findstart, base)
    if a:findstart
        let start_col = col('.') - 1

	if start_col <= 1
	    return -1
	endif

        let line = getline('.')[:start_col-1]
        let pattern = '^#\s*include\s*<\zs\%(\w\+[\\/]\)*\%(\w\+\%(\.\w*\)\=\)\=$'
        if line !~ pattern
            return -1
        else
            let paths_already = matchstr(line, pattern)
            let b:paths = split(paths_already, '/\|\', 1)
            " echoerr 'b:paths = '.string(b:paths)
            return start_col - strlen(paths_already)
        endif
    else
	if exists("b:paths")
	    let paths = b:paths
	    unlet b:paths
	    return s:Get_Matched_HeaderFiles(paths)
	else
	    return []
	endif
    endif
endfunction

setlocal completefunc=CompleteIncludedHeaderFile

