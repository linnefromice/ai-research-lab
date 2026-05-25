---
name: issue-transition
description: "issue の status ラベルを atomic に遷移する。単一の gh issue edit で旧ラベル除去と新ラベル付与を同時に行い、status の二重化を防ぐ。全ての状態遷移はこのスキルを通す。"
---

# issue-transition スキル

## 概要

`status:` ラベルの遷移を、[issue-protocol.md](../../../docs/issue-protocol.md) §4 の
排他規約に従って atomic に行う。

## 実行手順

入力: issue 番号 `N`、現在の status `<old>`、目標の status `<new>`、
付随ラベル（任意。`needs-human` / `failed` 等）。

1. **遷移前の検証**: 現在の `status:` を読み、引数の `<old>` と一致するか確認する。
   env var は永続しないため `.env` の source は同一ブロックで行う（protocol §9）:
   ```bash
   set -a; . ./.env; set +a
   gh issue view <N> --repo "$TARGET_REPO" --json labels,state
   ```
   実 status が `<old>` と違う / 既に closed なら、遷移せず呼び出し元に「状態不一致」を
   報告する（古い `<old>` を盲信して `--remove-label` が失敗するのを防ぐ）。
2. **必ず単一コマンド**で旧除去 + 新付与を行う（`.env` を同一ブロックで source）:
   ```bash
   set -a; . ./.env; set +a
   gh issue edit <N> --repo "$TARGET_REPO" \
     --remove-label "status:<old>" \
     --add-label "status:<new>" [--add-label "<付随ラベル>" ...]
   ```
3. **禁止**: 「先に add、後で remove」の 2 コマンド分割。途中失敗で status が
   二重化する。
4. 遷移後、`gh issue view <N> --repo "$TARGET_REPO" --json labels` で `status:` が
   ちょうど 1 個か確認する。

## 主な遷移（protocol §3 遷移表）

| 用途 | old → new | 付随ラベル |
|---|---|---|
| claim | `ready` → `in-progress` | — |
| 完成 | `in-progress` → `review` | `needs-human` |
| 失敗 | `in-progress` → `blocked` | `failed` |

`status:done` は存在しない。完了は `gh issue close <N>` で表す。
