# ai-research-lab — Claude 向け作業方針

このリポは [ai-research-pipeline](../ai-research-pipeline) で生成された daily-report
/ deep-research の知見を、手元で動かして検証するための作業場。

詳細な目的とディレクトリ構成は [README.md](./README.md) を、軽量ルールは
[.claude/rules/lab-workflow.md](./.claude/rules/lab-workflow.md) を参照。

## ⚠️ このリポは Public

**ai-research-lab は GitHub 上で public 公開している**。Claude/AI 作業時は次を厳守:

- **API key / token / 認証情報を絶対に書き込まない・commit しない** (Anthropic / OpenAI / GitHub / Telegram Bot 等)
- 親リポ (`../ai-research-pipeline`) の **private な情報** (内部 URL, 非公開スキーマ, 個人特定情報) を写し取らない
- Cloud リソース ID (Cloudflare account ID, GCP project ID 等) のうち公開したくないものを書かない
- 秘密値は `.env` (gitignored) に。`.env.example` ではキー名だけ共有
- うっかり commit した場合は **即ローテート** + git history からの除去を検討

### 秘匿情報を扱う検証は別 (private) repo を提案する

社外秘 / 個人情報 / production 認証情報を伴う検証は、このリポでは行わない。
ユーザーから依頼があった場合は **「別途 private repo を立てましょう」と提案** する
(本リポで進めない)。

詳細は [README.md の Public 警告節](./README.md#%EF%B8%8F-このリポは-public--秘匿情報を入れない) と
[.claude/rules/lab-workflow.md の 秘密情報 節](./.claude/rules/lab-workflow.md#秘密情報) を参照。

## 親リポへのアクセス

dev 環境では通常、ai-research-pipeline は `../ai-research-pipeline` に存在する。
レポート参照時は次のパスを直接 Read してよい:

| 種別 | パス |
|---|---|
| 国内 daily report | `../ai-research-pipeline/features/<feature>/reports/<YYYY-MM-DD>.md` |
| Global daily (EN) | `../ai-research-pipeline/features/<feature>-global/reports/<YYYY-MM-DD>.en.md` |
| Global daily (JA) | `../ai-research-pipeline/features/<feature>-global/reports/<YYYY-MM-DD>.ja.md` |
| Deep research | `../ai-research-pipeline/features/deep-research/reports/<topic>.md` |
| Deep research 中間 | `../ai-research-pipeline/features/deep-research/research/<topic>/` |
| Deep research goal | `../ai-research-pipeline/features/deep-research/goals/<topic>.md` |
| RSS sources | `../ai-research-pipeline/public-src/sources/<feature>/sources.json` |

存在しない場合はユーザーに確認する (clone されていない可能性)。

## 行動原則

このリポは PoC・実験用なので、pipeline 側よりも軽量に振る舞う:

- **「壊れていい・捨てていい」が前提**。作り込みすぎない
- **production 品質の error handling / test / docs を要求しない**。最小限で OK
- **「そのうち綺麗にする」コメントを残してよい** (PoC の本質)
- ただし以下は守る:
  - 実行手順 (どう動かすか) は README に書く
  - 起点となったレポート (どの daily-report のどの段落 / どの deep-research か) を
    実験ディレクトリの README にリンクする — 後から「なぜこれを作ったか」を辿れるように
  - 秘密情報 (API key, token) は `.env` に置き `.gitignore` に追加する
  - **親リポ (`../ai-research-pipeline/`) は Read のみ。改変しない**

## 新規実験を始めるとき

1. 起点となるレポートを Read して、何を試すか決める
2. `daily-report/<feature>/<date>/<slug>/` または `deep-research/<topic>/<slug>/` に
   ディレクトリを切る
3. その配下に `README.md` を作り、**起点 / 目的 / 実行方法 / 結果メモ** を書く
4. 動かす

slug は短く具体的に (`gemini-flash-cost-bench`, `bun-vs-pnpm-install-time`)。

## このリポでは適用しないこと (pipeline からの逸脱)

pipeline 側で必須のルールで、ここでは **適用しない** もの:

- TDD / 80% カバレッジ
- 設計書ファースト (`design-first.md`) — PoC はスキップ可
- main 直接 commit 禁止 / PR 必須
- code-reviewer エージェント必須
- 非自明な機能追加の事前設計

ただし以下は pipeline と同じく **守る**:

- 秘密情報を commit しない
- 大きな破壊的操作 (`rm -rf`, force push) は確認してから
