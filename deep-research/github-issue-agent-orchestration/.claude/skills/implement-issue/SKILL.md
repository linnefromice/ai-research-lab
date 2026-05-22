---
name: implement-issue
description: "[3] impl issue の実装指示に従いコードを変更し、テストを通し、PR を作成する。Step 1 では Claude が Codex を代用。変更は git worktree 内に隔離する。"
---

# implement-issue スキル

## 概要

[3] 実装工程。`type:impl` issue を実装し PR を出す。Step 2 以降は Codex が担うが、
Step 1 では Claude が代用する。

## 実行手順

入力: claim 済み（`status:in-progress`）の `type:impl` issue `N`。

1. `issue-read` で [3] と親 [2] を把握し、実装指示・完了条件を確定する。
2. **worktree 隔離**: `TARGET_REPO` のローカル clone で作業ブランチ用 worktree を切る:
   ```bash
   git -C "<clone>" worktree add "<WORKTREE_BASE>/issue-<N>" -b "impl/issue-<N>"
   ```
   破壊的なコード変更はこの worktree 内に限定する。
3. issue 本文の指示に従い実装する（`Edit` / `Write`）。
4. テスト・lint を実行し、green にする。失敗が解消できなければ手順 7 へ。
5. commit して push し、PR を作成する:
   ```bash
   gh pr create --repo "$TARGET_REPO" \
     --title "<title>" --body "Closes #<N>"
   ```
6. [3] を `in-progress`→`review` + `needs-human` に遷移する（`issue-transition`）。
   PR レビュー・マージ（G4）と issue close は人間が行う。
7. **失敗時**: [3] を `in-progress`→`blocked` + `failed` に遷移し、issue に
   コメントで理由（どこで詰まったか）を残す。

## 注意

- `Edit` / `Write` を使うのは [3] 実装工程のみ。[2] 設計工程には渡さない（protocol /
  レポート §7-4）。
- worktree は PR マージ後に人間 or 後片付け手順で `git worktree remove` する。
