# phase4b-llm-stream-chunker

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/05-phase4-implementation-log.md`
- 該当節:
  - 「Phase 4b への引き継ぎ事項 → 必須 2: LLM stream chunker (C)」
  - 「§2 計測値 run 1 の 3 文制約違反 (system prompt: 3 文以上 NG)」
  - 「主要な発見 4. 3 文制約違反は通常会話で reproduce → Phase 4b chunker の必要性が確定」
- トピック README: [../README.md](../README.md)

## 目的

LLM の stream 出力を `。/！/？/〜` で文単位に split し、**1 文目完成と同時に TTS 起動**
することで体感 latency を隠蔽する。同時に multi-turn の history 管理も再設計する。

**Phase 4a で確定した動機**: §2 run 1 で「おはよう、キミ。私は元気ですよ。**あなたも
良い一日を過ごしてくださいね。**」が出現 (3 文 + 一人称揺れ)。改名後・新 system prompt 後
でも再現したため、**system prompt の強化では根本解決しない** ことが確定。生成側でなく
表示/再生側で対処する。

## 実装 — `chunker.py`

stdlib のみで動く Python 単体 PoC (urllib + threading + queue + subprocess)。
追加 install 不要。

```python
SENTENCE_END = "。！？〜"

# LM Studio stream で delta を受けつつ buffer に貯め、
# 句読点を見つけたら 1 文として yield。
# main は 1 文ごとに VOICEVOX で synth → queue.put → 別 thread で afplay。
```

ファイル: [`./chunker.py`](./chunker.py)

## 実行方法

前提:
- VOICEVOX 起動済 (port 50021 / `8 春日部つむぎ:ノーマル`)
- LM Studio 起動済 (port 1234 / Llama-3.1-Swallow-8B-Instruct-v0.5-4bit ロード)

```bash
# i. print のみ (split 動作確認)
python3 chunker.py "おはよう"

# ii. VOICEVOX で読み上げ
python3 chunker.py "おはよう" --tts

# iii. latency bench (prompt 送信からの ms)
python3 chunker.py "おはよう" --tts --bench
```

環境変数で上書き可能:
- `LM_URL` (default `http://127.0.0.1:1234/v1`)
- `VOICEVOX_URL` (default `http://127.0.0.1:50021`)
- `SPEAKER_ID` (default `8` = 春日部つむぎ:ノーマル)
- `SYSTEM_PROMPT` (default Phase 4a ナオ版)

## 検証項目

- 1 文目 play_start latency: prompt 送信 → 最初の音が出るまで
  - 内訳: LLM TTFT + 1 文目生成 + VOICEVOX synth + afplay 起動
  - 目標: Phase 4a ASR + LLM TTFT 中央値 1.639s + VOICEVOX 534ms = 約 2.2s 想定
- **3 文以上生成された場合の扱い (iv 完了)**:
  - **採用: 案 A 打ち切り** (`--max-sentences N` で N 文目以降の synth/play を抑止し、LLM stream も generator break で abort)
  - voice_to_avatar の default は `MAX_SENTENCES=2` (Phase 4a 「3 文以上 NG」)
  - 案 B フェードアウト / 案 C 全部再生は実装せず (案 A で目的達成)
- multi-turn で history を保持しつつ context を肥大化させない方針 (未実装、v)
- character drift / 一人称揺れ を fewshot で抑制 (未実装、vi)

## 結果メモ

### 2026-04-29 実機ラン (M1 Pro 32GB, prompt="おはよう")

```
  n    ttft  sent_done   synth   ready  play_start
  1     585        693     508    1202        1202
  2     585       1202     623    1825        4186
```

- **1 文目 play_start = 1202ms** (prompt 送信から最初の音まで)
  - 内訳: LLM TTFT 585ms + sentence 1 生成 108ms + VOICEVOX synth 508ms
  - + ASR (Phase 4a 約 700ms) を足すと **発話終了から初音まで ~1.9s**
- **chunker による短縮効果 ≈ 1100ms** (全文 LLM 完了待ち比)
  - chunker なし推定: TTFT 585 + 全文生成 1202 + 全文 synth ~500 = 2287ms
  - chunker あり: 上記 1202ms
- **TTFT cold→warm**: 1363ms (1 回目) → 386ms (2 回目) → 585ms (3 回目)
  - Phase 4a の warmup_llm 推奨と整合
- **3 文制約違反**: 3 run 全て 2 文以内、本セッションでは未観測 (Phase 4a §2 と同様、確率的事象)

### 設計上の所見

- queue + thread の playback 直列化は意図通り動作 (sentence 2 の play_start は sentence 1 の再生完了を待つ)
- chunker overhead 自体は誤差レベル (split は数 µs/chunk)
- 並行性の余地: synth を per-sentence 並列、playback のみ直列にすれば sentence 2 の `ready_ms` を短縮可能 (PoC では未実装)

### iv 検証 (2026-04-29、prompt = "おはようございます今日は元気ですか")

Phase 4a §2 で「確率事象」とされた 3 文違反は、**朝挨拶系 prompt では 2/2 run で再現** (確率事象ではなく強い誘発条件)。

| run | --max-sentences | 出力 | 状態 |
|---|---|---|---|
| 1 | (none) | 3 文「おはようございます。私はいつも通り、穏やかに過ごしています。キミは今日、何か楽しい予定はありますか？」 | 3 文違反 |
| 2 | (none) | 3 文「おはよう。私はいつも通りです、キミ。お元気ですか？」 | 3 文違反 |
| 3 | 2 | 2 文「おはよう、キミ。私は元気ですよ。」 | ✅ クリーン停止 |
| 4 | 2 | 2 文「おはようございます。私はいつも通り、穏やかに過ごしています。」 | ✅ クリーン停止 |

→ 案 A (打ち切り) を採用。`voice_to_avatar` で default `MAX_SENTENCES=2` 有効化済。

### vi 検証 (2026-04-29、fewshot ON/OFF A/B)

`FEWSHOT_EXAMPLES` (4 pair、~150 chars) を messages として system + user の間に挿入。
`--no-fewshot` で無効化可能 (default ON)。

| run | fewshot | prompt | 出力 | 一人称揺れ | 物静か |
|---|---|---|---|---|---|
| 1 | ON | おはよう...元気ですか | 「んー、おはよう。まあ、いつもよりちょっと元気かな？」 | なし | ✓ |
| 2 | ON | 同上 | 「おはよう。まあ、いつもよりちょっとだけ元気かもね。」 | なし | ✓ |
| 3 | ON | 週末は何してましたか | 「うーん、家で映画を見てたよ。静かに過ごすのが好きだから。」 | なし | ✓ |
| 4 | OFF | 同上 | 「んー、あまり詳しくないかも。最近は、部屋でゆっくりアニメを見たり、本を読んだりして過ごすことが多いかな。」 | なし | ✓ (文長め) |

→ 採用 (default ON)。「あなた」混入は test set 全件で観測されず、効果は文長コンパクト化と
キャラ説明 (「静かに過ごすのが好きだから」) の自然な挿入に表れる。
TTFT への影響は fewshot ON warm 509-898ms / OFF 873ms で誤差レベル。

**所見**: iv (max-sentences=2) が間接的に「あなた」混入を防いでいる構造あり。
Phase 4a §2 の一人称揺れは **3 文目以降に集中** していた可能性 (cap=2 で表示されない)。
vi は補強として有効。

### v 検証 (2026-04-29、multi-turn flow)

実装: `~/.cache/avatar-chunker-history.json` に file-based session、`HISTORY_MAX_TURNS=5`
で古い turn 切り捨て。format は OpenAI/Anthropic 互換の `[{role, content}, ...]`。

flag:
- `--reset` 履歴クリア (prompt 省略可)
- `--no-history` 履歴を読まず保存もしない (single-shot)

shell: `reset_avatar` 関数 (avatar-helpers.sh) で履歴クリア。

検証 (2 turn の文脈継続):

| turn | prompt | response | 文脈継続 |
|---|---|---|---|
| 1 | 好きなアニメ教えて | 「日常系なら『ゆるキャン△』とか好きかな。ほら、可愛い犬も出てくるし。」 | (新規) |
| 2 | それの何が好き？ | 「んー、キャンプの雰囲気が良いかな。自然の中で過ごすのが好きだから。」 | ✅ 「それ」=ゆるキャン△、キャンプの話で応答 |

→ 採用 (default ON、`--no-history` で OFF)。

設計判断:
- Long-running session ではなく毎回 spawn + file IO: avatar-helpers.sh の API を変えずに済む
- summarize は不要 (Llama 3.1 8B = 128k context、5 turn で ~1000 token 余裕)
- file format はそのまま LM Studio API request body に流せる (pipeline 書き戻し時の翻訳コストゼロ)

### 残課題 (Phase 4b の C 残り)

(なし — v 完了で C は全項目クローズ)

## 採用後の統合先

[phase4b-tts-bench/](../phase4b-tts-bench/) の結果と合わせて、
[`../avatar-helpers.sh`](../avatar-helpers.sh) の `voice_to_llm` を
「LLM stream + chunker + TTS」まで一気通貫する拡張版に書き換える。
Phase 4b 期間中は lab 側 SoT で編集し、Phase 4b 完了時に pipeline へ書き戻す
(運用方針は [../README.md §運用方針](../README.md))。
