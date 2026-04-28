# whisperkit-prompt-bug-repro

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/05-phase4-implementation-log.md`
- 該当節:
  - 「主要な発見 1. WhisperKit serve の `prompt` field 実装は壊れている (upstream issue 候補)」
  - 「Phase 4b への引き継ぎ → 観察された Phase 4 scope 外項目 → WhisperKit `prompt` field upstream issue」
- トピック README: [../README.md](../README.md)

## 目的

**Japanese audio + 句点で終わる prompt → 空 transcript** という WhisperKit serve の
バグを最小再現する 1 ファイルのリポを作り、`argmaxinc/WhisperKit` に upstream issue
を投稿する。

Phase 4a (M1 Pro 実機 / large-v3-v20240930_turbo) で確定した症状:

| prompt | result.text | tokens の異常 |
|---|---|---|
| (none) | "こんにちは皆さん今日はとてもいい天気だね" | 正常 (16 token、コンテンツ含む) |
| "ミナ" | 同上 | 効果ゼロ — token 列が prompt 無しと完全一致 |
| "Mina" | "こんにちはみなさん今日はとてもいい天気だね" | hiragana shift のみ (43791 → 11362+3203+15567) |
| "ミナと話す会話。" | "" | `[SOT, ja, transcribe, ts, EOT]` の **5 token のみ**で decoder 即終了 |

## 仮説

WhisperKit が prompt を `<|startofprev|>` ではなく `<|startoftranscript|>` の
**後ろ** に挿入している可能性が高い。

期待 (OpenAI Whisper API 仕様):

```
input:  <|startofprev|> [prompt tokens] <|startoftranscript|> <|ja|> <|transcribe|> [ts] [audio frames] ...
output: <|startoftranscript|> <|ja|> <|transcribe|> <|0.00|> [content tokens] <|endoftext|>
```

prompt は decoder の prefix context として置かれ、**出力には現れず** style/vocabulary を
bias する。Phase 4a 実測では prompt 自体が transcript の一部として decoder に渡って
いる挙動。句点 (。) で終わる prompt は「transcript が完了した」と decoder に解釈されて
即終了する。

## 実行方法 (TBD)

```bash
# 1. 最小再現の wav を生成 (Kyoko voice、約 4s)
say -v Kyoko -o test.aiff "こんにちは、ミナさん。今日はとてもいい天気だね。"
# aiff -> wav 変換 (ffmpeg or sox)
sox test.aiff -r 16000 -c 1 test.wav

# 2. WhisperKit serve を起動 (large-v3 turbo)
#    avatar-helpers.sh の asr_serve_start を流用してよい
source ../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/avatar-helpers.sh
asr_serve_start

# 3. 4 条件で投げて verbose_json で token 列を記録
URL=http://127.0.0.1:8080/v1/audio/transcriptions
curl -F file=@test.wav -F language=ja -F response_format=verbose_json                              "$URL" | jq .
curl -F file=@test.wav -F language=ja -F response_format=verbose_json -F prompt="ミナ"             "$URL" | jq .
curl -F file=@test.wav -F language=ja -F response_format=verbose_json -F prompt="Mina"             "$URL" | jq .
curl -F file=@test.wav -F language=ja -F response_format=verbose_json -F prompt="ミナと話す会話。" "$URL" | jq .

# 4. 各条件の結果を結果メモに貼り付け
```

実 URL とパラメータは `avatar-helpers.sh` の `asr_latency` / `asr_debug` を読んで合わせる。

## 投稿先

- リポ: https://github.com/argmaxinc/WhisperKit
- タイトル案: `prompt field on Japanese audio: trailing 。 causes empty transcript`
- 本文に含めるもの:
  - 環境 (macOS Sequoia 15.7.3 / M1 Pro / large-v3-v20240930_turbo)
  - 4 条件の verbose_json (token 列)
  - 仮説 (`<|startofprev|>` 不在の疑い)
  - 最小再現リポへのリンク (このディレクトリを GitHub Gist or 別 public repo に切り出す案)

## 結果メモ (TBD)

- 4 条件の token 列再現: 
- 仮説の追加証拠: 
- issue URL: 
- WhisperKit メンテナの応答: 
