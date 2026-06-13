# md-to-html — 持ち込み可能な「md→HTML」バンドル (Stage 2)

md→HTML→slide パイプラインの **Stage 2**。md (正) を共通テーマの HTML (派生) に変換する。
画面はダークテーマ、印刷 (PDF) は A4 ライトテーマに自動切替。**どのプロジェクトにも
持ち込める**自己完結バンドル。

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/reports/readable-markdown-to-html-slide-presentation-2026.md` (§C md→HTML 実践)
- 移植元: 親リポ `ai-research-pipeline` の `md-to-html` スキル (PR #506)

> 親リポ (private) のパスは隣接 clone 前提。GitHub の public 読者は辿れない
> (lab のパス規約 — ルート [CLAUDE.md](../../../CLAUDE.md) 参照)。

## 目的

Stage 1 で整えた読みやすい md を、**1 ソース (md = 正) のまま配布・印刷できる HTML**へ
昇華する。LLM なしで CI 自動生成できる決定論パスと、魅せるためのリッチパスの 2 系統を持つ。

## 中身

```text
md-to-html/
├── README.md                       このファイル
├── install.sh                      任意プロジェクトへ冪等コピー
├── assets/report-theme-head.html   共通テーマ <style> (CSS の唯一の正)
├── skill/md-to-html/SKILL.md       LLM スキル: リッチな bespoke HTML を生成
└── scripts/render-html.sh          決定論レンダラ: markdown-it + theme で素早く HTML 化
```

## 2 つの変換パス

| パス | 使う場面 | 手段 | LLM |
|------|---------|------|-----|
| **決定論 (既定)** | CI 自動生成・素早く出す・素の md 構造で十分 | `render-html.sh` | 不要 |
| **リッチ (`--rich`)** | card-grid / 強調ボックス / フロー図で魅せたい | `/md-to-html ... --rich` | 要 |

どちらも CSS は `assets/report-theme-head.html` が唯一の正。テーマ変更は asset 側だけ編集。

## 実行方法

### 決定論レンダラ (node のみ)

```bash
# md → 同名 .html (テーマ付きスタンドアロン)
./scripts/render-html.sh path/to/report.md

# 出力先を指定
./scripts/render-html.sh path/to/report.md -o dist/report.html
```

frontmatter を除去し title を `<title>` に流用、本文を markdown-it で HTML 化して theme を
注入する。生 HTML はエスケープ（コードブロック内 `<script>` 等が表示を壊さない）。

### リッチパス (Claude)

```bash
/md-to-html path/to/report.md --rich
```

LLM が md を解析し、`.card` / `.highlight-box` / `.vflow` 等で bespoke HTML を組む。

### 任意プロジェクトに持ち込む

```bash
./install.sh --dry-run /path/to/target-project   # 確認
./install.sh /path/to/target-project             # 実行 (theme は既存なら skip)
```

コピー先: `.claude/skills/md-to-html/SKILL.md` / `tools/md-to-html/render-html.sh` /
`tools/md-to-html/report-theme-head.html`。

## PDF 化 (任意)

```bash
# chromium (印刷 CSS 忠実・JS 実行可)
chromium --headless --no-sandbox --print-to-pdf=report.pdf report.html
# weasyprint (JS 不要・Paged Media 強い)
weasyprint report.html report.pdf
```

日本語は `fonts-noto-cjk` が必要。未インストールなら GUI 印刷 (`Ctrl+P` → PDF) で代替。

## 結果メモ

- 決定論レンダラを Stage 1 テンプレ + 親リポの 481 行レポートで検証。後者は 42KB の
  テーマ付き HTML を生成 (table 11 / h2 8 / code 8)、frontmatter 非表示・`<script>`
  エスケープを確認。
- **bash 5.2 の罠**: `${var//pat/repl}` の replacement 内 `&` は「マッチ文字列」扱いに
  なり HTML エスケープが壊れた。`<title>` のエスケープは `sed` で実装 (移植性も上)。
- markdown-it CLI はテーブル既定 ON・`html:false` 既定で生 HTML をエスケープするため、
  本パイプラインの「HTML エスケープ」原則とそのまま整合。
- chromium/weasyprint/pandoc は本環境に未導入。PDF 化は手順提示に留めた (無理に入れない)。

## このバンドルの位置づけ

全体ロードマップは [親 README](../README.md)。Stage 1 ([readable-md](../readable-md/)) で
md を整え、本 Stage 2 で HTML へ、Stage 3 (未着手) で slide へ昇華する。
