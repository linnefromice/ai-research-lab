---
description: "GitHub issue オーケストレーションの 1 周 (ready な issue を claim → type に応じ処理 → status 遷移) を実行する"
---

GitHub Issue オーケストレーションを 1 周実行する。`/loop 10m /orchestrate-once` で
周期実行できる。

## 前提

1. [docs/issue-protocol.md](../../docs/issue-protocol.md) を読む（規約の正本）。
2. `.env` を読む: `set -a; . ./.env; set +a`（`TARGET_REPO` / `MAX_ISSUES_PER_RUN`）。
   `TARGET_REPO` が空なら「.env 未設定」と報告して終了する。

## 手順

### 1. 整合性チェック

```bash
gh issue list --repo "$TARGET_REPO" --state open --json number,labels --limit 100
```

各 open issue の `status:` ラベル個数を検査する。0 個 / 2 個以上の issue があれば
**警告として報告**する（protocol §4 違反）。処理自体は続行してよい。

### 2. 対象を 1 件拾う

`status:ready` の issue を次の優先順で 1 件選ぶ。各群の中では
`priority:p0 > p1 > p2`、同 priority なら issue 番号の小さい順:

1. `type:design` + `agent:claude` + `status:ready` — [2] 設計
2. `type:impl` + `agent:claude` + `status:ready` — [3] 実装（Step 1 は Claude 代用）
3. `type:request` + `status:ready` — [1]（triage 済み）

```bash
gh issue list --repo "$TARGET_REPO" --state open \
  --label "type:design" --label "status:ready" --label "agent:claude" \
  --json number,title,labels --limit 20
```

該当なしなら「処理対象なし」と報告して終了する。

### 3. claim

`claim-issue` スキルで `status:ready`→`status:in-progress` に遷移する。
claim 失敗（既に他者が処理中）なら、その issue を除外して手順 2 に戻る。

### 4. type に応じて処理

| type | 処理 |
|---|---|
| `type:request` | `breakdown-request` → [2] を起票し [1] を close |
| `type:design` | `design-issue`（本文を設計）→ `breakdown-design`（[3] 群を起票 + [2] を `review`+`needs-human`） |
| `type:impl` | `implement-issue`（実装 + PR → [3] を `review`+`needs-human`） |

### 5. 失敗時

処理が失敗したら `issue-transition` で `in-progress`→`blocked`+`failed` に遷移し、
issue にコメントで理由を残す。

### 6. 報告

処理した issue 番号 / type / 遷移結果 / 起票した子 issue / 作成した PR を報告する。

`MAX_ISSUES_PER_RUN`（既定 1）件まで手順 2〜6 を繰り返す。

## 厳守

- 人間レビューゲート G1〜G4 は越えない。`status:review` + `needs-human` で停止し、
  承認・close・PR マージは人間に委ねる。
- status 遷移は必ず `issue-transition` 経由（単一 `gh issue edit`）。
