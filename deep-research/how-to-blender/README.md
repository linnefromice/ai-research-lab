# how-to-blender

## 起点

- 素材: [Blender Guru のショートカット集](https://www.blenderguru.com/)
- 元ファイル: [`BlenderShortcuts.md`](./BlenderShortcuts.md) (Blender Guru 提供の原文を和訳ベースで整理したもの)

## 目的

Mac 上で Blender を使う際の実用的なショートカット参照資料を、使用キーボードごとに整備する。
あわせてショートカット内で登場する概念・用語の補足資料を作成し、初学者がキーの意味を理解しながら使えるようにする。

## ファイル一覧

| ファイル | 内容 |
|---|---|
| [`BlenderShortcuts.md`](./BlenderShortcuts.md) | 原文 (英語ベース、Blender Guru 準拠) |
| [`BlenderShortcuts_Mac_G913TKL_JIS.md`](./BlenderShortcuts_Mac_G913TKL_JIS.md) | Mac × Logicool G913 TKL (JIS) 向け日本語版 |
| [`BlenderShortcuts_Mac_G913TKL_JIS.html`](./BlenderShortcuts_Mac_G913TKL_JIS.html) | 上記の印刷用 HTML (A4 / 2 カラム) |
| [`BlenderShortcuts_Mac_US.md`](./BlenderShortcuts_Mac_US.md) | Mac × 内蔵 US キーボード向け日本語版 |
| [`BlenderShortcuts_Mac_US.html`](./BlenderShortcuts_Mac_US.html) | 上記の印刷用 HTML (A4 / 2 カラム) |
| [`BlenderGlossary.md`](./BlenderGlossary.md) | 用語集 / 補足資料 (全概念・機能名を日本語解説) |
| [`BlenderGlossary.html`](./BlenderGlossary.html) | 上記の印刷用 HTML (A4 / 2 カラム) |

## 各 Markdown / HTML の使い方

### ショートカット集 (Mac × JIS / US)

手元のキーボードに合ったファイルを参照する。

- **Markdown 版** — テキスト検索・コピー用
- **HTML 版** — ブラウザで開いて `Ctrl+P` → A4 印刷すると 2 カラムの参照カードになる

#### Mac × Logicool G913 TKL (JIS) での注意点

- **Emulate Numpad** を有効にすること (Edit > Preferences > Input)
- **View Pie Menu** (`~`) と **Fly Mode** (`Shift+~`) は JIS キーボードにキーが存在しないため要リマップ
  - Edit > Preferences > Keymap で `^` キーなどに割り当てる
- `[` / `]` キーは `「」` キーと同キーコードで動作する

#### Mac × 内蔵 US キーボードでの注意点

- **Emulate Numpad** を有効にすること
- F1–F12 がデフォルトでメディアキーになっているため、System Settings で変更するか `fn` を併用する
- `Ctrl+Space` は macOS の入力ソース切替と競合するため要確認

### 用語集 (BlenderGlossary)

ショートカット集に登場する概念・用語の意味がわからないときに参照する。
カテゴリ別 (インターフェース / モード / 変換 / モデリングツール / アニメーション / リギング / レンダリング など) に整理されている。

## 実行方法

追加のセットアップ・スクリプトは不要。HTML ファイルをブラウザで開くだけで動作する。

```bash
# 例: macOS でデフォルトブラウザを開く
open deep-research/how-to-blender/BlenderShortcuts_Mac_G913TKL_JIS.html
open deep-research/how-to-blender/BlenderShortcuts_Mac_US.html
open deep-research/how-to-blender/BlenderGlossary.html
```

## 結果メモ

- JIS キーボードは `~` キーが存在しないため、View Pie Menu / Fly Mode は初回に Keymap 再設定が必要
- Emulate Numpad 有効化後も Numpad `.` と `/` はデフォルトマッピングが存在しないので手動設定が必要
- HTML の `<kbd>` スタイリング + 印刷 CSS 2 カラムレイアウトで A4 1〜2 枚に収まる参照カードを作れることを確認
