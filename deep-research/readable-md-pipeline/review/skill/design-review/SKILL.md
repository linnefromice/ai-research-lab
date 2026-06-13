---
name: design-review
description: "生成した HTML / スライドが「見た目 human friendly」か、ノンデザイナーズ・デザインブックの C.R.A.P. (Contrast/Repetition/Alignment/Proximity) + タイポグラフィで品質レビューする。「デザインを見て」「読みやすい見た目か」「レイアウトをレビュー」で起動。機械監査 (design-audit.sh) を先に走らせ、静的に測れない整列・近接・視覚的印象を補う。"
user_invocable: true
argument_hint: "<generated.html | slides.html> [--theme <report-theme-head.html>]"
origin: ai-research-pipeline/deep-research/readable-markdown-to-html-slide-presentation-2026 + Robin Williams "The Non-Designer's Design Book"
---

# design-review スキル (品質レビュー)

md→HTML→slide の**生成物が見た目 human friendly か**を、デザイン原則で評価する。
内容の正しさ (忠実性) ではなく、**構造の見やすさ**を担保するのが目的。

レンズは Robin Williams『ノンデザイナーズ・デザインブック』の **C.R.A.P. 4 原則** +
タイポグラフィ。「デザインの大半は theme の CSS トークンに集約されている」ため、
まず機械監査でトークンを定量化し、静的に測れない部分を目視で補う。

## 評価軸

| 原則 | 問い | 担当 |
|------|------|------|
| **Contrast (対比)** | 図と地・見出しと本文の強弱が十分か。色のコントラスト比は AA 以上か | 機械 (design-audit) + 目視 |
| **Repetition (反復)** | 同じ役割の要素が一貫して同じ見た目か。場当たりな装飾がないか | 機械 (inline style 検出) + 目視 |
| **Alignment (整列)** | すべての要素が見えない線に揃っているか。端・グリッドの乱れがないか | **目視 (LLM)** |
| **Proximity (近接)** | 関連する要素が近く、無関係な要素が離れているか。余白でグループ化できているか | **目視 (LLM)** |
| **Typography** | 行長・行間・書体階層が読みやすいか | 機械 (design-audit) |

## 実行手順

### 1. まず機械監査を走らせる

```bash
./scripts/design-audit.sh <generated.html> [--theme <theme>]
```

出力 (コントラスト比 / 行長 / type scale / インライン style / パレット) を**読み込み**、
FAIL/WARN を起点にする。コントラスト AA 未満は最優先で直す。

### 2. レンダリング結果を見る (Alignment / Proximity)

> 補足: Alignment/Proximity は本質的に「目でしか測れない」わけではない。**レンダリングして
> 要素の座標を測れば決定論で数値化できる** (左端 X のクラスタ数 / ギャップ比)。これは
> [DESIGN-CEILING.md](../../DESIGN-CEILING.md) の Lv2 (geometry-audit) の領分。本スキルの目視は
> その自動監査が無いときの fallback。

- **スクリーンショットが撮れる環境** (chromium 等) があれば、HTML をレンダリングして
  画像を Read し、整列・近接・視覚的リズムを評価する。
- 無い環境では、**HTML 構造 + theme トークンから推論**する (ピクセルは見えないが、
  マークアップの入れ子・余白クラス・カードのグルーピングから判断できる)。限界は明記する。

評価の着眼点 (C.R.A.P.):
- **Alignment**: 見出し・本文・カードが同じ左端に揃っているか。中央寄せと左寄せの混在がないか。
- **Proximity**: セクション間の余白 > セクション内の余白 になっているか (関連が近接)。
  見出しが「次の段落」に近く「前のセクション」から離れているか。
- **Contrast**: 一番言いたいことが視覚的に一番目立つか。全部同じ強さで平板になっていないか。
- **Repetition**: 見出しスタイル・タグ・カードが一貫しているか。1 箇所だけ違う装飾がないか。

### 3. スライド特有の観点 (slides.html のとき)

- 1 スライド 1 メッセージが**視覚的にも**成立しているか (詰め込み過多でないか)。
- 各スライドで内容がスライド枠を**オーバーフローしていないか** (Marp は溢れる)。
- 余白が十分か。箇条書きが画面を埋め尽くしていないか。

### 4. 採点と改善提案

各軸を 5 段階 (1=要改善 … 5=良好) で採点し、**根拠**と**具体的な直し方**を出す。
直す対象は原則 **theme の asset (`report-theme-head.html`)** ―― 単一ソースを直せば
全生成物に反映される。個別 HTML を手で直さない。

```text
design-review 結果: <file>
  Contrast    : 4/5  本文 15:1 と高コントラスト。ただし h3 が本文と同サイズで弱い
  Repetition  : 5/5  インライン style なし。カード/タグ一貫
  Alignment   : 4/5  左端揃え。表のセル内改行が不揃い
  Proximity   : 3/5  セクション間余白が section 内と差が小さく、区切りが弱い
  Typography  : 3/5  行長 68 字/行は JP に広い。h3 のサイズ強弱を付けたい
  → 推奨: asset の h3 を 16→17-18px、--text-sub を一段明るく、.container を 760px 前後に
```

## 注意事項

- **内容ではなく見た目を見る**。事実誤りや情報欠落は別のレビュー (忠実性) の担当。
- **直しは単一ソースへ**。theme asset を直す。生成 HTML を手編集しない。
- **過剰装飾を足さない**。読みやすさのための引き算を優先 (デザインブックの精神)。
- **スクショが撮れないなら正直に**。「ピクセル未確認、マークアップからの推論」と明記する。
- **由来**: deep-research レポートの可読性原則 + 『ノンデザイナーズ・デザインブック』の
  C.R.A.P.。機械部分は [`scripts/design-audit.sh`](../../scripts/design-audit.sh) が担う。
