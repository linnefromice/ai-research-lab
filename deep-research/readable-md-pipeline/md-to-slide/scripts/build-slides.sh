#!/usr/bin/env bash
#
# build-slides.sh — Marp の slides.md を HTML / PDF / PPTX に決定論ビルドする。
#
# 起点レポート §D-3 (発表→配布の二面性) / §F-3 (CI 自動生成)。marp-cli を npx で実行。
# HTML は chromium 不要。PDF / PPTX は内部でブラウザを使うため、未導入環境では
# その旨を報告して skip する (無理に入れない方針)。
#
# 使い方:
#   ./build-slides.sh <slides.md>            # HTML のみ (既定)
#   ./build-slides.sh <slides.md> --pdf      # + PDF (要 chromium)
#   ./build-slides.sh <slides.md> --pptx     # + PPTX (要 chromium)
#   ./build-slides.sh <slides.md> --all      # HTML + PDF + PPTX
#   ./build-slides.sh <slides.md> -o <dir>   # 出力先ディレクトリ (既定: slides.md と同階層の dist/)
#
set -euo pipefail

IN=""
OUTDIR=""
WANT_PDF=0
WANT_PPTX=0
expect_out=0
for arg in "$@"; do
  if [[ $expect_out -eq 1 ]]; then OUTDIR="$arg"; expect_out=0; continue; fi
  case "$arg" in
    --pdf)  WANT_PDF=1 ;;
    --pptx) WANT_PPTX=1 ;;
    --all)  WANT_PDF=1; WANT_PPTX=1 ;;
    --html) : ;;  # 既定で常に出すので no-op
    -o|--output) expect_out=1 ;;
    -h|--help) grep '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) IN="$arg" ;;
  esac
done

if [[ -z "$IN" ]]; then
  echo "usage: $0 <slides.md> [--pdf] [--pptx] [--all] [-o <dir>]" >&2
  exit 2
fi
if [[ ! -f "$IN" ]]; then
  echo "error: input not found: $IN" >&2
  exit 1
fi
if ! command -v npx >/dev/null 2>&1; then
  echo "error: npx が無いため Marp ビルドできない (node を入れる)" >&2
  exit 1
fi

base="$(basename "${IN%.md}")"
[[ -z "$OUTDIR" ]] && OUTDIR="$(cd "$(dirname "$IN")" && pwd)/dist"
mkdir -p "$OUTDIR"

# chromium 検出 (PDF/PPTX 用)。CHROME_PATH 優先、無ければ既知コマンドを探す。
find_chromium() {
  if [[ -n "${CHROME_PATH:-}" && -x "${CHROME_PATH}" ]]; then echo "$CHROME_PATH"; return 0; fi
  local c
  for c in chromium chromium-browser google-chrome google-chrome-stable; do
    if command -v "$c" >/dev/null 2>&1; then command -v "$c"; return 0; fi
  done
  return 1
}

run_marp() {
  # $@ をそのまま marp-cli に渡す。HTML 専用なので chromium DL は止める。
  # --no-stdin: 非 TTY (CI / バックグラウンド) で stdin 待ちハングを防ぐ。
  PUPPETEER_SKIP_DOWNLOAD=1 PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1 \
    npx --yes @marp-team/marp-cli --no-stdin "$@"
}

made=()

# --- HTML (常に・chromium 不要) ------------------------------------------
html_out="${OUTDIR}/${base}.html"
echo "── HTML ..."
if run_marp "$IN" --html -o "$html_out"; then
  made+=("$html_out")
  echo "  ✓ ${html_out}"
else
  echo "  ✗ HTML ビルド失敗" >&2
  exit 1
fi

# --- PDF / PPTX (要 chromium) --------------------------------------------
if [[ $WANT_PDF -eq 1 || $WANT_PPTX -eq 1 ]]; then
  if chrome="$(find_chromium)"; then
    export CHROME_PATH="$chrome"
    echo "  (chromium: ${chrome})"
    if [[ $WANT_PDF -eq 1 ]]; then
      pdf_out="${OUTDIR}/${base}.pdf"
      echo "── PDF ..."
      if run_marp "$IN" --pdf --allow-local-files -o "$pdf_out"; then
        made+=("$pdf_out"); echo "  ✓ ${pdf_out}"
      else
        echo "  ✗ PDF ビルド失敗 (chromium 起動を確認)" >&2
      fi
    fi
    if [[ $WANT_PPTX -eq 1 ]]; then
      pptx_out="${OUTDIR}/${base}.pptx"
      echo "── PPTX ..."
      if run_marp "$IN" --pptx --allow-local-files -o "$pptx_out"; then
        made+=("$pptx_out"); echo "  ✓ ${pptx_out}"
      else
        echo "  ✗ PPTX ビルド失敗 (chromium 起動を確認)" >&2
      fi
    fi
  else
    echo "── PDF/PPTX: chromium が見つからないため skip" >&2
    echo "   HTML をブラウザで開き Ctrl+P → PDF 保存、または chromium を入れて再実行" >&2
    echo "   (CHROME_PATH=/path/to/chromium を指定しても可)" >&2
  fi
fi

echo ""
echo "完了: ${#made[@]} ファイル"
for f in ${made[@]+"${made[@]}"}; do echo "  - $f"; done
