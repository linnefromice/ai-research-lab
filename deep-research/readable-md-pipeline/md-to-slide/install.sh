#!/usr/bin/env bash
#
# install.sh — md-to-slide バンドル (Stage 3) を任意プロジェクトへ持ち込む (冪等)。
#
# Marp スライド化のスキル / ビルドスクリプト / 骨子テンプレを所定位置にコピーする。
#
# 使い方:
#   ./install.sh <target-project-dir>      # コピー実行
#   ./install.sh --dry-run <target-dir>    # 表示のみ
#
# コピー先 (target 配下):
#   .claude/skills/md-to-slide/SKILL.md       スキル本体
#   tools/md-to-slide/build-slides.sh         Marp ビルド (HTML/PDF/PPTX)
#   tools/md-to-slide/slides-marp.md          Marp 骨子テンプレ
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
  "${SRC}/skill/md-to-slide/SKILL.md::${TARGET}/.claude/skills/md-to-slide/SKILL.md::1"
  "${SRC}/scripts/build-slides.sh::${TARGET}/tools/md-to-slide/build-slides.sh::1"
  "${SRC}/templates/slides-marp.md::${TARGET}/tools/md-to-slide/slides-marp.md::0"
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
echo "  1) cd ${TARGET}"
echo "  2) Claude で /md-to-slide <report.md>            # report → slides.md に要約・分割"
echo "  3) tools/md-to-slide/build-slides.sh <slides.md> # HTML ビルド (--all で PDF/PPTX も)"
