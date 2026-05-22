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

1. `.env` を読む（`TARGET_REPO`）。
2. **必ず単一コマンド**で旧除去 + 新付与を行う:
   ```bash
   gh issue edit <N> --repo "$TARGET_REPO" \
     --remove-label "status:<old>" \
     --add-label "status:<new>" [--add-label "<付随ラベル>" ...]
   ```
3. **禁止**: 「先に add、後で remove」の 2 コマンド分割。途中失敗で status が
   二重化する。
4. 遷移後、`gh issue view <N> --json labels` で `status:` がちょうど 1 個か確認する。

## 主な遷移（protocol §3 遷移表）

| 用途 | old → new | 付随ラベル |
|---|---|---|
| claim | `ready` → `in-progress` | — |
| 完成 | `in-progress` → `review` | `needs-human` |
| 失敗 | `in-progress` → `blocked` | `failed` |

`status:done` は存在しない。完了は `gh issue close <N>` で表す。
