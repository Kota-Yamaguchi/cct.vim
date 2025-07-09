# cct.vim

Vim から tmux ペインの Claude Code にテキストを送信するプラグイン

## 必要な依存関係

- tmux
- Claude Code
- pstree

```zsh
# tmux と pstree をインストール
brew install tmux pstree
```

## インストール

```vim
" vim-plug
Plug 'Kota-Yamaguchi/cct.vim'

" Vundle
Plugin 'Kota-Yamaguchi/cct.vim'
```

## 基本的な使い方

1. tmux セッション内で Vim を起動
2. `:ClaudeCodeConnect`で Claude Code に接続
   - Claude Code が起動していない場合は自動で起動
   - すでに起動している場合は自動で検出
3. Vim でコードや質問を書く
4. `<Space>cc`で送信

## キーマッピング

| キー        | モード        | 説明                  |
| ----------- | ------------- | --------------------- |
| `<Space>cc` | Normal/Visual | 現在行/選択範囲を送信 |
| `<Space>cp` | Normal/Visual | プロンプト付きで送信  |
| `<Space>ca` | Normal        | AutoSendMode 切り替え |
| `<Space>cA` | Normal        | AutoSendMode 状態確認 |

## AutoSendMode

Enter キーを押した時に現在行を自動送信する機能

- `<Space>ca`で有効/無効を切り替え
- カーソルが 2 秒以上滞在した行のみ送信対象
- 空行や重複は自動的にスキップ
