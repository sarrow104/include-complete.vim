if globpath(&rtp, 'autoload/youcompleteme.vim') != ""
" just append autocmd,not redefined
au FileType c,cpp
	    \ command! -nargs=0	ToggleCF	call header_complete#ToggleWithYCM()
endif
