# phase4b-tts-bench

## 起点

- レポート: `../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/05-phase4-implementation-log.md`
- 該当節: 「Phase 4b への引き継ぎ事項 → 必須 1: TTS 候補比較ベンチ (B)」
- トピック README: [../README.md](../README.md)

## 目的

M1 Pro 32GB 実機で TTS 候補を 1 文の **初音 latency** で比較し、ナオ (物静かな
キャラ) に合う voice を選定する。

**budget**: 初音 latency < 700ms (avatar の対話テンポを保つため)

## 候補

| TTS | Phase 4a 時点の想定 latency | 物静か voice 候補 | 備考 |
|---|---|---|---|
| **VOICEVOX** | 200-500 ms | TBD | 軽量・無料・複数キャラ |
| **AivisSpeech** | 300-700 ms | TBD | Phase 4a レポート (`reports/m1-pro-local-llm-for-avatar.md`) の暫定推奨 |
| **WhisperKit Qwen3-TTS** | TBD | TBD | LLM と同じ MLX スタックで動かせるなら統合性が高い |

## 評価項目

- **初音 latency**: TTS にテキストを渡してから最初の音が出るまで (1 文 "元気だよ〜!" で 5 試行、中央値)
- **連続音声**: 1 文を最後まで再生する所要時間 (RTF)
- **声質適合**: ナオ (物静か / 落ち着いた / 控えめ) の SYSTEM_PROMPT に合うか主観評価
- **CPU/GPU 負荷**: LLM と同居して E2E (ASR + LLM + TTS) で degradation するか

## 計測テキスト

`"んー、おはようございます。"` (Phase 4a §4 で実機に出た発話。物静かキャラのトーンと一致)

## 実行方法

```bash
# 0. avatar-helpers.sh を source (TTFT 計測の基本セット — 本 bench 自体は使わない)
source ../avatar-helpers.sh

# --- VOICEVOX ---
# 1. engine 起動 (M1: arm64 image)
docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest

# 2. 全 speaker dump (候補選定のため)
curl -sS http://127.0.0.1:50021/speakers > voicevox-speakers.json

# 3. bench 実行 (default: SPEAKER_ID=3 ずんだもん:ノーマル)
./bench-voicevox.sh

# 4. 候補 voice を sweep
for spk in 60 59 56 8 80; do
  echo "=== speaker_id=${spk} ==="
  SPEAKER_ID=$spk ./bench-voicevox.sh
done

# 5. 主観評価のため WAV を再生 (audio/ に保存される、gitignore 対象)
afplay audio/voicevox-spk60-trial1.wav
```

## 結果メモ

### VOICEVOX 0.25.1 (cpu-arm64, M1 Pro 32GB) — 2026-04-29

text = `"んー、おはようございます。"`、5 trials、中央値 (ms)。
warmup 1 回後の計測値。Engine は warm 状態のみ (cold 起動は別)。

| ID | speaker | style | query_ms | synth_ms | total_ms | budget < 700ms |
|---|---|---|---|---|---|---|
| 60 | 猫使ビィ | 人見知り | 18 | 526 | **543** | ✅ |
| 59 | 猫使ビィ | おちつき | 21 | 519 | **538** | ✅ |
| **56** | 猫使アル | おちつき | 19 | 478 | **499** | ✅ (最速) |
| 8 | 春日部つむぎ | ノーマル | 20 | 515 | **534** | ✅ |
| 80 | もち子さん | のんびり | 21 | 722 | **743** | ❌ |

参考 (default ベースライン):

| ID | speaker | style | total_ms |
|---|---|---|---|
| 3 | ずんだもん | ノーマル | 597 |

**所見**:
- VOICEVOX 単体では候補 5 件中 4 件が budget 内 (478-543ms)。`もち子さん:のんびり (80)` は明らかに重い (おそらく speaker 個別 acoustic model の差)
- `query_ms` は全 voice で 17-27ms とほぼ一定 (engine 内 lookup だけなので想定通り)
- `synth_ms` の voice 間差は 478-526ms (~48ms)。同 voice 内 trial 間ばらつきは ±15ms 程度
- 数値だけで判断するなら **猫使アル:おちつき (56)** が最速。ただし最終判断は声質評価 (人見知りキャラへの適合) を優先

**主観評価** (2026-04-29):
- 4 候補 (`56 / 59 / 60 / 8`) を `afplay` で聴き比べ
- **VOICEVOX 内 voice 確定: `8 春日部つむぎ:ノーマル` (total_ms 534)**
- 数値最速の `56 猫使アル:おちつき (499ms)` ではなく `8` を選んだ理由はユーザー主観 (ナオの「物静か / 落ち着いた優しいトーン」と適合)
- ささやき / けだるげ / こわがり 系は未試聴 (現候補で十分と判断)

### AivisSpeech (TBD)
### WhisperKit Qwen3-TTS (TBD)

### 横並び (3 TTS が揃ったら埋める)

| TTS | voice | 初音 latency (median) | RTF | 主観評価 |
|---|---|---|---|---|
| VOICEVOX | 8 春日部つむぎ:ノーマル | 534ms | TBD | ✅ 採用候補 |
| AivisSpeech | | | | |
| Qwen3-TTS | | | | |

**採用**: TBD

## 採用後の統合先

[`../avatar-helpers.sh`](../avatar-helpers.sh) の `voice_to_llm` を「LLM stream → TTS」
までつなぐ拡張版に書き換える (隣の [phase4b-llm-stream-chunker/](../phase4b-llm-stream-chunker/)
と一緒)。Phase 4b 期間中は lab 側 SoT で編集し、Phase 4b 完了時に pipeline へ書き戻す
(運用方針は [../README.md §運用方針](../README.md))。
