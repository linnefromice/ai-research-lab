# github-issue-agent-orchestration — Claude 向け作業方針

このディレクトリは GitHub Issues を control plane にした agent-orchestration の
**ローカル側プロジェクト**。`claude` をこのディレクトリから起動して使う。

## Issue 運用 (最重要)

- ラベル体系・3 層 type・状態機械・claim 規約の正本は
  [docs/issue-protocol.md](./docs/issue-protocol.md)。**作業前に必ず読む**。
- **status 遷移は必ず単一の `gh issue edit --remove-label <old> --add-label <new>`**。
  先に add・後で remove は禁止（status 二重化の原因）。
- 完了は `status:done` ではなく `gh issue close`。
- 人間レビューゲート G1〜G4 は越えない。`status:review` + `needs-human` で停止する。

## Claude の担当

- Step 1 (本 PoC) では Claude が **[2] design と [3] impl の両方**を回す
  （Codex 未導入のため [3] を代用。Step 2 で [3] を Codex に剥がす）。
- 各工程の手順は `.claude/skills/` の issue 操作スキルに従う:
  - `issue-read` — issue を構造化把握 / `issue-triage` — [1] の [2] 化可否判定
  - `claim-issue` — ready 再確認 → in-progress 遷移 / `issue-transition` — atomic 遷移
  - `breakdown-request` — [1]→[2] 起票 / `design-issue` — [2] 設計本文 /
    `breakdown-design` — [2]→[3] 起票 / `implement-issue` — [3] 実装 + PR
- 入口は `/orchestrate-once`（1 周実行）。周期実行は `/loop 10m /orchestrate-once`。

## 接続設定

- `.env` の `TARGET_REPO` (owner/repo) が操作対象。`gh` コマンドは常に
  `--repo "$TARGET_REPO"` を付ける。
- `.env` 読み込み: `set -a; . ./.env; set +a`。
- `gh` / `claude` の認証は環境側 ambient。**`.env` に API key / token を書かない**
  （このリポは public）。

## 行動原則 (lab PoC)

- ルート [../../CLAUDE.md](../../CLAUDE.md) の lab 方針（動くものを最速で・捨てて
  いい・production 品質の test/docs を要求しない）に従う。
- ただし **status 遷移の atomic 規約と claim 規約は PoC でも厳守**（破ると
  オーケストレーションが壊れる中核制約のため）。
- 破壊的操作（[3] 実装のコード変更）は worktree 内に隔離する。
