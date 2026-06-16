---
name: readable-md
description: "Markdown を「人が読みやすく、かつ機械が HTML/スライドへ変換しやすい」構造に執筆・整形する。新規に調査/設計 md を書くときや、既存 md を昇華 (md→HTML→slide) の前に整えるときに使う。「読みやすい md にして」「昇華しやすく整形して」「調査 md を書いて」で起動。"
user_invocable: true
argument_hint: "<target-md-path | topic> [--check-only]"
origin: ai-research-pipeline/deep-research/readable-markdown-to-html-slide-presentation-2026
---

# readable-md スキル

md→HTML→slide パイプラインの **Stage 1**。「読みやすい md = 機械が変換しやすい md」
という等式に基づき、md を**人にとって読みやすく・後段の変換 (HTML/スライド) が
壊れない構造**に揃える。

## 基本原則

> **読みやすい md は、そのまま TOC 自動生成・スライド分割・アクセシビリティを成立させる。**
> 人向けの可読性ルールと、機械向けの変換しやすさは同じもの。

- **md = Source of Truth (正)**。HTML / slide / PDF は再生成可能な派生物。内容修正は常に md 側。
- 構造を**規則的・予測可能**に保つ。例外的なレイアウトは後段の変換を壊す。
- 体裁ではなく**構造**を直す。色やフォントは後段 (テーマ asset) の仕事。

## いつ使うか

| 状況 | 動作 |
|------|------|
| `<topic>` を渡された (パスでない) | テンプレ (`templates/research-skeleton.md`) を骨子に新規執筆 |
| 既存 `<path>.md` を渡された | 構造を解析し、原則に沿って**整形リファクタ** (内容は保つ) |
| `--check-only` | 執筆/整形せず、`scripts/check-readable-md.sh` の結果だけ報告 |

## 実行手順

### 1. 入力の判別

- 引数がファイルパス → 既存 md の整形モード。まず Read する。
- 引数がトピック文字列 → 新規執筆モード。`templates/research-skeleton.md` を骨子に使う。
- 引数なし → 対象をユーザーに確認。

### 2. 構造原則の適用

執筆/整形時に次の 12 原則を満たす (起点レポート §A-1):

| # | 原則 | 対応ルール |
|---|------|-----------|
| 1 | H1 は 1 文書に 1 つ (タイトル) | MD025 |
| 2 | 見出しを飛ばさない (H2→H4 禁止) | MD001 |
| 3 | ATX 見出し (`#`) を使う | MD003 |
| 4 | 1 セクション 1 主題 / 1 スライド 1 メッセージ | — |
| 5 | 箇条書きは 3〜5 項目・1 項目 15 語以内 (目安) | — |
| 6 | コードフェンスに言語指定 (` ```lang `) | MD040 |
| 7 | 要素を適材適所 (§A-2) | — |
| 8 | frontmatter で title/date/tags を構造化 | — |
| 9 | 画像に alt、リンクは意味のある語に | MD045/MD042 |
| 10 | 1 文 1 行 or 段落空行区切り (git diff が読みやすい) | — |
| 11 | markdownlint で機械強制 | — |
| 12 | 規則的・予測可能なパターン (= 機械可読性) | — |

#### 要素の使い分け (§A-2)

| 内容の性質 | 使う要素 |
|-----------|---------|
| 並列・列挙 | 箇条書き `-` |
| 手順・順序あり | 番号付き `1.` |
| 属性 × 対象の比較 | 表 `\|` |
| 連続した説明・論理 | 段落 |
| コマンド・コード | フェンスドコードブロック (言語指定) |
| 注意・補足・引用 | `>` blockquote |
| 構造図・フロー | コードブロック内 ASCII or Mermaid |

### 3. frontmatter を必ず付ける

```yaml
---
title: "<タイトル>"
date: 2026-06-13
tags: [research]
---
```

`title` / `date` は後段の変換 (HTML の `<title>`、slide のヘッダ) が流用する。

### 4. 機械検証 (drift gate)

整形後、必ず構造チェッカを通す:

```bash
./scripts/check-readable-md.sh <path>.md
# markdownlint も併せて掛けるなら (npx 取得あり):
./scripts/check-readable-md.sh --lint <path>.md
```

error が出たら直してから完了とする。チェッカは次を機械検証する:
H1 単一 / 見出し非スキップ / コードフェンス言語指定 / frontmatter title・date /
未閉鎖フェンス / インライン `style=` (warn)。

### 5. 完了報告

```text
readable-md で整形しました:
  対象: <path>.md
  チェック: ✓ error 0 / warn N
  次段: /md-to-html <path>.md でHTML化、または Marp で slide 化
```

## チェックリスト (§F-4 「昇華しやすい md か」)

- [ ] frontmatter に title/date/tags があるか
- [ ] H1 1 つ・見出しを飛ばしていないか
- [ ] セクションが 1 主題で、そのままスライド 1 枚に要約できる粒度か
- [ ] コードフェンスに言語指定があるか
- [ ] 図は Mermaid か ASCII (CJK 崩れに注意) で再生成可能か
- [ ] テーマ/CSS が本文でなく後段の asset 側にあるか
- [ ] check-readable-md.sh (+ markdownlint) が通るか
- [ ] 派生物 (html/slide/pdf) を手編集していないか (md 側でのみ修正)

## 注意事項

- **内容を勝手に足さない**: 整形モードでは構造だけ直す。事実・主張の追加は別途確認。
- **体裁を md に書かない**: 色/フォント/余白は後段テーマの仕事。`style=` 等を md に持ち込まない。
- **「3〜5 / 15 語」は目安**: 経験則のガイドライン (blog 由来)。厳密な制約ではない。
- **由来**: 親リポ `ai-research-pipeline` の deep-research レポート
  `readable-markdown-to-html-slide-presentation-2026` の §A / §F を実装。
