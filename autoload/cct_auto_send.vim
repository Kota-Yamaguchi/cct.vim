" cct_auto_send.vim - AutoSend mode functions for cct.vim
" This file handles automatic sending of lines as the cursor moves

" AutoSend mode state
let s:auto_send_mode = 0
let s:last_sent_line = 0
let s:last_sent_content = ''

" Timer-related variables (kept for compatibility)
let s:timer_id = 0

" Line tracking variables
let s:line_times = {}  " Dictionary to track time spent on each line
let s:current_line = 0
let s:line_start_time = 0
let s:min_dwell_time = 1  " Minimum seconds to qualify for sending

" Get AutoSend mode status
function! cct_auto_send#is_enabled() abort
  return s:auto_send_mode
endfunction

" Enable AutoSend mode
function! cct_auto_send#enable() abort
  if s:auto_send_mode
    echo 'AutoSendMode は既に有効です'
    return
  endif
  
  let s:auto_send_mode = 1
  let s:last_sent_line = 0
  let s:last_sent_content = ''
  
  " Reset timer variables
  call cct_auto_send#cancel_timer()
  
  " Set up Enter key mapping and cursor tracking for AutoSend
  augroup ClaudeCodeAutoSend
    autocmd!
    autocmd BufEnter * call cct_auto_send#setup_enter_mapping()
    autocmd CursorMoved,CursorMovedI * call cct_auto_send#track_cursor_movement()
  augroup END
  
  " Set up the Enter key mapping immediately for current buffer
  call cct_auto_send#setup_enter_mapping()
  
  " Initialize cursor tracking
  call cct_auto_send#init_cursor_tracking()
  
  echo 'AutoSendMode が有効になりました'
endfunction

" Disable AutoSend mode
function! cct_auto_send#disable() abort
  if !s:auto_send_mode
    echo 'AutoSendMode は既に無効です'
    return
  endif
  
  let s:auto_send_mode = 0
  let s:last_sent_line = 0
  let s:last_sent_content = ''
  
  " Reset timer variables and cancel timer
  call cct_auto_send#cancel_timer()
  
  " Clear line tracking data
  call cct_auto_send#clear_line_tracking()
  
  " Remove autocmd and restore Enter key mapping
  augroup ClaudeCodeAutoSend
    autocmd!
  augroup END
  
  " Restore original Enter key mapping
  call cct_auto_send#restore_enter_mapping()
  
  echo 'AutoSendMode が無効になりました'
endfunction

" Toggle AutoSend mode
function! cct_auto_send#toggle() abort
  if s:auto_send_mode
    call cct_auto_send#disable()
  else
    call cct_auto_send#enable()
  endif
endfunction

" Handle Enter key press
function! cct_auto_send#handle_enter() abort
  if !s:auto_send_mode
    " Execute normal Enter behavior
    return "\<CR>"
  endif
  
  let l:current_line = line('.')
  let l:line_content = getline(l:current_line)
  
  " Skip empty lines
  if empty(trim(l:line_content))
    return "\<CR>"
  endif
  
  " Skip if same line as last sent
  if l:current_line == s:last_sent_line
    return "\<CR>"
  endif
  
  " Skip if content is the same as last sent (avoid duplicate sends)
  if l:line_content == s:last_sent_content
    return "\<CR>"
  endif
  
  " Cancel any existing timer
  call cct_auto_send#cancel_timer()
  
  " Check if current line qualifies for sending 
  let l:line_time = cct_auto_send#get_line_time(l:current_line)
  if !cct_auto_send#line_qualifies_for_sending(l:current_line)
    echom 'AutoSend: 行 ' . l:current_line . ' は送信対象外（滞在時間: ' . l:line_time . 's / 必要: ' . s:min_dwell_time . 's）'
    return "\<CR>"
  endif
  
  " Send immediately
  call cct_auto_send#send_line_auto(l:current_line, l:line_content)
  
  " Update tracking variables
  let s:last_sent_line = l:current_line
  let s:last_sent_content = l:line_content
  
  " Show feedback
  echom 'AutoSend: 送信完了 (' . expand('%:p') . ':' . l:current_line . ')'
  
  " Execute normal Enter behavior
  return "\<CR>"
endfunction

" Send line with AutoSend-specific prompt
function! cct_auto_send#send_line_auto(line_num, line_content) abort
  let l:filepath = expand('%:p')
  if empty(l:filepath)
    let l:filepath = '[無題]'
  endif
  
  " Create AutoSend prompt
  let l:prompt = cct_auto_send#create_auto_send_prompt(l:filepath, a:line_content)
  
  " Send with the prompt
  call cct_tmux#send_text(l:prompt)
  
  " Show minimal feedback
  echom 'AutoSend: ' . l:filepath . ':' . a:line_num
endfunction

" Create AutoSend-specific prompt
function! cct_auto_send#create_auto_send_prompt(filepath, line_content) abort
  " Always respond in Japanese
  let l:prompt = "# Mob Programming Session\n\n"
  let l:prompt .= "**Always Japanese**: Please respond in Japanese only.\n\n"
  
  " Context section with file path and content
  let l:prompt .= "<context>\n"
  let l:prompt .= "**File Path**: " . a:filepath . "\n\n"
  
  " Add file content if file exists and is readable
  if filereadable(a:filepath)
    try
      let l:file_lines = readfile(a:filepath)
      let l:prompt .= "**File Content**:\n"
      let l:prompt .= "```\n"
      let l:prompt .= join(l:file_lines, "\n")
      let l:prompt .= "\n```\n"
    catch
      let l:prompt .= "**File Content**: (Read error)\n"
    endtry
  else
    let l:prompt .= "**File Content**: (File not found)\n"
  endif
  let l:prompt .= "</context>\n\n"
  
  " Instructions
  let l:prompt .= "## Instructions\n"
  let l:prompt .= "We are in a mob programming session. About the following added line:\n"
  let l:prompt .= "- If it's a question, please answer concisely\n"
  let l:prompt .= "- If it's code, please comment concisely\n"
  let l:prompt .= "- Keep your response as short as possible\n\n"
  
  " Target line
  let l:prompt .= "**Target Line**: `" . a:line_content . "`"
  
  return l:prompt
endfunction

" Get status string for statusline
function! cct_auto_send#get_status() abort
  if s:auto_send_mode
    return '[AutoSend]'
  else
    return ''
  endif
endfunction

" Timer callback function (kept for compatibility)
function! cct_auto_send#timer_callback(timer_id) abort
  " Reset timer ID
  let s:timer_id = 0
endfunction

" Cancel current timer
function! cct_auto_send#cancel_timer() abort
  if s:timer_id > 0
    call timer_stop(s:timer_id)
    let s:timer_id = 0
  endif
endfunction


" Get timer status (kept for compatibility)
function! cct_auto_send#get_timer_status() abort
  return '即座送信モード'
endfunction

" Store original Enter mapping
let s:original_enter_mapping = ''

" Setup Enter key mapping for AutoSend
function! cct_auto_send#setup_enter_mapping() abort
  if !s:auto_send_mode
    return
  endif
  
  " Store original mapping if not already stored
  if empty(s:original_enter_mapping)
    let s:original_enter_mapping = maparg('<CR>', 'i', 0, 1)
  endif
  
  " Set up AutoSend Enter mapping
  inoremap <expr> <CR> cct_auto_send#handle_enter()
endfunction

" Restore original Enter key mapping
function! cct_auto_send#restore_enter_mapping() abort
  " Remove AutoSend mapping
  silent! iunmap <CR>
  
  " Restore original mapping if it existed
  if !empty(s:original_enter_mapping)
    if s:original_enter_mapping.expr
      execute printf('inoremap <expr> %s %s', s:original_enter_mapping.lhs, s:original_enter_mapping.rhs)
    else
      execute printf('inoremap %s %s', s:original_enter_mapping.lhs, s:original_enter_mapping.rhs)
    endif
  endif
  
  " Clear stored mapping
  let s:original_enter_mapping = ''
endfunction

" Initialize cursor tracking
function! cct_auto_send#init_cursor_tracking() abort
  let s:line_times = {}
  let s:current_line = line('.')
  let s:line_start_time = localtime()
endfunction

" Clear line tracking data
function! cct_auto_send#clear_line_tracking() abort
  let s:line_times = {}
  let s:current_line = 0
  let s:line_start_time = 0
endfunction

" Track cursor movement and accumulate time spent on each line
function! cct_auto_send#track_cursor_movement() abort
  if !s:auto_send_mode
    return
  endif
  
  let l:new_line = line('.')
  let l:current_time = localtime()
  
  " If we moved to a different line, record time spent on previous line
  if s:current_line != 0 && s:current_line != l:new_line && s:line_start_time != 0
    let l:time_spent = l:current_time - s:line_start_time
    
    " Only add positive time (avoid clock issues)
    if l:time_spent > 0
      " Add to existing time for this line
      if has_key(s:line_times, s:current_line)
        let s:line_times[s:current_line] += l:time_spent
      else
        let s:line_times[s:current_line] = l:time_spent
      endif
      
    endif
  endif
  
  " Update current line tracking
  let s:current_line = l:new_line
  let s:line_start_time = l:current_time
endfunction

" Check if a line qualifies for sending
function! cct_auto_send#line_qualifies_for_sending(line_num) abort
  " Update current line time before checking
  call cct_auto_send#update_current_line_time()
  
  " Check if line has accumulated enough time
  let l:total_time = get(s:line_times, a:line_num, 0)
  
  return l:total_time >= s:min_dwell_time
endfunction

" Update time for current line
function! cct_auto_send#update_current_line_time() abort
  if s:current_line != 0 && s:line_start_time != 0
    let l:current_time = localtime()
    let l:time_spent = l:current_time - s:line_start_time
    
    " Only add positive time (avoid clock issues)
    if l:time_spent > 0
      if has_key(s:line_times, s:current_line)
        let s:line_times[s:current_line] += l:time_spent
      else
        let s:line_times[s:current_line] = l:time_spent
      endif
      
    endif
    
    " Reset start time for continued tracking
    let s:line_start_time = l:current_time
  endif
endfunction


" Get specific line time
function! cct_auto_send#get_line_time(line_num) abort
  call cct_auto_send#update_current_line_time()
  return get(s:line_times, a:line_num, 0)
endfunction

" Set minimum dwell time
function! cct_auto_send#set_min_dwell_time(seconds) abort
  let s:min_dwell_time = a:seconds
  echo 'AutoSend minimum dwell time set to ' . a:seconds . ' seconds'
endfunction

" Get minimum dwell time
function! cct_auto_send#get_min_dwell_time() abort
  return s:min_dwell_time
endfunction

" Reset tracking variables (useful for debugging)
function! cct_auto_send#reset() abort
  let s:last_sent_line = 0
  let s:last_sent_content = ''
  call cct_auto_send#cancel_timer()
  call cct_auto_send#clear_line_tracking()
  echo 'AutoSend tracking variables reset'
endfunction 