# github-issue-agent-orchestration — ローカルオーケストレータ

GitHub Issues を control plane にして「要求 → 設計 → 実装」の一周を
Claude / Codex で回す構成の、**ローカル側プロジェクト**。

## 起点
- レポート: `../../../ai-research-pipeline/features/deep-research/reports/github-issue-agent-orchestration.md`
- 該当節: 全体。特に §3 ラベル体系 / §4 状態機械 / §7 Claude ルール・スキル設計 /
  §9 共通規約 (`docs/issue-protocol.md`) / §11 最小検証手順
- 先行研究: `../../../ai-research-pipeline/features/deep-research/reports/hermes-agent-orchestration.md`
  (基盤・コスト・実行環境比較)

## 目的

GitHub 側（ラベル作成・issue テンプレ・リポ設定）には触れず、それに **触れにいく
ローカルプロジェクト** を用意する。3 機構を段階的に載せる:

| Step | 機構 | 状態 |
|---|---|---|
| **Step 1** | 共通コア + **claude `/loop`** | ← 本 PoC のスコープ |
| Step 2 | Codex Automations (`AGENTS.md` + automation プロンプト) | 余白 (未着手) |
| Step 3 | Symphony (Elixir orchestrator) | 余白 (レポートでもアダプタ未検証) |

各 Step は「一周が回る」ことを確認してから次へ進む（レポート §6-2 の段階移行）。

## 構成

```
github-issue-agent-orchestration/
├── README.md                     このファイル
├── .env.example                  接続先リポ等のキー名 (実値は .env=gitignored)
├── CLAUDE.md                     /loop 実行時に読まれるルール
├── docs/
│   └── issue-protocol.md         規約の単一ソース (type/status/claim)
└── .claude/
    ├── skills/issue-*/           issue 操作スキル群 (共通コア)
    └── commands/orchestrate-once.md  1 周分を実行するスラッシュコマンド
```

## 実行方法

```bash
cd deep-research/github-issue-agent-orchestration

# 1. 接続先リポを設定
cp .env.example .env
$EDITOR .env            # TARGET_REPO=<owner/repo> を埋める

# 2. このディレクトリで claude を起動し、単発で 1 周を確認
claude
> /orchestrate-once

# 3. 周期実行 (claude /loop)
> /loop 10m /orchestrate-once
```

前提: `gh` が認証済み (`gh auth status`)、`TARGET_REPO` に
`docs/issue-protocol.md` のラベル群が作成済みであること（GitHub 側の準備はユーザー作業）。

## 結果メモ

- (Step 1 検証後に追記)

## このプロジェクトで扱わないもの

- GitHub 側のラベル作成・issue テンプレ配置・リポ作成（ユーザーが別途行う）
- 秘密情報: `gh` / `claude` の認証は環境側 ambient。`.env` には `TARGET_REPO` 等の
  非秘匿な接続設定のみ。**API key / token は書かない**（lab は public）
