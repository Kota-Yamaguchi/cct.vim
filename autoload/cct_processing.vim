" cct_processing.vim - Processing functions for cct.vim
" Send current line
function! cct_processing#send_line() abort
  let l:line = getline('.')
  if empty(l:line)
    echohl WarningMsg | echo 'Nothing to send (empty line)' | echohl None
    return
  endif
  
  echo 'Sending current line...'
  call cct_tmux#send_text(l:line)
endfunction

" Send current line with prompt
function! cct_processing#send_line_with_prompt() abort
  let l:line = getline('.')
  if empty(l:line)
    echohl WarningMsg | echo 'Nothing to send (empty line)' | echohl None
    return
  endif
  
  " Get prompt from user
  let l:prompt = input('プロンプト: ')
  if empty(l:prompt)
    echo 'キャンセルされました'
    return
  endif
  
  " Combine prompt and line
  let l:text_to_send = l:prompt . "\n\n" . l:line
  
  echo 'Sending current line with prompt...'
  call cct_tmux#send_text(l:text_to_send)
endfunction


" Send visual selection (safer implementation)
function! cct_processing#send_visual_selection() abort
  " Use a more reliable method to get visual selection
  let l:save_reg = @@
  let l:save_regtype = getregtype('"')
  
  " Yank the visual selection
  normal! gvy
  let l:text = @@
  
  " Restore register
  call setreg('"', l:save_reg, l:save_regtype)
  
  if empty(l:text)
    echohl WarningMsg | echo 'Nothing to send (empty selection)' | echohl None
    return
  endif
  
  echo 'Sending visual selection...'
  call cct_tmux#send_text(l:text)
endfunction

" Send visual selection with prompt
function! cct_processing#send_visual_selection_with_prompt() abort
  " Use a more reliable method to get visual selection
  let l:save_reg = @@
  let l:save_regtype = getregtype('"')
  
  " Yank the visual selection
  normal! gvy
  let l:text = @@
  
  " Restore register
  call setreg('"', l:save_reg, l:save_regtype)
  
  if empty(l:text)
    echohl WarningMsg | echo 'Nothing to send (empty selection)' | echohl None
    return
  endif
  
  " Get prompt from user
  let l:prompt = input('プロンプト: ')
  if empty(l:prompt)
    echo 'キャンセルされました'
    return
  endif
  
  " Combine prompt and selection
  let l:text_to_send = l:prompt . "\n\n" . l:text
  
  echo 'Sending visual selection with prompt...'
  call cct_tmux#send_text(l:text_to_send)
endfunction
