#!/usr/bin/env bash
#
# setup-issue-labels.sh — TARGET_REPO に issue オーケストレーション用ラベルを作成する
#
# 冪等: `gh label create --force` で create-or-update。何度実行しても同じ状態に収束する。
# ラベル定義（名前・色・説明）の正本は本スクリプトと docs/issue-protocol.md §2。
# 出典: deep-research レポート github-issue-agent-orchestration §3-5。
#
# 使い方:
#   ./scripts/setup-issue-labels.sh
#
# 前提: .env に TARGET_REPO を設定済み、`gh auth status` が通ること。

set -euo pipefail

# プロジェクトルート (.env の場所) を script の位置から解決する
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# .env 読み込み（このスクリプトは単一プロセスなので 1 回 source すれば十分）
if [[ ! -f "${PROJECT_ROOT}/.env" ]]; then
  echo "Error: ${PROJECT_ROOT}/.env がありません (.env.example をコピーして作成)" >&2
  exit 1
fi
set -a
# shellcheck disable=SC1091
. "${PROJECT_ROOT}/.env"
set +a

if [[ -z "${TARGET_REPO:-}" ]]; then
  echo "Error: .env の TARGET_REPO が未設定です" >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Error: gh が未認証です (gh auth login を実行)" >&2
  exit 1
fi

# ラベル定義: "name|color|description"
# status:done は作らない（完了は issue close で表す — protocol §4）
LABELS=(
  "type:request|5319e7|[1] 抽象的な要求・要望ノート"
  "type:design|1d76db|[2] 要件・設計"
  "type:impl|0e8a16|[3] 実装"
  "status:triage|ededed|起票直後・吟味中"
  "status:ready|fbca04|担当エージェントが拾ってよい"
  "status:in-progress|0e8a16|claim 済み・処理中"
  "status:review|d93f0b|成果物完成・人間レビュー待ち"
  "status:blocked|b60205|依存・不明点で停止中"
  "agent:claude|d4a5ff|Claude 担当"
  "agent:codex|a5d4ff|Codex 担当"
  "agent:human|d4d4d4|人間担当"
  "priority:p0|b60205|最優先"
  "priority:p1|d93f0b|通常"
  "priority:p2|fbca04|後回し可"
  "needs-human|e99695|人間の判断・承認が必要"
  "failed|b60205|エージェント処理が失敗"
)

echo "Target repo: ${TARGET_REPO}"
echo "Creating/updating ${#LABELS[@]} labels..."

fail=0
for entry in "${LABELS[@]}"; do
  IFS='|' read -r name color desc <<< "${entry}"
  if gh label create "${name}" --repo "${TARGET_REPO}" \
       --color "${color}" --description "${desc}" --force >/dev/null 2>&1; then
    echo "  ok  ${name}"
  else
    echo "  NG  ${name}" >&2
    fail=1
  fi
done

if [[ "${fail}" -ne 0 ]]; then
  echo "Error: 一部のラベル作成に失敗しました" >&2
  exit 1
fi
echo "Done. ${#LABELS[@]} labels are in sync on ${TARGET_REPO}."
