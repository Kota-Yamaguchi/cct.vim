" cct_tmux.vim - Tmux integration functions for cct.vim
" Check if a pane has claude process running
function! cct_tmux#_has_claude_process(pane_pid) abort
  " Method 1: Try pstree (if available)
  if executable('pstree')
    let l:pstree_cmd = 'pstree -p ' . a:pane_pid . ' 2>/dev/null | grep -q claude'
    let l:result = system(l:pstree_cmd)
    if !v:shell_error
      return 1
    endif
  endif
  
  " Method 2: Recursively check child processes using ps
  let l:pids_to_check = [a:pane_pid]
  let l:checked_pids = {}
  
  while !empty(l:pids_to_check)
    let l:current_pid = remove(l:pids_to_check, 0)
    
    " Avoid infinite loops
    if has_key(l:checked_pids, l:current_pid)
      continue
    endif
    let l:checked_pids[l:current_pid] = 1
    
    " Check if current process is claude
    let l:comm_cmd = 'ps -p ' . l:current_pid . ' -o comm= 2>/dev/null'
    let l:comm = system(l:comm_cmd)
    let l:comm = substitute(l:comm, '\n\+$', '', '')
    
    if l:comm =~ 'claude'
      return 1
    endif
    
    " Get child processes
    let l:children_cmd = 'ps -o pid,ppid -ax | awk ''$2 == ' . l:current_pid . ' { print $1 }'''
    let l:children = system(l:children_cmd)
    
    for l:child_pid in split(l:children, '\n')
      if !empty(l:child_pid) && l:child_pid =~ '^\d\+$'
        call add(l:pids_to_check, l:child_pid)
      endif
    endfor
  endwhile
  
  return 0
endfunction

" Check if tmux is running
function! cct_tmux#check_tmux() abort
  if !executable('tmux')
    echoerr 'tmux is not installed'
    return 0
  endif
  
  let l:result = system('tmux has-session 2>/dev/null')
  if v:shell_error
    echoerr 'No tmux session found'
    return 0
  endif
  
  return 1
endfunction

" Verify target pane exists
function! cct_tmux#verify_pane(pane) abort
  " Check if pane ID format is correct
  if a:pane !~ '^%\d\+$'
    echo 'Warning: Pane ID format may be incorrect: ' . a:pane
    echo 'Expected format: %<number> (e.g., %1, %2, etc.)'
  endif
  
  let l:cmd = 'tmux list-panes -s -F "#{pane_id}" | grep -q "^' . a:pane . '$"'
  let l:result = system(l:cmd)
  return !v:shell_error
endfunction

" Auto-detect Claude Code pane
function! cct_tmux#auto_detect_pane() abort
  if !cct_tmux#check_tmux()
    return ''
  endif
  
  " Get current pane ID to exclude it from detection
  let l:current_pane = system('tmux display-message -p "#{pane_id}"')
  let l:current_pane = substitute(l:current_pane, '\n\+$', '', '')
  
  " Get all panes in current session with their PIDs
  let l:cmd = 'tmux list-panes -s -F "#{pane_id}:#{pane_pid}"'
  let l:pane_list = system(l:cmd)
  
  if v:shell_error
    return ''
  endif
  
  " Check each pane for claude process using pstree
  for l:line in split(l:pane_list, '\n')
    if empty(l:line)
      continue
    endif
    
    let l:parts = split(l:line, ':')
    if len(l:parts) < 2
      continue
    endif
    
    let l:pane_id = l:parts[0]
    let l:pane_pid = l:parts[1]
    
    " Skip current pane (where Vim is running)
    if l:pane_id == l:current_pane
      continue
    endif
    
    " Check if claude is running in this pane
    if cct_tmux#_has_claude_process(l:pane_pid)
      let l:current_session = system('tmux display-message -p "#{session_name}"')
      let l:current_session = substitute(l:current_session, '\n\+$', '', '')
      echo 'Found claude process in pane ' . l:pane_id . ' (PID: ' . l:pane_pid . ') in session ' . l:current_session
      return l:pane_id
    endif
  endfor
  
  " Fallback: look for panes with 'claude' in the command name (current session only)
  let l:cmd = 'tmux list-panes -s -F "#{pane_id}:#{pane_current_command}" | grep -i claude | head -1 | cut -d: -f1'
  let l:pane_id = system(l:cmd)
  let l:pane_id = substitute(l:pane_id, '\n\+$', '', '')
  
  if !empty(l:pane_id)
    return l:pane_id
  endif
  
  " Final fallback: look for Python processes that might be Claude Code (current session only)
  let l:cmd = 'tmux list-panes -s -F "#{pane_id}:#{pane_current_command}" | grep -E "python|Python" | head -1 | cut -d: -f1'
  let l:pane_id = system(l:cmd)
  let l:pane_id = substitute(l:pane_id, '\n\+$', '', '')
  
  return l:pane_id
endfunction

" Start Claude Code in a new pane
function! cct_tmux#start_claude() abort
  if !cct_tmux#check_tmux()
    return ''
  endif
  
  echo "Starting Claude Code in a new pane..."
  
  " Get current pane for reference
  let l:current_pane = system('tmux display-message -p "#{pane_id}"')
  let l:current_pane = substitute(l:current_pane, '\n\+$', '', '')
  
  " Split pane and start Claude Code
  let l:split_dir = exists('g:claude_code_split_direction') ? g:claude_code_split_direction : 'h'
  let l:split_size = exists('g:claude_code_split_size') ? g:claude_code_split_size : '40%'
  
  " Parse split size - use -l for percentage, -p for numeric
  let l:size_option = '-l'
  let l:size_value = l:split_size
  if l:split_size =~ '^\d\+$'
    let l:size_option = '-p'
  endif
  
  " Create new pane
  let l:cmd = 'tmux split-window -' . l:split_dir . ' ' . l:size_option . ' ' . l:size_value . ' -P -F "#{pane_id}"'
  let l:new_pane = system(l:cmd)
  let l:new_pane = substitute(l:new_pane, '\n\+$', '', '')
  
  if v:shell_error || empty(l:new_pane)
    echoerr 'Failed to create new pane'
    return ''
  endif
  
  " Start Claude Code in the new pane
  let l:claude_cmd = exists('g:claude_code_command') ? g:claude_code_command : 'claude code'
  call system('tmux send-keys -t ' . l:new_pane . ' ' . shellescape(l:claude_cmd) . ' C-m')
  
  " Return focus to the original pane
  call system('tmux select-pane -t ' . l:current_pane)
  
  " Give Claude Code time to start
  sleep 2
  
  " Send Enter to show prompt
  call system('tmux send-keys -t ' . l:new_pane . ' C-m')
  
  echo 'Claude Code started in pane ' . l:new_pane
  return l:new_pane
endfunction


" Send text to Claude Code
function! cct_tmux#send_text(text) abort
  if !cct_tmux#check_tmux()
    return
  endif
  
  " Prevent rapid successive calls
  if exists('s:last_send_time') && (localtime() - s:last_send_time) < 1
    echohl WarningMsg | echo 'Ignoring duplicate send (too soon after last send)' | echohl None
    return
  endif
  let s:last_send_time = localtime()
  
  if empty(a:text)
    echohl WarningMsg | echo 'Nothing to send (empty text)' | echohl None
    return
  endif
  
  " Auto-detect if no pane is set or pane doesn't exist
  if !exists('g:claude_code_pane') || empty(g:claude_code_pane) || !cct_tmux#verify_pane(g:claude_code_pane)
    let l:detected = cct_tmux#auto_detect_pane()
    if !empty(l:detected)
      let g:claude_code_pane = l:detected
      echo 'Auto-detected Claude Code at ' . g:claude_code_pane
    else
      echoerr 'No Claude Code pane found. Use :ClaudeCodeFindPanes or :ClaudeCodeConnect'
      return
    endif
  endif
  
  " Add prefix if enabled
  let l:text_to_send = a:text
  if exists('g:claude_code_prefix') && !empty(g:claude_code_prefix)
    let l:text_to_send = g:claude_code_prefix . "\n" . a:text
  endif
  
  " Get current pane for verification
  let l:current_pane = system('tmux display-message -p "#{pane_id}"')
  let l:current_pane = substitute(l:current_pane, '\n\+$', '', '')
  
  " Check if we're trying to send to the same pane
  if l:current_pane == g:claude_code_pane
    echoerr 'ERROR: Target pane is the same as current pane! This would send to Vim itself.'
    echoerr 'Please run :ClaudeCodeFindPanes to find the correct Claude pane.'
    return
  endif
  
  " Verify the target pane still exists
  if !cct_tmux#verify_pane(g:claude_code_pane)
    echoerr 'Target pane ' . g:claude_code_pane . ' no longer exists!'
    return
  endif
  
  " Send the text
  let l:cmd = 'tmux send-keys -t ' . g:claude_code_pane . ' ' . shellescape(l:text_to_send)
  let l:result = system(l:cmd)
  
  if v:shell_error
    echoerr 'Failed to send text to ' . g:claude_code_pane . ': ' . l:result
    return
  endif
  
  " Small delay to ensure text is processed
  sleep 100m
  
  " Then send Enter separately
  let l:enter_cmd = 'tmux send-keys -t ' . g:claude_code_pane . ' Enter'
  let l:enter_result = system(l:enter_cmd)
  
  if v:shell_error
    echoerr 'Failed to send Enter to ' . g:claude_code_pane . ': ' . l:enter_result
  else
    echo 'Sent to ' . g:claude_code_pane . '!'
  endif
endfunction
