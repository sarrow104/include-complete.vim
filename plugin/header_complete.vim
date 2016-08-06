if globpath(&rtp, 'autoload/youcompleteme.vim') != ""
" just append autocmd,not redefined
au FileType c,cpp
	    \ command! -nargs=0	ToggleCF	call header_complete#ToggleWithYCM()
endif

autocmd FileType c,cpp
            \ command! -nargs=1 -complete=dir ICaddDirForLocal        call header_complete#addDirForLocal(<q-args>)
