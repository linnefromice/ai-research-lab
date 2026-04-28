# Bash ベストプラクティス

シェルスクリプト作成時に適用するルール。このプロジェクトで繰り返し遭遇した問題から導出。

---

## 変数展開

### マルチバイト文字の直後

`$VAR` の直後に日本語の全角文字（`）`、`」` 等）が続くと、bash がそれを変数名の一部と解釈する。`set -u` 環境では `unbound variable` エラーになる。

```bash
# ❌ BAD
echo "本日（$REPORT_DATE）のレポート"

# ✅ GOOD
echo "本日（${REPORT_DATE}）のレポート"
```

**ルール:** 変数展開の直後にマルチバイト文字が続く可能性がある場合は、常に `${VAR}` とブレースで囲む。

---

## 文字列トリム

### xargs を使わない

`xargs` はシングルクォート・ダブルクォートを特殊文字として扱うため、日本語テキスト（例: `Lil'Log`）でエラーになる。

```bash
# ❌ BAD
line="$(echo "$line" | xargs)"

# ✅ GOOD — 純粋な bash パラメータ展開
line="${line#"${line%%[![:space:]]*}"}"   # trim leading
line="${line%"${line##*[![:space:]]}"}"   # trim trailing
```

---

## set -euo pipefail との組み合わせ

### [[ ]] && action パターン

`set -e` 環境では `[[ condition ]] && action` が false の場合にスクリプトが終了する。

```bash
# ❌ BAD — condition が false だとスクリプトが exit 1 で終了
[[ -n "$last_log" ]] && echo "Log: $last_log"

# ✅ GOOD
[[ -n "$last_log" ]] && echo "Log: $last_log" || true

# ✅ GOOD — if 文を使う
if [[ -n "$last_log" ]]; then
  echo "Log: $last_log"
fi
```

---

## 一時ファイル管理

### mktemp + trap を使う

`/tmp/固定名` ではなく `mktemp` + `trap EXIT` で安全に管理する。

```bash
# ❌ BAD
curl ... > /tmp/curl_code
# 処理
rm -f /tmp/curl_code

# ✅ GOOD
TMPFILE=$(mktemp)
trap "rm -f '$TMPFILE'" EXIT
curl ... > "$TMPFILE"
# 処理（trap が自動でクリーンアップ）
```

---

## 並行実行時の git 操作

複数プロセスが同じリポジトリで同時に `git pull` や `git commit/push` すると競合する。

**ルール:**
- 並行実行する場合は `--skip-pull` と `--skip-git` オプションを用意する
- 呼び出し元（`manage.sh run-all`）が事前に1回だけ pull し、全完了後に1回だけ commit/push する

---

## launchd 環境の PATH

launchd は対話シェル（`.zshrc` 等）を読み込まないため、fnm / nvm / volta 等で管理されたコマンドが PATH に入らない。

**ルール:**
- launchd plist の `EnvironmentVariables > PATH` に必要なパスを含める
- `.env` に `FNM_NODE_BIN` 等の変数を定義し、plist 生成時に参照する
- `manage.sh register` で `load_env` を呼び、`.env` の値を plist に反映する

```bash
# launchd.sh の PATH 生成例
<string>${FNM_NODE_BIN:+${FNM_NODE_BIN}:}/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>
```

---

## git pull のリモート・ブランチ明示

launchd 環境では `~/.gitconfig` のブランチ追跡設定が効かない場合がある。`git pull --ff-only` が `Cannot fast-forward to multiple branches` で失敗する。

```bash
# ❌ BAD — launchd 環境でリモート/ブランチが解決できない
git -C "$path" pull --ff-only

# ✅ GOOD
git -C "$path" pull --ff-only origin main
```

---

## 巨大データの外部コマンド渡し

シェル変数の値が大きい場合（数十KB〜）、`jq --arg` や `curl -d "$data"` は ARG_MAX（macOS: 1MB）に達して失敗する。

```bash
# ❌ BAD — ARG_MAX を超えるとサイレントに失敗
payload=$(jq -n --arg content "$huge_text" '{content: $content}')
curl -d "$payload" ...

# ✅ GOOD — ファイル経由で渡す
printf '%s' "$huge_text" > "$tmpfile"
jq -n --rawfile content "$tmpfile" '{content: $content}' > "$payload_file"
curl -d @"$payload_file" ...
```

---

## エラーハンドリング

ファイル書き込みや外部コマンドの実行は、失敗時のガードを入れる。

```bash
# ❌ BAD
echo "$content" > "$path"
launchctl load "$path"

# ✅ GOOD
if ! echo "$content" > "$path"; then
  echo "Error: Failed to write $path" >&2
  return 1
fi
if ! launchctl load "$path"; then
  echo "Error: Failed to load $path" >&2
  rm -f "$path"
  return 1
fi
```

---

## 空配列の展開 (set -u トラップ)

`set -u` が有効な bash (< 4.4 相当) で空配列を `"${arr[@]}"` で展開すると
`unbound variable` エラーで即時終了する。引数なしで呼ばれるエントリポイントに
よく潜む (過去に `./manage.sh run tech-trends` が追加引数なしで即死した PR #133 事例)。

```bash
# ❌ BAD — 空配列で死ぬ
local extra_args=()
for arg in "$@"; do extra_args+=("$arg"); done
node cli.js "${extra_args[@]}"   # extra_args が空だと unbound variable

# ✅ GOOD — ${arr[@]+"${arr[@]}"} は set かつ非空の時だけ展開
node cli.js ${extra_args[@]+"${extra_args[@]}"}
```

**ルール:** `set -euo pipefail` のスクリプトで配列を `"$@"` 形式で他プロセスに
渡すときは、必ず `${arr[@]+"${arr[@]}"}` のイディオムを使う。

### なぜ shellcheck / `bash -n` で検出できないか

- `bash -n` は syntax チェックのみで runtime 展開は評価しない
- shellcheck は `SC2145` 等で部分的に警告するが、このパターンは警告対象外
- 実際の引数 0 件で手元実行するまで気づけない

**予防:** 新規スクリプトを merge する前に **引数なしで 1 回手動実行する**。
CI で smoke test できる場合は空引数パスをカバーする。

---

## BSD awk は `-v` で改行を受け付けない

macOS 標準の BSD awk は `-v varname="multi\nline"` で改行を含む値を渡すとエラー:

```
awk: newline in string ... at source line 1
```

bash 変数に複数行の payload を持って awk に渡したい場合は **環境変数経由** で:

```bash
# ❌ BAD — BSD awk で improved string error
awk -v payload="$MULTI_LINE_VAR" '...'

# ✅ GOOD — ENVIRON[] で取得
PAYLOAD="$MULTI_LINE_VAR" awk '
  BEGIN { payload = ENVIRON["PAYLOAD"] }
  ...
'
```

gawk (GNU awk) は `-v` で改行を扱える。Linux CI で通って macOS 開発機で落ちるパターンに
なりやすいので、クロス環境前提のスクリプトは常に `ENVIRON[]` を使う方が無難。

実例: `shared/lib/enhance-goal-merge.sh` の merge awk は `NEW_SCOPE` / `NEW_HINTS` を環境
変数で渡している (PR #164 で macOS 実行時に踏んだ)。
