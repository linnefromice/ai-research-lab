#!/usr/bin/env bash
#
# render-html.sh — md を「共通テーマ付きスタンドアロン HTML」へ決定論的に変換する。
#
# LLM を使わない CI 向けパス (起点レポート §C-1 ②standalone HTML / §F-3 の自動生成)。
# markdown-it (npx) で md 本文を HTML 化し、assets/report-theme-head.html の <style> を
# <head> に挿入して 1 ファイル完結の HTML を出力する。frontmatter は表示せず title を流用。
#
# リッチな card/box レイアウトが要るときは LLM スキル (skill/md-to-html) を使う。
# こちらは「素の md 構造をテーマ付きで素早く HTML 化」する用途。
#
# 使い方:
#   ./render-html.sh <input.md> [-o <output.html>]
#   既定の出力先は入力と同じディレクトリの同名 .html。
#
# 依存: npx (markdown-it を取得)。日本語フォントは表示環境側に依存。
#
set -euo pipefail

IN=""
OUT=""
expect_out=0
for arg in "$@"; do
  if [[ $expect_out -eq 1 ]]; then OUT="$arg"; expect_out=0; continue; fi
  case "$arg" in
    -o|--output) expect_out=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) IN="$arg" ;;
  esac
done

if [[ -z "$IN" ]]; then
  echo "usage: $0 <input.md> [-o <output.html>]" >&2
  exit 2
fi
if [[ ! -f "$IN" ]]; then
  echo "error: input not found: $IN" >&2
  exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx が無いため md→HTML 変換できない (node を入れるか LLM スキルを使う)" >&2
  exit 1
fi

[[ -z "$OUT" ]] && OUT="${IN%.md}.html"

# テーマ asset を探す (バンドル: ../assets/、install 後: 同階層)
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
THEME=""
for cand in \
  "${script_dir}/../assets/report-theme-head.html" \
  "${script_dir}/report-theme-head.html" \
  "${script_dir}/../report-theme-head.html"; do
  if [[ -f "$cand" ]]; then THEME="$cand"; break; fi
done
if [[ -z "$THEME" ]]; then
  echo "error: report-theme-head.html が見つからない" >&2
  exit 1
fi

TMPBODY="$(mktemp)"
TMPMD="$(mktemp --suffix=.md)"
trap 'rm -f "$TMPBODY" "$TMPMD"' EXIT

# frontmatter を除去 (1 行目が --- なら次の --- まで)。title を控える。
title=""
awk '
  NR==1 && $0=="---" { in_fm=1; next }
  in_fm && $0=="---" { in_fm=0; next }
  in_fm { next }
  { print }
' "$IN" > "$TMPMD"

# title: frontmatter > 最初の # 見出し > ファイル名
title="$(awk '
  NR==1 && $0=="---" { in_fm=1; next }
  in_fm && $0=="---" { exit }
  in_fm && /^title:/ {
    sub(/^title:[[:space:]]*/, "")
    gsub(/^"|"$/, "")
    print; exit
  }
' "$IN")"
if [[ -z "$title" ]]; then
  title="$(awk '/^# / { sub(/^# /, ""); print; exit }' "$TMPMD")"
fi
[[ -z "$title" ]] && title="$(basename "${IN%.md}")"

# title を HTML エスケープ (< > & が <title> を壊さないように。& を先に)
# sed を使う: bash 5.2 の ${var//pat/&...} は & を「マッチ文字列」と解釈し壊れるため。
esc_title="$(printf '%s' "$title" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g')"

# 本文を HTML 化 (html:false 既定 = 生 HTML をエスケープ。コードブロック内 <script> 対策)
if ! npx --yes markdown-it "$TMPMD" > "$TMPBODY"; then
  echo "error: markdown-it 変換に失敗" >&2
  exit 1
fi

# HTML 組み立て (theme の <style> を head に逐語挿入)
{
  echo '<!DOCTYPE html>'
  echo '<html lang="ja">'
  echo '<head>'
  echo '<meta charset="UTF-8">'
  echo '<meta name="viewport" content="width=device-width, initial-scale=1.0">'
  printf '<title>%s</title>\n' "$esc_title"
  cat "$THEME"
  echo '</head>'
  echo '<body>'
  echo '<div class="container">'
  cat "$TMPBODY"
  echo '</div>'
  echo '</body>'
  echo '</html>'
} > "$OUT"

echo "rendered: ${OUT}"
echo "  title:  ${title}"
echo "  theme:  ${THEME#${script_dir}/}"
echo ""
echo "PDF 化 (任意・要 chromium): chromium --headless --no-sandbox --print-to-pdf=${OUT%.html}.pdf ${OUT}"
