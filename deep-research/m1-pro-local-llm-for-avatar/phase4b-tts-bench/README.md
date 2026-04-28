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

## 実行方法 (TBD)

```bash
# 0. avatar-helpers.sh を source (TTFT 計測の基本セット)
source ../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/avatar-helpers.sh

# 1. 各 TTS のサーバ起動 / インストール手順を README に記録
# 2. 1 文 ("元気だよ〜!") を 5 回ずつ実行し初音 latency を測る
#    - VOICEVOX: docker run + curl /audio_query → /synthesis
#    - AivisSpeech: ?
#    - Qwen3-TTS: WhisperKit serve 経由?
# 3. results.md に表で記録
```

## 結果メモ (TBD)

| TTS | voice | 初音 latency (median) | RTF | 主観評価 |
|---|---|---|---|---|
| VOICEVOX | | | | |
| AivisSpeech | | | | |
| Qwen3-TTS | | | | |

**採用**: TBD

## 採用後の統合先

`avatar-helpers.sh` の `voice_to_llm` を「LLM stream → TTS」までつなぐ拡張版に
書き換える (隣の [phase4b-llm-stream-chunker/](../phase4b-llm-stream-chunker/) と一緒)。

統合は pipeline 側で別 PR (lab 改造ではなく pipeline の `avatar-helpers.sh` を更新)。
