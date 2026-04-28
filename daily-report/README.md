# daily-report 起点の検証

ai-research-pipeline が毎朝生成する daily report で取り上げられたツール / フレームワーク
/ 構成パターンを、手元で動かして検証するためのディレクトリ。

---

## ディレクトリ構成

```
daily-report/
├── README.md
└── <feature>/             # 親リポの feature 名と一致させる
    └── <YYYY-MM-DD>/      # 起点となったレポートの日付
        └── <slug>/        # 1 検証 1 ディレクトリ
            ├── README.md  # 起点 / 目的 / 実行方法 / 結果メモ
            └── ...        # 実験コード
```

## 例

```
daily-report/
├── tech-trends/
│   ├── 2026-04-27/
│   │   └── bun-1.2-workspaces-bench/
│   │       ├── README.md
│   │       ├── bench.ts
│   │       └── results.md
│   └── 2026-04-25/
│       └── opentelemetry-collector-config/
│           ├── README.md
│           └── otel-collector.yaml
└── tech-trends-global/
    └── 2026-04-26/
        └── claude-code-hooks-poc/
            ├── README.md
            └── .claude/hooks/...
```

## Feature 名の早見表 (2026-04 時点)

| グループ | Feature |
|---|---|
| 国内 daily | tech-trends / finance-markets / invest-japan / productivity / life-hacks |
| Global daily | tech-trends-global / wellness-global / parenting-global / family-finance-global / workstyle-global |
| Weekly | wellness / parenting-baby / parenting-edu / family-finance / workstyle |
| Session | invest-japan / invest-global (open/mid/close) |

最新は `ls ../ai-research-pipeline/features/` で確認。

## 始め方

1. 起点とする日次レポートを開く:
   ```bash
   cat ../../ai-research-pipeline/features/tech-trends/reports/2026-04-27.md
   ```
2. 試したい項目を 1 つ抽出する
3. `<feature>/<date>/<slug>/` を切って `README.md` を書く
4. 動かす

詳細は [../docs/workflow.md](../docs/workflow.md) を参照。
