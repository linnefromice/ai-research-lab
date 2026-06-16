---
name: md-to-html
description: "Markdown を共通テーマの HTML（画面ダーク / 印刷は A4 ライトテーマ）に変換する。「HTML 化して」「HTML 版を作って」「PDF にしたい」で起動。調査/設計/レポート md の配布・印刷用途に。素早く出すなら scripts/render-html.sh、リッチな card/box レイアウトが要るときは LLM 整形。"
user_invocable: true
argument_hint: "<markdown-file-path> [--rich] [--sync]"
origin: ai-research-pipeline/.claude/skills/md-to-html (PR #506)
---

# md-to-html スキル (Stage 2)

md→HTML→slide パイプラインの **Stage 2**。md (正) を共通テーマの HTML (派生) に変換する。
画面表示はダークテーマ、印刷 (PDF 化) 時は A4 ライトテーマに自動で切り替わる。

前段の [readable-md (Stage 1)](../../../readable-md/) で構造を整えた md を入力に想定する
（H1 単一・見出し非スキップ・frontmatter 付き）。

## 基本原則

### MD が正 (Source of Truth)

```text
*.md (正)  →  変換  →  *.html (派生)
  ↓ 修正                    ↓ 再生成
*.md (更新) →  変換  →  *.html (更新)
```

- 内容修正は **常に MD 側**。HTML は派生表示用で、HTML だけの手修正はしない（同期が壊れる）。
- 出力先は既定で **MD と同じディレクトリの同名 `.html`**。

### スタイルは asset が唯一の正

CSS/デザイントークンは [`assets/report-theme-head.html`](../../assets/report-theme-head.html) に集約。
HTML 生成時はこの `<style>` ブロックを **逐語コピーして `<head>` に挿入**する。
SKILL.md 本文や生成 HTML に独自 CSS を散らさない（ドリフト防止）。テーマ変更は asset 側だけ編集。

## 2 つの変換パス

| パス | 使う場面 | 手段 |
|------|---------|------|
| **決定論パス (既定)** | CI 自動生成・素早く出す・素の md 構造で十分 | `scripts/render-html.sh`（markdown-it + theme） |
| **リッチパス (`--rich`)** | card-grid / 強調ボックス / フロー図で魅せたい | LLM が md を解析し bespoke HTML を生成 |

### 決定論パス

```bash
./scripts/render-html.sh <input.md>                 # 同名 .html を出力
./scripts/render-html.sh <input.md> -o out.html     # 出力先指定
```

frontmatter を除去し title を `<title>` に流用、本文を markdown-it で HTML 化して theme を
注入する。生 HTML はエスケープされる（コードブロック内 `<script>` 等が表示を壊さない）。
LLM 不要なので CI に置ける（§F-3）。

### リッチパス (`--rich`) — LLM が整形

MD の構造を解析し、HTML コンポーネントへマッピングする:

| MD 要素 | HTML コンポーネント |
|---------|-------------------|
| `# タイトル` | `<h1>` + `.subtitle` |
| `## セクション` | `<h2>` + セクション区切り |
| `### サブセクション` | `<h3>` |
| `> 引用` / `> **注意:**` | `.highlight-box` / `.warn-box` / `.risk-box` / `.ok-box`（内容で判別） |
| テーブル | `<table>`（必要なら `.card` 内） |
| 箇条書き | `<ul>` / `<ol>` |
| `---` (区切り線) | `.divider` |
| frontmatter / 冒頭メタ | `.subtitle` に統合（YAML は表示しない） |
| コードブロック（フロー図） | `.vflow` フロー図 or `<pre>` |

**HTML エスケープ必須**: MD 本文の `<` `>` `&` は `&lt;` `&gt;` `&amp;` に。
**標準コンポーネント**: `.card` / `.card-grid` / `.card-sm` / `.tag-*` / `.highlight-box` /
`.warn-box` / `.risk-box` / `.ok-box` / `.vflow` / `.note` / `.divider`。
判断が要る場合（表をカードグリッドにするか等）はユーザーに確認する。

#### リッチパスのテンプレート構造

```html
<!DOCTYPE html>
<html lang="ja">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>{{タイトル}}</title>
<!-- assets/report-theme-head.html の <style> をここに逐語挿入 -->
</head>
<body>
<div class="container">
  <h1>{{タイトル}}</h1>
  <p class="subtitle">{{サブタイトル・メタ情報}}</p>
  <!-- セクション群 -->
  <div class="note">{{フッターノート}}</div>
</div>
</body>
</html>
```

## `--sync` の挙動

既存 HTML があるとき:

- `--sync` なし: 既存 HTML を読み、MD との差分箇所のみ更新。
- `--sync` あり: 差分検出せず MD から全面再生成（手で壊れた HTML をリセットしたいとき）。

## 品質チェック

1. **MD との内容一致**: セクション数・テーブル行数・箇条書き項目数が一致するか。
2. **`<style>` の同一性**: asset の `<style>` がそのまま入っているか（改変していないか）。
3. **インラインスタイル禁止**: `style="..."` を使わない（印刷時に上書きできず壊れる）。CSS クラスを使う。

## PDF 化

### GUI 環境
ブラウザで HTML を開き `Cmd+P` / `Ctrl+P` →「PDF として保存」。A4 1 ページに収まるか・
カードの途中改ページがないかをプレビューで確認。

### headless 環境 (CI / WSL2)

```bash
# chromium (印刷 CSS @media print を最も忠実に再現・JS 実行で Mermaid/KaTeX 可)
chromium --headless --no-sandbox --print-to-pdf=out.pdf --no-pdf-header-footer report.html

# weasyprint (Python・Paged Media 強い・JS 不要)
weasyprint report.html out.pdf
```

いずれも未インストールなら無理に `apt install` せず、その旨を報告して GUI 印刷を促す。
日本語は `fonts-noto-cjk`（Noto Sans CJK JP）が必要。font-family は
Hiragino → Noto Sans JP → Noto Sans CJK JP の順で fallback。

## 注意事項

- **インラインスタイルを避ける**: `style="..."` は印刷で壊れる。CSS クラスを使う。
- **スタイルの単一 source**: CSS は `assets/report-theme-head.html` のみが正。
- **生成 HTML はスタンドアロン配布物**: 公開サイトの SSG パイプライン等とは別系統。
  git にコミットするかはプロジェクト判断（派生物なので原則 CI 生成 / 手編集禁止）。
- **由来**: 親リポ `ai-research-pipeline` の `md-to-html` スキル (PR #506) を移植・汎用化。
  リポ固有のパス前提を外し、決定論パス (`render-html.sh`) を追加した。
