# md-to-slide — 持ち込み可能な「md→スライド」バンドル (Stage 3)

md→HTML→slide パイプラインの **Stage 3**。調査/レポート md (正) を**発表スライド**へ昇華する。
既定ツールは **Marp**（純 Markdown 寄り・最速配布・HTML/PDF/PPTX）。**どのプロジェクトにも
持ち込める**自己完結バンドル。

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/reports/readable-markdown-to-html-slide-presentation-2026.md` (§D スライド実践 / §E ツール比較 / §F ワークフロー)

> 親リポ (private) のパスは隣接 clone 前提 (lab のパス規約 — ルート
> [CLAUDE.md](../../../CLAUDE.md) 参照)。

## 目的

Stage 1 で整え Stage 2 で HTML 化した md を、**同じ md 資産から発表資料**へも昇華する。
「文書 md とスライド md は編集距離がある」ため、要約・分割した `slides.md` を派生として作り、
そこから決定論的に HTML/PDF/PPTX をビルドする。

## 中身

```text
md-to-slide/
├── README.md                     このファイル
├── install.sh                    任意プロジェクトへ冪等コピー
├── skill/md-to-slide/SKILL.md    LLM スキル: report.md → slides.md (要約・分割)
├── scripts/build-slides.sh       決定論ビルド: marp-cli で HTML/PDF/PPTX
└── templates/slides-marp.md      Marp 骨子テンプレ (§付録2-2)
```

## 2 段構え (authoring と build)

| 段 | 役割 | 手段 |
|----|------|------|
| **authoring** | `report.md` を要約・1 スライド 1 メッセージに分割して `slides.md` を作る | LLM (`/md-to-slide`) |
| **build** | `slides.md` → HTML / PDF / PPTX | `build-slides.sh` (marp-cli) |

> **編集距離があるので自動同期は困難 (銀の弾丸なし)**。文書とスライドは別ファイルにし、
> 内容修正は `report.md` (正) 側で行って `slides.md` を作り直す。

## 実行方法

### ビルド (node のみ・HTML は chromium 不要)

```bash
./scripts/build-slides.sh slides.md            # HTML のみ (既定)
./scripts/build-slides.sh slides.md --pdf       # + PDF (要 chromium)
./scripts/build-slides.sh slides.md --pptx      # + PPTX (要 chromium)
./scripts/build-slides.sh slides.md --all       # HTML + PDF + PPTX
./scripts/build-slides.sh slides.md -o dist/    # 出力先指定
```

出力は既定で `slides.md` と同階層の `dist/`（gitignore 済）。

### authoring (Claude)

```bash
/md-to-slide path/to/report.md          # report.md → report.slides.md に要約・分割
```

### 任意プロジェクトに持ち込む

```bash
./install.sh --dry-run /path/to/target-project
./install.sh /path/to/target-project
```

コピー先: `.claude/skills/md-to-slide/SKILL.md` / `tools/md-to-slide/build-slides.sh` /
`tools/md-to-slide/slides-marp.md`。

## ツール選択 (既定 Marp。用途で替える)

| やりたいこと | 推奨 |
|------------|------|
| CI で slide+PDF 自動生成・最速配布 | **Marp** (本バンドル) |
| リッチ/インタラクティブ (live code) | Slidev |
| 自由度最大・既存 HTML 資産 | reveal.js |
| 文書もスライドも 1 ツールで | Pandoc / Quarto |

`slides.md` が素直な md なら `pandoc -t revealjs` 等にもそのまま渡せる。

## 結果メモ

- `build-slides.sh` を Marp テンプレで検証。5 スライドの HTML (112KB) を生成。
- **marp-cli の stdin ハング**: 非 TTY (CI / バックグラウンド) では marp-cli が stdin 待ちで
  固まる。`--no-stdin` を必ず付ける (スクリプトに組込み済)。
- **chromium 依存**: HTML は不要、PDF/PPTX は内部でブラウザを使う。本環境は未導入のため
  PDF/PPTX は graceful skip し、HTML 印刷 or `CHROME_PATH` 指定を案内する。
- npx での marp-cli 取得時、puppeteer が chromium を DL しようとして遅い →
  `PUPPETEER_SKIP_DOWNLOAD=1` で抑止 (HTML には不要なため。スクリプトに組込み済)。

## このバンドルの位置づけ

全体ロードマップは [親 README](../README.md)。Stage 1 ([readable-md](../readable-md/)) で
md を整え、Stage 2 ([md-to-html](../md-to-html/)) で HTML へ、本 Stage 3 で slide へ。
これで md 1 本がレポートと発表資料へ同時に昇華する。
