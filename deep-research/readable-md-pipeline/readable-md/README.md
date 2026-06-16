# readable-md — 持ち込み可能な「読みやすい md を作る」バンドル (Stage 1)

md→HTML→slide パイプラインの **Stage 1**。「**読みやすい md = 機械が変換しやすい md**」
という等式に基づき、md を人にとって読みやすく・後段の変換 (HTML/スライド) が壊れない
構造に揃えるための、**どのプロジェクトにも持ち込める**自己完結バンドル。

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/reports/readable-markdown-to-html-slide-presentation-2026.md`
- 該当節: §A (読みやすい Markdown 構造原則) / §B (Single Source 設計) / §F-4 (昇華しやすい md かチェックリスト)

> 起点レポートは親リポ `ai-research-pipeline` (private) 内。上記は隣接 clone 前提の
> 相対パスで、GitHub の public 読者は辿れない (lab 全体のパス規約 — ルート
> [CLAUDE.md](../../../CLAUDE.md) 参照)。

## 目的

調査 md / 設計 md を、**1 ソース (md = 正) のまま HTML・スライド・PDF へ昇華できる構造**で
書く / 整えるための土台を提供する。「読みやすさ」を人手レビューでなく**機械で担保**し、
後段 (Stage 2 = md→HTML, Stage 3 = md→slide) のドリフトを根絶する。

## 中身

```text
readable-md/
├── README.md                     このファイル
├── install.sh                    任意プロジェクトへ冪等コピー
├── .markdownlint.jsonc           機械強制ルール (drift gate)。§A-1 を lint 化
├── skill/readable-md/SKILL.md    Claude 向けスキル: 可読+変換しやすい md を執筆/整形
├── scripts/check-readable-md.sh  node 不要の構造チェッカ (+ --lint で markdownlint)
└── templates/research-skeleton.md 調査 md 骨子テンプレ (§付録2-1)
```

| 部品 | 役割 | 駆動 |
|------|------|------|
| `skill/readable-md` | md を執筆・整形する (人の意図を構造に落とす) | Claude (`/readable-md`) |
| `check-readable-md.sh` | 構造を機械検証する drift gate | bash (node 不要) |
| `.markdownlint.jsonc` | 記法ゆれを機械強制 | markdownlint-cli2 |
| `templates/` | 「昇華しやすい」初期構造 | コピーして使う |

**スキル (人の判断) と チェッカ (機械検証) の二段構え**が肝。前者で書き、後者で守る。

## 実行方法

### このバンドル単体で試す

```bash
# 構造チェック (node 不要)
./scripts/check-readable-md.sh path/to/your.md

# markdownlint も併せて (npx 取得あり)
./scripts/check-readable-md.sh --lint path/to/your.md

# 骨子テンプレから書き始める
cp templates/research-skeleton.md path/to/new-research.md
```

### 任意プロジェクトに持ち込む

```bash
# 何がコピーされるか確認
./install.sh --dry-run /path/to/target-project

# 実行 (冪等。.markdownlint.jsonc は既存があれば skip)
./install.sh /path/to/target-project
```

コピー先:

| コピー先 (target 配下) | 中身 |
|------------------------|------|
| `.claude/skills/readable-md/SKILL.md` | スキル本体 (`/readable-md` で起動) |
| `.markdownlint.jsonc` | lint 設定 (既存があれば skip) |
| `tools/readable-md/check-readable-md.sh` | 構造チェッカ |
| `tools/readable-md/research-skeleton.md` | 骨子テンプレ |

### CI に drift gate を置く (例)

```yaml
# .github/workflows/md-lint.yml (擬似)
on: { push: { paths: ["**/*.md"] } }
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: npx --yes markdownlint-cli2 --config .markdownlint.jsonc "**/*.md"
```

## check-readable-md.sh が見るもの

| チェック | レベル | 対応ルール |
|---------|--------|-----------|
| H1 が 1 つか | error | MD025 |
| 見出しを飛ばしていないか | error | MD001 |
| 全コードフェンスに言語指定があるか | error | MD040 |
| frontmatter に title | error | §A-1 #8 |
| frontmatter に date | warn | §A-1 #8 |
| コードフェンスが閉じているか | error | — |
| インライン `style=` の混入 | warn | §C-2 (印刷で壊れる) |

`error` が 1 件でもあると終了コード 1 (CI で落ちる)。`warn` は 0。

## 結果メモ

- 自前の調査 md / 親リポのレポートでチェッカを検証済み。親レポートでは ASCII フロー図の
  裸フェンス (` ``` `) が MD040 で正しく検出された (→ ` ```text ` 推奨)。
- markdownlint v0.40 の MD025 は frontmatter `title:` を H1 とみなすため、原則 #1 (H1 単一)
  と #8 (frontmatter title) が衝突する。`front_matter_title: ""` で解消 (config に明記)。
- MD060 (table 整列) は CJK 幅で整列不能のため OFF。
- node 無し環境でも構造チェックだけは動く (`--lint` のみ npx 依存) ので、最低限の
  drift gate はどこでも効く。

## このバンドルの位置づけ

パイプライン全体のロードマップは [親 README](../README.md) を参照。Stage 1 (本バンドル) が
「読みやすい md を作る」、Stage 2 が md→HTML (親リポ `md-to-html` スキル相当)、
Stage 3 が md→slide (Marp 等) を担う。
