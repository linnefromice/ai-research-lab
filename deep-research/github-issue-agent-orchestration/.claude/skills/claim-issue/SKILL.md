---
name: claim-issue
description: "status:ready の issue を claim する。遷移直前に ready を再確認してから in-progress へ atomic 遷移し、二重取得のレース窓を最小化する。issue を処理開始する直前に必ず使う。"
---

# claim-issue スキル

## 概要

issue を処理開始する直前に呼ぶ。[issue-protocol.md](../../../docs/issue-protocol.md)
§5 の claim 規約を実装する。

## 実行手順

入力: issue 番号 `N`。

1. **再確認**: 現在も `status:ready` かつ open か検査する。env var は永続しない
   ため `.env` の source は同一ブロックで行う（protocol §9）:
   ```bash
   set -a; . ./.env; set +a
   gh issue view <N> --repo "$TARGET_REPO" --json labels,state
   ```
   既に `status:in-progress` 等に変わっている / closed → **claim 失敗**。呼び出し元に
   「他者が claim 済み」と返し、この issue はスキップさせる。
2. `ready` のままなら `issue-transition` で `ready`→`in-progress` へ atomic 遷移する。
3. claim 成功を返す（issue 番号 + 現 status）。

## 注意

- 再確認と遷移の間のレース窓は残るが、`type:`+`agent:` のスコープ分離（protocol §5）
  で別機構との競合は構造的に無い。同一機構の多重起動は `/loop` を 1 本に保てば回避できる。
