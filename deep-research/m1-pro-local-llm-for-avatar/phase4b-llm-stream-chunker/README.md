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

## 仮実装方針 (TBD)

```python
# OpenAI compat streaming で LLM の delta を受けつつ
# buffer に貯めて句読点が来たら 1 文として TTS に渡す
SENTENCE_END = "。！？〜"

buffer = ""
async for chunk in llm_stream:
    buffer += chunk.delta
    while sentence_complete(buffer):
        sentence, buffer = split_at_first_end(buffer, SENTENCE_END)
        await tts_play(sentence)  # 1 文目を再生 → LLM はまだ生成中
```

## 検証項目

- 1 文目 TTS 起動までの追加 latency < 100ms (chunker のオーバヘッド)
- 3 文以上生成された場合の扱い:
  - 案 A: 打ち切り (n 文目以降を捨てる、生成自体も abort)
  - 案 B: フェードアウト (TTS の volume を下げて自然に終わる)
  - 案 C: 全部再生 (隠蔽せず流す)
- multi-turn で history を保持しつつ context を肥大化させない方針
  - 何ターン保持するか
  - summarize するか truncate するか
- character drift (「物静か」キャラ → 前向き締め「頑張りましょうね」「散歩が好きですか?」)
  を fewshot で抑制できるか
  - 一人称揺れ (「キミ」指定なのに「あなた」混入) も同じ fewshot で対処

## 実行方法 (TBD)

```bash
# 0. avatar-helpers.sh を source
source ../../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/avatar-helpers.sh

# 1. chunker の最小実装を Python or Node で書く
# 2. 既知の "3 文出力" を再現するプロンプトで chunker をテスト
# 3. TTS と組み合わせて E2E で 1 文目再生開始までの latency を測る
```

## 結果メモ (TBD)

- chunker overhead: 
- 3 文制約違反時の体感: 
- multi-turn history 設計: 
- fewshot character drift 抑制: 
- 採用方針: 

## 採用後の統合先

[phase4b-tts-bench/](../phase4b-tts-bench/) の結果と合わせて、pipeline 側の
`avatar-helpers.sh` の `voice_to_llm` を「LLM stream + chunker + TTS」まで一気通貫
する拡張版に書き換える (pipeline 側で別 PR)。
