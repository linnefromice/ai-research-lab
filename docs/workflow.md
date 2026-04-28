# 検証ワークフロー

ai-research-lab で実験を始めてから片付けるまでの基本フロー。

---

## 1. 起点となるレポートを選ぶ

### Daily report 起点

毎朝の自動生成レポートから「面白い」「試したい」「気になる」項目を選ぶ。

```bash
# 親リポの最新レポートをざっと眺める例
ls ../ai-research-pipeline/features/tech-trends/reports/ | tail
cat ../ai-research-pipeline/features/tech-trends/reports/2026-04-27.md
```

Feature 一覧 (2026-04 時点):

| グループ | Feature |
|---|---|
| 国内 daily | tech-trends, finance-markets, invest-japan, productivity, life-hacks |
| Global daily (EN/JA) | tech-trends-global, wellness-global, parenting-global, family-finance-global, workstyle-global |
| Weekly | wellness, parenting-baby, parenting-edu, family-finance, workstyle |
| Session | invest-japan (open/mid/close), invest-global (open/mid/close) |

### Deep research 起点

```bash
ls ../ai-research-pipeline/features/deep-research/reports/ | head
cat ../ai-research-pipeline/features/deep-research/reports/cloudflare-ai-search-chat-ui.md
```

中間成果物 (Phase 0-3) も役に立つ:

| ファイル | 内容 |
|---|---|
| `01-web-research.md` | Web 調査の生 sources |
| `_sources.json` | 一次情報の URL 集 |
| `02-analysis.md` | 比較表 / SWOT |
| `03-validation.md` | ファクトチェック |

`../ai-research-pipeline/features/deep-research/research/<topic>/` 配下にある。

## 2. 実験ディレクトリを作る

命名規則:

| 起点 | パス |
|---|---|
| Daily | `daily-report/<feature>/<YYYY-MM-DD>/<slug>/` |
| Deep | `deep-research/<topic>/<slug>/` |

slug は短く具体的に (`gemini-flash-cost-bench`, `bun-vs-pnpm-install-time`)。

## 3. 実験 README を必ず書く

````markdown
# <slug>

## 起点
- レポート: `../../../../ai-research-pipeline/features/tech-trends/reports/2026-04-27.md`
- 該当節: 「Today's Highlights — Bun 1.2 リリース」

## 目的
Bun workspaces が pnpm workspaces を install 時間で上回るか測る。

## 実行方法
```bash
npm install
./bench.sh
```

## 結果メモ
- Bun: 平均 1.2s
- pnpm: 平均 3.4s
- 監視ポイント: cold cache 時は差が縮む (要再測)
````

このメモが将来「なぜこの実験を作ったか」を辿れる唯一の手がかりになる。
省略しない。

## 4. 動かす

実験コードは綺麗である必要はない。**動いて結果が出ること** が最優先。

- 1 ファイル script でも OK
- 依存は `package.json` / `requirements.txt` / `Cargo.toml` などに書く
- 環境変数は `.env.example` を残す (実値は `.env` で gitignore)

## 5. 残すか / 捨てるか

実験完了後、3 つの選択肢:

| 選択 | 何をする |
|---|---|
| **残す** (デフォルト) | README に「結果メモ」を追記して commit。後で見返せる状態に |
| **捨てる** | ディレクトリごと削除。結論だけ親レポートにフィードバック (任意) |
| **昇格** | 育てたい PoC は `apps/<name>/` などトップレベルに移動 |

## 6. パイプライン側へのフィードバック (任意)

検証で得た知見を pipeline 側のレポート品質改善に還元したい場合:

- `../ai-research-pipeline/` で別途 PR を切る
- 例: deep-research の goal template に「実装観点」を追加する等

このリポと pipeline は別 repo / 別 PR フローなので、混同しないこと。
