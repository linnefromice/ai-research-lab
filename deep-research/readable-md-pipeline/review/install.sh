#!/usr/bin/env bash
#
# install.sh — review (デザイン品質監査) バンドルを任意プロジェクトへ持ち込む (冪等)。
#
# C.R.A.P. デザイン監査スクリプトと LLM レビュースキルをコピーする。
# design-audit.sh は既定テーマを tools/md-to-html/report-theme-head.html から探すため、
# Stage 2 (md-to-html) も入れておくと --theme 省略で動く。
#
# 使い方:
#   ./install.sh <target-project-dir>      # コピー実行
#   ./install.sh --dry-run <target-dir>    # 表示のみ
#
# コピー先 (target 配下):
#   .claude/skills/design-review/SKILL.md     レビュー スキル
#   tools/review/design-audit.sh              デザイン監査 (機械)
#
set -euo pipefail

DRY=0
TARGET=""
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) TARGET="$arg" ;;
  esac
done

if [[ -z "$TARGET" ]]; then
  echo "usage: $0 [--dry-run] <target-project-dir>" >&2
  exit 2
fi
if [[ ! -d "$TARGET" ]]; then
  echo "error: target dir not found: $TARGET" >&2
  exit 1
fi

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="$(cd "$TARGET" && pwd)"

# src::dst::overwrite(1)/skip-if-exists(0)
MAPPINGS=(
  "${SRC}/skill/design-review/SKILL.md::${TARGET}/.claude/skills/design-review/SKILL.md::1"
  "${SRC}/scripts/design-audit.sh::${TARGET}/tools/review/design-audit.sh::1"
)

copied=0 skipped=0
for m in "${MAPPINGS[@]}"; do
  src="${m%%::*}"; rest="${m#*::}"; dst="${rest%%::*}"; ow="${rest##*::}"
  rel="${dst#"$TARGET"/}"

  if [[ "$ow" -eq 0 && -e "$dst" ]]; then
    echo "skip (既存):      ${rel}"
    skipped=$((skipped + 1))
    continue
  fi
  if [[ $DRY -eq 1 ]]; then
    echo "would copy:       ${rel}"
    continue
  fi
  if ! mkdir -p "$(dirname "$dst")"; then
    echo "error: mkdir failed for $(dirname "$dst")" >&2
    exit 1
  fi
  if ! cp "$src" "$dst"; then
    echo "error: copy failed: $src -> $dst" >&2
    exit 1
  fi
  [[ "$dst" == *.sh ]] && chmod +x "$dst" || true
  echo "copied:           ${rel}"
  copied=$((copied + 1))
done

echo ""
if [[ $DRY -eq 1 ]]; then
  echo "(dry-run) 上記をコピーします。実行: $0 ${TARGET}"
  exit 0
fi
echo "完了: copied=${copied} skipped=${skipped}"
echo ""
echo "次の一歩:"
echo "  tools/review/design-audit.sh <generated.html>   # C.R.A.P. 機械監査"
echo "  Claude で /design-review <generated.html>        # 整列/近接の目視レビュー"
