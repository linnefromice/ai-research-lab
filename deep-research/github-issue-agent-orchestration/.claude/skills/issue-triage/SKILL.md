---
name: issue-triage
description: "type:request ([1]) の issue を吟味し、[2] design 化してよいか・優先度を判定する。人間レビューゲート G1 の補助。"
---

# issue-triage スキル

## 概要

[1] 要求ノートを読み、「[2] 設計に進めてよいか」と優先度の判定材料を出す。
最終承認（G1）は人間が行う — このスキルは**判定材料を出すだけ**。

## 実行手順

入力: `type:request` の issue 番号 `N`。

1. `issue-read` で issue を構造化把握する。
2. 次を評価する:
   - **明確さ**: 「何を・なぜ」が読み取れるか。曖昧すぎないか。
   - **実装可能性の芽**: 設計工程 [2] で具体化できる見込みがあるか。
   - **重複**: 既存の open issue と被っていないか確認する
     （`set -a; . ./.env; set +a` の後に `gh issue list --repo "$TARGET_REPO"`）。
   - **優先度**: `priority:p0`（最優先）/ `p1`（通常）/ `p2`（後回し可）。
3. 判定を返す: `[2]化推奨` / `要追記`（情報不足）/ `却下推奨`（ノイズ・重複）、
   および推奨 `priority:`。
4. 判定理由を issue にコメントで残す（人間が G1 判断に使う）。env var は永続しない
   ため `.env` の source は同一ブロックで行う（protocol §9）:
   ```bash
   set -a; . ./.env; set +a
   gh issue comment <N> --repo "$TARGET_REPO" --body "<判定理由>"
   ```

## 注意

- ラベルの変更（`triage`→`ready`）も `agent:` 付与も**人間が行う**。このスキルは
  コメントを残すまで。
