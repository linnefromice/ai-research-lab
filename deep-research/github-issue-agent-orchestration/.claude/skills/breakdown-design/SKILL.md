---
name: breakdown-design
description: "[2] design を実装単位に分解し、複数の [3] impl issue を起票する ([2]→[3] のブレイクダウン)。[2] を review + needs-human に遷移する。"
---

# breakdown-design スキル

## 概要

[issue-protocol.md](../../../docs/issue-protocol.md) の遷移 X2。`design-issue` が
仕上げた設計を、実装可能な単位の `type:impl` issue 群に分解する。

## 実行手順

入力: 設計本文が完成した（`status:in-progress`）の `type:design` issue `N`。

1. 設計本文の「子 [3] のリスト」を実装単位に確定する。1 つの [3] は
   「1 PR で完結する大きさ」を目安にする。
2. 各 [3] を起票する。担当エージェントは `.env` の `IMPL_AGENT`（既定 `claude`）で
   決める — Step 1 は `claude`、Codex 導入後 (Step 2) は `codex`。env var は永続しない
   ため `.env` の source は同一ブロックで行う（protocol §9）:
   ```bash
   set -a; . ./.env; set +a
   gh issue create --repo "$TARGET_REPO" \
     --title "<impl issue title>" \
     --label "type:impl" --label "status:triage" \
     --label "agent:${IMPL_AGENT:-claude}" \
     --body "$(cat <<'EOF'
親: #<[2]の番号>
由来: #<[2]の番号>

## 対象
<変更する範囲>

## 変更内容
<実装指示>

## テスト方針
<検証方法>

## 完了条件
PR が open + CI green
EOF
)"
   ```
   `IMPL_AGENT` が実行機構の切り替え点（protocol §5-2 のハイブリッド）。Step 1 では
   `claude` なので、起票された [3] を `/orchestrate-once` がそのまま拾える（人手での
   `agent:` 貼り替えは不要）。特定の [3] だけ担当を変えたいときは人間が貼り替える。
3. 起票した [3] 番号を [2] にコメントで一覧記録する:
   ```bash
   set -a; . ./.env; set +a
   gh issue comment <[2]の番号> --repo "$TARGET_REPO" --body "子 [3]: #<n1> #<n2> ..."
   ```
4. [2] を `in-progress`→`review` + `needs-human` に遷移する（`issue-transition`）。
   設計方針の承認（G3）と [2] の close は人間が行う。

## 注意

- 新規 [3] は `status:triage` 起票。`ready` 化は人間（G2 相当）。
- 本文冒頭に `親:` / `由来:` を必ず書く（protocol §7）。
