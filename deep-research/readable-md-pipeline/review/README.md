# review — 生成物の「見た目 human friendly」を担保するデザイン品質レビュー

md→HTML→slide パイプラインの**生成物 (HTML/スライド) が見た目として読みやすい構造か**を、
デザイン原則で品質レビューする横断バンドル。内容の正しさではなく、**構造の見やすさ**を見る。

レンズは Robin Williams『ノンデザイナーズ・デザインブック』の **C.R.A.P. 4 原則**
(Contrast / Repetition / Alignment / Proximity) + タイポグラフィ。

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/reports/readable-markdown-to-html-slide-presentation-2026.md` (§C-2 テーマ/印刷 CSS の勘所)
- デザイン原則: Robin Williams "The Non-Designer's Design Book" の C.R.A.P.

## 目的

「読みやすい md」を整えても、**HTML/スライドの見た目が破綻していたら human friendly でない**。
デザイン判断の大半は theme の CSS トークンに集約されているので、トークンを機械監査して
定量化し、静的に測れない整列・近接を LLM で補う ―― という二段構えで見た目品質を守る。

## 中身

```text
review/
├── README.md                       このファイル
├── install.sh                      任意プロジェクトへ冪等コピー
├── scripts/design-audit.sh         C.R.A.P. 機械監査 (コントラスト比/行長/type scale 等)
└── skill/design-review/SKILL.md    LLM レビュー (整列/近接/視覚的印象を C.R.A.P. で採点)
```

## 何を測るか

| C.R.A.P. | 機械 (design-audit.sh) | LLM (design-review) |
|---|---|---|
| **Contrast** | 文字/背景の WCAG コントラスト比 (画面ダーク & 印刷ライト両方)、type scale | 図と地の視覚的強弱 |
| **Repetition** | 生成 HTML のインライン `style=` 混入 (単一ソース違反)、色トークン数 | トーンの一貫性 |
| **Alignment** | — | 端揃え・グリッドの乱れ (目視/スクショ) |
| **Proximity** | — | 関連要素のグルーピング・余白設計 (目視) |
| **Typography** | 行長 (1 行の文字数)・行間・見出し階層 | — |

## 実行方法

### 機械監査 (決定論・node 不要)

```bash
# パイプラインの theme を自動で探して監査 (HTML を渡すとインライン style も見る)
./scripts/design-audit.sh path/to/generated.html

# theme を明示
./scripts/design-audit.sh --theme path/to/report-theme-head.html path/to/generated.html
```

コントラスト AA 未満 (本文 < 4.5) が 1 件でもあると終了コード 1 (CI gate)。行長・行間・
type scale・パレットは WARN (改善余地)。

### LLM レビュー (整列/近接)

```bash
/design-review path/to/generated.html
```

先に design-audit を走らせ、その結果を起点に、レンダリング結果 (あればスクショ) へ
C.R.A.P. を当てて 5 段階で採点・改善提案する。直しは theme asset (単一ソース) へ。

### 任意プロジェクトに持ち込む

```bash
./install.sh /path/to/target-project
```

`design-audit.sh` は既定テーマを `tools/md-to-html/report-theme-head.html` から探すので、
Stage 2 も入れておくと `--theme` 省略で動く。

## 結果メモ

- パイプラインの実テーマ + 生成 report.html を監査。コントラストは画面・印刷とも WCAG AA
  通過 (本文 15:1 / 印刷 17:1)。当初 WARN として有用な実指摘が 3 件出た:
  - 行長 ≒ 68 文字/行は JP に広い (快適域 ~30-45)。
  - h3 が本文と同サイズ (16px) で見出しのサイズ強弱が弱い。
  - 色トークン 13 はやや多い。
- **その 3 件を theme asset (単一ソース) で実際に修正し、WARN 0 を達成** (監査で before/after 比較):
  - 散文の読み幅 `--measure: 38rem` を導入し `p/ul/ol/blockquote` に適用 →
    本文 38 文字/行に。**表・カード・フロー図 (pre) は全幅のまま** (典型的な雑誌型レイアウト)。
  - h3 を 16→18px (印刷 10→11px) で h1>h2>h3>body のサイズ階層を回復。
  - 未使用トークン `--orange` を削除 (13→12)。
  - 監査側も `--measure` を読み、レイアウト幅でなく本文読み幅で行長を判定するよう改良。
- 低コントラストのダミーテーマで FAIL→exit 1、インライン style 検出も確認。
- コントラスト比は hex から WCAG 相対輝度を awk で計算 (node 不要)。
- 整列/近接の視覚評価はスクショが要る。chromium 無し環境ではマークアップ推論に留め、
  その旨を明記する方針 (skill に記載)。

## どこまでコードで行けるか (設計メモ)

「見た目をコードでどこまで改善できるか」の到達点と壁 (梯子 Lv0-4・C.R.A.P. がどの
レベルで計算可能になるか・正しさ vs 適切さの境界・推奨ロードマップ) は
[DESIGN-CEILING.md](./DESIGN-CEILING.md) に分離してある。要点:

- **正しさ** (一貫性・アクセシビリティ・原則準拠) はコードで実質 100% 保証できる。
- **適切さ** (意味に対する見た目・ブランド・意図) は人間が seed を選ぶ。
- C.R.A.P. はすべて **Lv2 (レンダリング幾何) までで計算可能** ―― Alignment/Proximity も
  座標を測れば決定論で数値化できる (「目視」は Lv2 未導入時の fallback)。

## このバンドルの位置づけ

全体ロードマップは [親 README](../README.md)。Stage 1-3 が「作る」側、本 review が
「**作ったものの見た目を担保する**」側。md (正) の構造健全性は Stage 1 の
check-readable-md.sh、生成物の見た目は本バンドルが見る。
