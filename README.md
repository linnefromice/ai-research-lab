# ai-research-lab

[ai-research-pipeline](https://github.com/linnefromice/ai-research-pipeline) で生成した
**daily-report** や **deep-research** の知見を、手元で実際に動かして検証するための作業場。

## 目的

リサーチパイプラインが毎日産み出すレポートには「試したいツール」「気になる構成」「比較
したいフレームワーク」が大量に並ぶ。読むだけでは血肉化しない。このリポは:

- レポートで取り上げられた **ツール / ライブラリ / アーキテクチャ** を実際に動かす
- **PoC** や **最小構成のデモアプリ** を作って体感する
- 検証結果を残し、後でリサーチに feedback できる形にする

ための場所。production code を置く場所ではないので、汚いコード・捨てる前提のコード・
未完成の実験で構わない。

## ai-research-pipeline との関係

|                        | ai-research-pipeline               | ai-research-lab (このリポ)            |
| ---------------------- | ---------------------------------- | ------------------------------------- |
| 役割                   | RSS + AI でレポート自動生成        | 生成されたレポートを起点に手で検証    |
| 出力                   | `features/<feature>/reports/*.md`  | 動くコード、PoC、ベンチ結果、メモ     |
| 品質                   | production (cron 運用)             | experimental (壊して良い)             |
| ブランチ運用           | main 直 commit 禁止 (PR 必須)      | 軽量。直 commit OK / PR は任意        |
| AI ルール              | TDD・design-first・code-review 必須 | 動かすことを最優先・ルールは最小限    |

dev clone は通常 `../ai-research-pipeline` に隣接する想定。Claude/AI が作業する際は
`../ai-research-pipeline/features/<feature>/reports/<date>.md` などを直接参照する。

## ディレクトリ構成

```
ai-research-lab/
├── README.md                  # このファイル
├── CLAUDE.md                  # Claude/AI 向け作業方針
├── .claude/
│   └── rules/
│       ├── lab-workflow.md         # lab 固有の軽量ルール
│       ├── bash-best-practices.md  # pipeline からコピー
│       └── common/
│           └── coding-style.md     # pipeline からコピー
├── docs/
│   ├── workflow.md            # 検証の進め方
│   └── pipeline-reference.md  # 親リポのレポート探し方
├── daily-report/              # daily-report 起点の検証
│   └── README.md
└── deep-research/             # deep-research 起点の検証
    └── README.md
```

「育って独立した PoC」になったものは、`daily-report/` / `deep-research/` から
トップレベルに昇格させて構わない (例: `apps/some-cool-poc/`)。

## 検証フロー (概略)

1. `../ai-research-pipeline/features/<feature>/reports/<date>.md` または
   `features/deep-research/reports/<topic>.md` を読む
2. 試したい項目を 1 つ抽出する
3. `daily-report/<feature>/<date>/<short-slug>/` または
   `deep-research/<topic>/<short-slug>/` を作る
4. README に「何を、どのレポートのどの節を起点に試したか」を書く
5. 動かす → 残す or 捨てる

詳細は [docs/workflow.md](docs/workflow.md) を参照。
