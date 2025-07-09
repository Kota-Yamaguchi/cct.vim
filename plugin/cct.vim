" cct.vim - Send text from Vim to Claude Code via tmux

" Set space as leader key for Claude Code
if !exists('g:claude_code_leader')
  let g:claude_code_leader = ' '
endif

" Helper function to start Claude Code
function! s:start_claude() abort
  let l:pane = cct_tmux#start_claude()
  if !empty(l:pane)
    let g:claude_code_pane = l:pane
  endif
endfunction

" Helper function to auto-detect or start Claude Code
function! s:auto_detect_or_start() abort
  " First try to auto-detect existing Claude Code pane
  let l:pane = cct_tmux#auto_detect_pane()
  if !empty(l:pane)
    let g:claude_code_pane = l:pane
    echo 'Claude Code pane detected and set to: ' . g:claude_code_pane
    return
  endif
  
  " If not found, start Claude Code
  echo 'No Claude Code pane found. Starting Claude Code...'
  let l:pane = cct_tmux#start_claude()
  if !empty(l:pane)
    let g:claude_code_pane = l:pane
    echo 'Claude Code started and set to: ' . g:claude_code_pane
  else
    echoerr 'Failed to start Claude Code'
  endif
endfunction

" Commands
command! ClaudeCodeConnect call s:auto_detect_or_start()

" AutoSend mode commands
command! ClaudeCodeAutoSendToggle call cct_auto_send#toggle()
command! ClaudeCodeAutoSendStatus echo 'AutoSendMode: ' . (cct_auto_send#is_enabled() ? '有効' : '無効') . ' | ' . cct_auto_send#get_timer_status() . ' | 最小滞在時間: ' . cct_auto_send#get_min_dwell_time() . 's'

" Default mappings
if !exists('g:claude_code_no_mappings')
  " Send current line or visual selection
  execute 'nnoremap <silent> ' . g:claude_code_leader . 'cc :call cct_processing#send_line()<CR>'
  execute 'xnoremap <silent> ' . g:claude_code_leader . 'cc :<C-u>call cct_processing#send_visual_selection()<CR>'
  
  " Send current line or visual selection with prompt
  execute 'nnoremap <silent> ' . g:claude_code_leader . 'cp :call cct_processing#send_line_with_prompt()<CR>'
  execute 'xnoremap <silent> ' . g:claude_code_leader . 'cp :<C-u>call cct_processing#send_visual_selection_with_prompt()<CR>'
  
  " AutoSend mode mappings
  execute 'nnoremap <silent> ' . g:claude_code_leader . 'ca :ClaudeCodeAutoSendToggle<CR>'
  execute 'nnoremap <silent> ' . g:claude_code_leader . 'cA :ClaudeCodeAutoSendStatus<CR>'
endif
