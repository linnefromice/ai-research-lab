---
name: issue-read
description: "GitHub issue を 1 件読み、type / status / agent / priority / 親子関係を構造化して把握する。issue を処理する前段で使う。"
---

# issue-read スキル

## 概要

issue 番号を受け取り、本文とラベルから type/status/agent/親子関係を構造化して返す。

## 実行手順

1. issue を取得する。**env var は Bash 呼び出し間で永続しない**ため、`.env` の
   source は `gh` と同一ブロックで行う（protocol §9）:
   ```bash
   set -a; . ./.env; set +a
   gh issue view <N> --repo "$TARGET_REPO" \
     --json number,title,body,labels,state,comments
   ```
2. ラベルから `type:` / `status:` / `agent:` / `priority:` を分離して抽出する。
3. 本文冒頭の `親: #<N>` / `由来: #<N>` 行を抽出する。
4. **規約チェック**: `status:` prefix のラベルがちょうど 1 個か検査する。0 個 / 2 個
   以上なら規約違反として警告する（[issue-protocol.md](../../../docs/issue-protocol.md) §4）。
5. 次を構造化サマリとして返す: 番号 / title / type / status / agent / priority /
   親 / 由来 / DoD（本文要約） / open|closed。

## 注意

- このスキルは **読むだけ**。ラベル変更や issue 作成は行わない。
