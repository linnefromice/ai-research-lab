# readable-md-pipeline — md を正として HTML / スライドへ昇華する汎用パイプライン

「**人が読みやすい md** を Source of Truth とし、そこから **HTML / スライド / PDF** を
再生成可能な派生物として昇華する」ワークフローを、**任意プロジェクトに持ち込める
スキルセット + パイプライン**として段階的に組む PoC。

## 起点

- レポート: `../../../ai-research-pipeline/features/deep-research/reports/readable-markdown-to-html-slide-presentation-2026.md` (PR #507)
- 先行: 親リポ `md-to-html` スキル (PR #506) — md→共通ダークテーマ HTML / 印刷 A4 PDF

> 起点レポートは親リポ `ai-research-pipeline` (private) 内。相対パスは隣接 clone 前提
> (lab のパス規約 — ルート [CLAUDE.md](../../CLAUDE.md) 参照)。

## 目的

レポートの核心「**読みやすい md = 機械が変換しやすい md**」「md = 正、派生は再生成可能」を、
読んで終わりにせず**動く道具**に落とす。1 本の調査 md が、レポート (HTML/PDF) と
発表資料 (slide) へ同時に昇華する状態を、どのリポでも再現できるようにする。

## ロードマップ (3 Stage)

| Stage | 担当 | 中身 | 状態 |
|-------|------|------|------|
| **Stage 1** | 読みやすい md を作る | スキル `readable-md` + markdownlint drift gate + 構造チェッカ + 骨子テンプレ | ✅ **構築済** ([readable-md/](./readable-md/)) |
| Stage 2 | md → HTML | 親リポ `md-to-html` スキル相当 (共通ダークテーマ / 印刷 A4 / headless PDF) を移植・汎用化 | 余白 (未着手) |
| Stage 3 | md → slide | Marp 中心に `slides.md` 生成 + HTML/PDF/PPTX 出力。reveal/Pandoc は選択肢 | 余白 (未着手) |

各 Stage は「1 本通る」ことを確認してから次へ進む。Stage 間は **md = 正** の一点で
繋がっており、内容修正は常に md 側でのみ行う。

```text
[ research.md ]  ← 唯一の正 (Source of Truth)
      |
      | Stage 1: readable-md (執筆/整形 + drift gate)
      v
[ 読みやすい md ] --(機械検証 OK)-->
      |
      +--- Stage 2: md → report.html / report.pdf
      |
      +--- Stage 3: md → slides.html / slides.pdf / slides.pptx
```

## いま動くもの (Stage 1)

```bash
cd readable-md

# 構造チェック (node 不要)
./scripts/check-readable-md.sh <your.md>

# markdownlint も併せて
./scripts/check-readable-md.sh --lint <your.md>

# 任意プロジェクトへ持ち込む
./install.sh /path/to/target-project
```

詳細は [readable-md/README.md](./readable-md/README.md)。

## 設計方針

- **持ち込み可能性を最優先**: 各 Stage は `install.sh` で任意リポにコピーできる自己完結
  バンドルにする。lab 内でしか動かない作りにしない。
- **人 (スキル) と 機械 (チェッカ/lint) の二段構え**: 書くのは Claude、守るのは CI。
- **node 無しでも最低限動く**: 構造チェックは pure-bash。重い依存は任意機能に留める。
- **ツールは用途で選ぶ**: 最強の単一解はない。Stage 3 で Marp を既定にしつつ
  reveal/Pandoc も選べる余地を残す (レポート §E 用途別推奨)。

## 結果メモ

- Stage 1 を構築し、自前テンプレ + 親リポレポートでチェッカ / markdownlint を検証済み。
- 次の余白: Stage 2 (md→HTML 汎用化) と Stage 3 (Marp slide)。レポート §F-3 の
  「md push → lint → report HTML/PDF + slide HTML/PDF/PPTX → 配布」CI を最終形に置く。
