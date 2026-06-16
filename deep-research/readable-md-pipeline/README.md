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
| **Stage 2** | md → HTML | 共通テーマ HTML (画面ダーク / 印刷 A4)。決定論レンダラ + LLM リッチパスの 2 系統 | ✅ **構築済** ([md-to-html/](./md-to-html/)) |
| **Stage 3** | md → slide | Marp で `slides.md` 生成 + HTML/PDF/PPTX。authoring(LLM) + build(決定論)の 2 段 | ✅ **構築済** ([md-to-slide/](./md-to-slide/)) |

各 Stage は「1 本通る」ことを確認してから次へ進む。Stage 間は **md = 正** の一点で
繋がっており、内容修正は常に md 側でのみ行う。

```text
[ research.md ]  ← 唯一の正 (Source of Truth)
      |
      | Stage 1: readable-md (執筆/整形 + drift gate)        ✅
      v
[ 読みやすい md ] --(機械検証 OK)-->
      |
      +--- Stage 2: md → report.html / report.pdf           ✅
      |
      +--- Stage 3: md → slides.html / slides.pdf / slides.pptx   ✅
```

3 Stage すべて構築済。md 1 本がレポート (HTML/PDF) と発表資料 (slide) へ同時に昇華する。

## 任意プロジェクトへ一括導入 (統合インストーラ)

3 Stage をまとめて持ち込むなら、親 `install.sh` を使う:

```bash
# 全 Stage を入れる
./install.sh /path/to/target-project

# 何が入るか確認 (dry-run)
./install.sh --dry-run /path/to/target-project

# Stage を選んで入れる (1=readable-md 2=html 3=slide)
./install.sh --only 1,2 /path/to/target-project
```

導入後、target 側で次が使える:

```bash
tools/readable-md/check-readable-md.sh <your.md>   # 1) 構造チェック (node 不要)
tools/md-to-html/render-html.sh <your.md>          # 2) md → HTML
tools/md-to-slide/build-slides.sh <slides.md>      # 3) slides.md → HTML/PDF/PPTX
# Claude スキル: /readable-md  /md-to-html  /md-to-slide
```

個別に入れたい場合は各 Stage の `install.sh` を直接使う
([readable-md](./readable-md/) / [md-to-html](./md-to-html/) / [md-to-slide](./md-to-slide/))。

## 設計方針

- **持ち込み可能性を最優先**: 各 Stage は `install.sh` で任意リポにコピーできる自己完結
  バンドルにする。lab 内でしか動かない作りにしない。
- **人 (スキル) と 機械 (チェッカ/lint) の二段構え**: 書くのは Claude、守るのは CI。
- **node 無しでも最低限動く**: 構造チェックは pure-bash。重い依存は任意機能に留める。
- **ツールは用途で選ぶ**: 最強の単一解はない。Stage 3 で Marp を既定にしつつ
  reveal/Pandoc も選べる余地を残す (レポート §E 用途別推奨)。

## 結果メモ

- 3 Stage + 統合インストーラを構築し、各 Stage を実物で検証済み（親リポ 481 行レポートの
  HTML 化、フルパイプラインで 10 枚スライド生成、fresh プロジェクトへ install → check →
  render → build の通し）。
- ドッグフーディングで実バグを修正: Stage 1 checker が Marp slide md の frontmatter を
  誤検知 → `marp:true` 検出で slide md と認識。
- 残りの余白: レポート §F-3 の「md push → lint → report HTML/PDF + slide HTML/PDF/PPTX →
  配布」を `.github/workflows/` に実体化する CI テンプレ。
