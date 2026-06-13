---
name: md-to-slide
description: "調査/レポート md を発表スライド (Marp) に昇華する。report.md を要約・分割して slides.md を作り、HTML/PDF/PPTX に書き出す。「スライドにして」「発表資料を作って」「Marp で」で起動。文書とスライドは編集距離があるため別ファイル (slides.md) として作る。"
user_invocable: true
argument_hint: "<report-md-path> [-o <slides.md>] [--build]"
origin: ai-research-pipeline/deep-research/readable-markdown-to-html-slide-presentation-2026 (§D/§E/§F)
---

# md-to-slide スキル (Stage 3)

md→HTML→slide パイプラインの **Stage 3**。調査/レポート md (正) を**発表スライド**へ昇華する。
既定ツールは **Marp**（純 Markdown 寄り・最速配布・HTML/PDF/PPTX 出力）。

## 基本原則

> **文書 md とスライド md は「編集距離」がある。銀の弾丸はない。**
> 情報密度が違う（文書=高 / スライド=1 画面 1 論点）。そのまま変換せず、
> **要約 → 1 メッセージ/スライドに分割**して `slides.md` を別ファイルで作るのが推奨。

- `report.md` (正) は触らない。スライドは派生の `slides.md` として新規作成する。
- `slides.md` も「読みやすい md」原則に従う（Stage 1 の構造原則がそのまま効く）。
- ビルド (`slides.md` → HTML/PDF/PPTX) は決定論スクリプト `scripts/build-slides.sh` が担う。

## スライド md の作法 (Marp)

- **`---` でスライド分割**。各スライドの先頭 `##` がスライドタイトル。
- **1 スライド 1 メッセージ**。「20 枚のきれい > 10 枚の詰め込み」。
- 箇条書きは **3〜5・各 15 語以内**（目安）。文ではなくキーワード。
- frontmatter に `marp: true` / `theme` / `paginate` / `header` を置く。
- **スピーカーノート**は `<!-- ノート -->` コメント（presenter UI に表示、配布 PDF では非表示）。
- 図表が要るなら Mermaid / 表は最小限に。1 スライド 1 図。

## 実行手順

### 1. 入力の判別

- 引数が `report.md` パス → Read して内容を把握。
- 出力 `slides.md` は既定で同ディレクトリの `<name>.slides.md`（`-o` で変更）。

### 2. report.md → slides.md (要約・分割)

report の各セクションを**スライド 1 枚に要約**する。目安の構成:

| スライド | 内容 |
|---------|------|
| 表紙 | タイトル + 発表者/日付（`#` 見出し 1 枚） |
| 結論 | Executive Summary を 3〜5 箇条書きに圧縮（最初に結論） |
| 背景/問い | なぜ・何を |
| 本論 (複数) | report の各 `##` を 1〜2 枚に。表は列を絞る |
| まとめ | 結論再掲 + 次アクション |

`templates/slides-marp.md` を骨子に使ってよい。**内容を盛らない**——要約であって
新情報の追加ではない。判断に迷う圧縮はユーザーに確認する。

### 3. ビルド (決定論)

```bash
./scripts/build-slides.sh <slides.md>            # HTML (既定・chromium 不要)
./scripts/build-slides.sh <slides.md> --pdf      # PDF も (要 chromium)
./scripts/build-slides.sh <slides.md> --pptx     # PPTX も (要 chromium)
./scripts/build-slides.sh <slides.md> --all      # HTML+PDF+PPTX
```

marp-cli を npx で実行する。PDF/PPTX は内部でブラウザ (chromium) を使うため、
未導入環境では HTML のみ成功する（スクリプトがその旨を報告する）。

### 4. 完了報告

```text
md-to-slide で発表資料を作成しました:
  正:     report.md
  派生:   report.slides.md  (要約・分割)
  ビルド: dist/report.slides.html  (+ --pdf/--pptx で PDF/PPTX)
```

## ツール選択 (既定は Marp。用途で替える)

| やりたいこと | 推奨 |
|------------|------|
| CI で slide+PDF を自動生成・最速配布 | **Marp** (既定) |
| リッチ/インタラクティブ発表 (live code) | Slidev |
| 自由度最大・既存 HTML 資産活用 | reveal.js |
| 文書もスライドも 1 ツールで | Pandoc / Quarto |

本バンドルは Marp を実装。他ツールが要る場合は `slides.md` をそのまま
`pandoc -t revealjs` 等に渡せる（md 構造が素直なら流用しやすい）。

## 発表 → 配布の二面性

- 発表用 = インタラクティブ HTML（presenter notes・段階表示）。
- 配布用 = PDF（ノートは非表示、段階表示は展開済み）。
- 同じ `slides.md` から両方出る（`build-slides.sh --all`）。

## 注意事項

- **report.md は触らない**。スライドは常に派生の `slides.md` 側で作る。
- **盛らない**。スライド化は要約。新しい主張を足さない。
- **1 スライド 1 メッセージ**。詰め込んだら分割する。
- **PDF/PPTX は要 chromium**。無ければ HTML で代替し、その旨を報告（無理に入れない）。
- **由来**: deep-research レポート `readable-markdown-to-html-slide-presentation-2026`
  の §D（スライド実践）/§E（ツール比較）/§F（昇華ワークフロー）を実装。
