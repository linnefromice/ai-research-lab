---
name: breakdown-request
description: "[1] request を入力に [2] design issue を起票する ([1]→[2] のブレイクダウン)。元の [1] は close する。"
---

# breakdown-request スキル

## 概要

[issue-protocol.md](../../../docs/issue-protocol.md) の遷移 X1。`type:request` を
1 件以上の `type:design` issue に分解して起票する。

## 実行手順

入力: claim 済み（`status:in-progress`）の `type:request` issue `N`。

1. `issue-read` で [1] を構造化把握する。
2. 要求を「設計工程で扱う単位」に分解する。多くは 1 個。明確に独立した関心事が
   複数あれば複数の [2] に分ける（type は肥大させない — protocol §1）。
3. 各 [2] を起票する:
   ```bash
   gh issue create --repo "$TARGET_REPO" \
     --title "<design issue title>" \
     --label "type:design" --label "status:triage" --label "agent:claude" \
     --body "$(cat <<'EOF'
親: #<N>
由来: #<N>

## 背景
<[1] の要約>

## このdesign issueで決めること
<スコープ>
EOF
)"
   ```
4. 起票した [2] の番号を [1] にコメントで記録する。
5. [1] を close する: `gh issue close <N> --repo "$TARGET_REPO"`
   （[1] の完了は close で表す — protocol §4）。

## 注意

- 新規 [2] は `status:triage` で起票する。`ready` 化（G2）は人間が行う。
- 本文冒頭に `親:` / `由来:` を必ず書く（protocol §7）。
