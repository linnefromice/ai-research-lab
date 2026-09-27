# ai-research-lab — エージェント向け方針

[ai-research-pipeline](../ai-research-pipeline) の daily-report / deep-research を
手元で検証する PoC 置き場。目的・ディレクトリ構成は [README.md](./README.md)、
検証の進め方は [docs/workflow.md](./docs/workflow.md)、親リポのレポート探し方は
[docs/pipeline-reference.md](./docs/pipeline-reference.md) を参照。

## このリポは Public — 秘密情報を書かない

- API key / token / 認証情報を書き込まない・commit しない
- 親リポ (`../ai-research-pipeline`) の private な情報 (内部 URL, 非公開スキーマ, 個人特定情報) を写し取らない
- Cloud リソース ID など公開したくない値を書かない
- 秘密値は `.env` (gitignored) に。`.env.example` はキー名だけ
- うっかり commit したら即ローテート + git history からの除去を検討
- 社外秘 / 個人情報 / production 認証情報を伴う検証は行わない。依頼があれば
  「別途 private repo を立てましょう」と提案する (このリポでは進めない)

## 親リポ (`../ai-research-pipeline/`) は Read のみ

改変しない。知見を pipeline 側に還元したい場合は、ユーザーに伝えた上で
pipeline 側で別途 PR を切る (このリポからの作業ではない)。

## 行動原則 (PoC / 実験用、pipeline より軽量)

- 「壊れていい・捨てていい」が前提。作り込みすぎない
- production 品質の error handling / test / docs は要求しない。最小限で OK
- 「そのうち綺麗にする」コメントを残してよい
- ただし: 実行手順は README に書く、秘密情報は `.env` に置く、親リポは改変しない

## 適用しないこと (pipeline からの逸脱)

TDD / 80% カバレッジ、設計書ファースト、main 直接 commit 禁止 / PR 必須、
code-reviewer エージェント必須、非自明な機能追加の事前設計 — これらは適用しない。
main 直 commit OK、PR は任意。

ただし秘密情報を commit しないことと、大きな破壊的操作 (`rm -rf`, force push) は
確認してから行うことは pipeline と同じく守る。

## 新規実験

起点となるレポートを Read し、`daily-report/<feature>/<date>/<slug>/` または
`deep-research/<topic>/<slug>/` を作って README に **起点 / 目的 / 実行方法 / 結果メモ**
を書く (必須、省略しない)。詳細な手順は [docs/workflow.md](./docs/workflow.md)。

## 日次定例

`just daily` は親リポの最新レポートを一覧するだけ (Read のみ)。生成・公開反映は
親リポの定型日次 (`../ai-research-pipeline/scripts/ops-phrase-daily.sh`) で行う。
このリポからは実行しない。
