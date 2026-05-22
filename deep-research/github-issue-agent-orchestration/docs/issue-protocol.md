# issue-protocol — GitHub Issue オーケストレーション規約 (単一ソース)

このファイルは **ラベル体系・状態機械・claim 規約の正本**。Claude は `CLAUDE.md`、
Codex は (Step 2 以降) `AGENTS.md` から本ファイルを参照する。規約をそれぞれに直書き
すると乖離するため、**変更は必ずこのファイルだけに対して行う**。

出典: deep-research レポート `github-issue-agent-orchestration` §3/§4/§9。

---

## 1. 3 層 issue type

| type | 目的 | 担当 | 完了条件 (DoD) |
|---|---|---|---|
| `request` ([1]) | やりたいこと・困りごとの粗い記録。実装可能性は問わない | 人間 (起票) | 人間が [2] 化を承認 |
| `design` ([2]) | 要件定義・詳細設計・調査を 1 issue にまとめる | Claude | 設計本文が DoD を満たし、子 [3] が起票され、人間が方針承認 |
| `impl` ([3]) | [2] が分解した実装単位を進め PR を出す | Codex (Step 1 は Claude 代用) | PR open + CI green + 人間がレビュー・マージ |

type は `type:` ラベルで表す（personal repo 前提。org 化したら issue types に昇格）。

## 2. ラベル体系

prefix は小文字 + コロン。**`status:done` は作らない** — 完了は issue close で表す。

| グループ | ラベル | 意味 |
|---|---|---|
| `type:` | `type:request` / `type:design` / `type:impl` | 3 層 type |
| `status:` | `status:triage` / `ready` / `in-progress` / `review` / `blocked` | ライフサイクル（全 type 共通） |
| `agent:` | `agent:claude` / `agent:codex` / `agent:human` | 担当エージェント |
| `priority:` | `priority:p0` / `p1` / `p2` | 取得順 |
| その他 | `needs-human` / `failed` | レビュー待ちの目印 / 処理失敗 |

`agent:human` は `type:request` ([1]) の既定担当、およびエージェント処理が不能と
判断された issue に付ける（人間が担当することの明示）。

ラベル一覧と色は GitHub 側 (`TARGET_REPO`) に作成済みであること（本プロジェクトは
GitHub のラベル作成は行わない）。色定義はレポート §3-5 を参照。

## 3. 状態機械

```
 status:triage ──(人間が承認)──▶ status:ready ──(agent が claim)──▶ status:in-progress
                                      ▲                                    │
                                      │                          ┌─────────┴─────────┐
            (依存解消・人間が再投入)    │                    (成果物完成)        (処理失敗)
                                      │                          ▼                   ▼
                              status:blocked ◀───────────  status:review        status:blocked
                                                          + needs-human          + failed
                                                                │
                                                       (人間が承認) → issue close
```

### 遷移表

| # | 遷移 | 実行者 | コマンド (atomic) |
|---|---|---|---|
| T2 | `triage`→`ready` | 人間 | `gh issue edit N --remove-label status:triage --add-label status:ready` |
| T3 | `ready`→`in-progress` | エージェント (claim) | `gh issue edit N --remove-label status:ready --add-label status:in-progress` |
| T4 | `in-progress`→`review` | エージェント | `gh issue edit N --remove-label status:in-progress --add-label status:review --add-label needs-human` |
| T5 | `review`→close | 人間 | `gh issue close N` |
| T6 | `in-progress`→`blocked` | エージェント | `gh issue edit N --remove-label status:in-progress --add-label status:blocked --add-label failed` |
| T7 | `blocked`→`ready` | 人間 | `gh issue edit N --remove-label status:blocked --remove-label failed --add-label status:ready` |
| X1 | [1] 処理中に [2] 起票 | Claude | `gh issue create` (type:design) + 本文に `由来: #<[1]>` |
| X2 | [2] 処理中に [3] 起票 | Claude | `gh issue create` ×N (type:impl) + 本文に `親: #<[2]>` |

## 4. status 排他規約 (最重要)

GitHub のラベルに排他制約はない。**遷移は必ず単一の `gh issue edit` で old を
`--remove-label`・new を `--add-label` する**。先に add してから remove するのは
**禁止**（途中失敗で status が二重化する）。

- `status:` prefix のラベルは常に **ちょうど 1 個**。0 個・2 個以上は規約違反。
- 完了は `status:done` ではなく `gh issue close`。
- 整合性チェック: `gh issue list --json number,labels` で `status:` 個数を検査
  （`orchestrate-once` が 1 周の冒頭で実行）。
- **二重化の是正**: `status:` が 2 個以上の issue を検出したら、状態機械上**より進んだ
  status を残し**古い方を `--remove-label` で除去する（例: `ready` と `in-progress`
  併存 → `ready` を除去）。進行方向が判断できない場合は是正せず人間に報告する。
- **close の担当（非対称・意図的）**: `type:request` の close はエージェント
  (`breakdown-request`) が行う — [1] は [2] 起票をもって役割を終えるため。
  `type:design` / `type:impl` の close は人間が G3 / G4 で行う。

## 5. claim 規約 (二重取得防止)

1. **スコープ分離** — 各実行機構は `type:` + `agent:` + `status:ready` でフィルタし、
   拾う issue 集合をそもそも重ねない。
2. **claim 遷移** — 拾った直後に `ready`→`in-progress` へ即遷移 (T3)。遷移の直前に
   「まだ `status:ready` か」を再確認してから遷移し、レース窓を最小化する。
3. 遷移に失敗した（既に他者が claim 済み）issue はスキップして次へ。

## 6. レビューゲート (人間必須)

| ゲート | 遷移 | 目的 |
|---|---|---|
| G1 | [1] `triage`→`ready` | ノイズ要求を [2] 化させない |
| G2 | [2] `triage`→`ready` | 起票された [2] が設計すべきものか確認 |
| **G3** | [2] `review`→close | 設計方針を [3] 実装前に止める。**最重要** |
| **G4** | [3] `review`→close (PR マージ) | コードレビュー |

エージェントは **G1〜G4 を自分で越えない**。`status:review` + `needs-human` で
人間に渡し、そこで停止する。

**G3 却下時の後始末**: `breakdown-design` は G3 の前に子 [3] を起票する（遷移 X2）。
G3 で [2] の設計方針が却下された場合、その [2] が起票済みの子 [3]（`status:triage`）は
**人間が close** し、孤児 [3] を残さない。

## 7. issue 本文フォーマット

全 issue の本文冒頭に由来を明記する:

```
親: #<N>      (上位 type の issue 番号。[1] は省略可)
由来: #<N>    (この issue を生んだ issue 番号)
```

現状の `breakdown-request` / `breakdown-design` では両者は同値になる（構造上の親が
そのまま生成元）。生成元と構造上の親が異なるケース（[3] を別 [2] から再分割する等）に
備えて 2 フィールドを保持する。同値で問題ない。

- `type:design` の本文 DoD: 背景 / 要件 / 設計 / 調査ソース / 子 [3] のリスト
- `type:impl` の本文 DoD: 対象 / 変更内容 / テスト方針 / 完了条件

## 8. セットアップ (GitHub 側 — 参考)

ラベル一括作成は `TARGET_REPO` 側で行う。コマンドはレポート §3-5
(`gh label create` ×16) を参照。**本ローカルプロジェクトはラベル作成を行わない**。

## 9. エージェント実行上の約束

スキル・コマンドが `gh` を呼ぶときの共通規約。Claude / Codex 双方が守る。

- **環境変数は Bash 呼び出し間で永続しない**。`$TARGET_REPO` 等を使う bash ブロックは
  **ブロック先頭で必ず `set -a; . ./.env; set +a` を実行**してから `gh` を呼ぶ。
- **CWD はプロジェクトルートに保つ**（CWD は永続する）。永続的な `cd` は禁止し、
  別ディレクトリでの作業は `git -C <path>` / サブシェル `( cd <path>; ... )` で行う。
  これにより `. ./.env` の相対パスが常に有効になる。
- 処理開始前に `gh auth status` で認証を確認する（未認証なら即報告して停止）。
