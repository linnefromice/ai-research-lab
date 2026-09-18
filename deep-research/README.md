# deep-research 起点の検証

ai-research-pipeline の Deep Research が産んだトピック別レポート
(`features/deep-research/reports/<topic>.md`) を起点に、設計検証 / PoC / 比較実装を行う
ディレクトリ。

---

## ディレクトリ構成

```
deep-research/
├── README.md
└── <topic>/             # 親リポの topic slug と一致させる
    ├── README.md        # トピック全体の検証方針 (任意)
    └── <slug>/          # 個別の実験
        ├── README.md
        └── ...
```

## 例

```
deep-research/
├── cloudflare-ai-search-chat-ui/
│   ├── README.md                      # トピックの全体方針
│   ├── astro-search-poc/
│   │   ├── README.md
│   │   └── ...
│   └── workers-ai-pricing-bench/
│       ├── README.md
│       └── ...
└── claude-code-automation-ideas/
    └── hooks-skill-poc/
        ├── README.md
        └── ...
```

## このリポで進行中のトピック

| ディレクトリ | 内容 |
|---|---|
| [github-issue-agent-orchestration](./github-issue-agent-orchestration/) | GitHub Issues を control plane にしたオーケストレータ (Step 1) |
| [m1-pro-local-llm-for-avatar](./m1-pro-local-llm-for-avatar/) | M1 Pro 上のローカル LLM + Live2D アバター |
| [readable-md-pipeline](./readable-md-pipeline/) | 読みやすい md → HTML / スライド |

親リポ側のレポート一覧:

```bash
ls ../ai-research-pipeline/features/deep-research/reports/
```

## トピックレベル README (任意)

レポート 1 本につき複数の検証を派生させる場合、`<topic>/README.md` で全体方針を書くと
追跡しやすい。書く内容例:

- 元レポートの結論サマリ (3-5 行)
- 検証したい仮説のリスト
- 既に実施した検証 (slug + 結果) の表

## Deep research の中間成果物も使える

最終 `report.md` だけでなく、Phase 0-3 の中間も役に立つ:

| ファイル | 内容 |
|---|---|
| `00-knowledge-base.md` | 基礎知識・用語定義 |
| `01-web-research.md` + `_sources.json` | Web 調査の生 sources |
| `02-analysis.md` | 比較表 / SWOT |
| `03-validation.md` | ファクトチェック |

パスは `../ai-research-pipeline/features/deep-research/research/<topic>/`。

## 始め方

詳細は [../docs/workflow.md](../docs/workflow.md) を参照。
