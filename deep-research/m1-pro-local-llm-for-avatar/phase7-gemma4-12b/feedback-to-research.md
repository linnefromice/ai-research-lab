# リサーチへのフィードバック — Gemma 4 12B を avatar に載せる検証（2026-06-27 実機）

> **目的**: deep-research トピック「m1-pro-local-llm-for-avatar」で出した
> **Gemma 4 12B 移行プラン（phase7 机上準備）を実機検証したところ、初手の推奨が外れた**。
> その「うまくいかなかった点」と検証で判明した正しい前提をまとめ、**リサーチ repo に戻して
> 再リサーチさせるための入力**とする。この文書は単体で読めるよう自己完結で書いている。

## 0. 一行サマリ

研究の「STEP 1 = LM Studio + `mlx-community/gemma-4-12B-4bit`」は**そのままでは会話不能**だった。
真因は **model ID の取り違え（`-it` 無しの非 instruction-tuned 生ダンプを指していた）** と
**ランタイム前提の欠落**。**`mlx-community/gemma-4-12B-it-4bit` + MLX ランタイム更新**で最終的に
GO になった。つまり結論（Gemma 4 12B は使える）は正しいが、**到達手順の具体が誤っていた**。

## 1. 検証環境（事実）

- ハード: Apple M1 Pro / **32GB**（研究が参照した Gemini 解説は 16GB 前提で、力点がずれていた）
- backend: **LM Studio**（`lms` CLI 同梱）。Ollama は未導入。
- avatar 構成: Open-LLM-VTuber（Live2D）+ WhisperKit(ASR) + VOICEVOX(TTS)。LLM を Swallow 8B から差し替え。

## 2. 「うまくいかなかった点」= 研究が外した/落とした前提

| # | 研究の記述 / 前提 | 実機で起きたこと（検証済み） | 正しい結論 |
|---|---|---|---|
| 1 | **初手 model = `mlx-community/gemma-4-12B-4bit`**（NO-GGUF-on-Mac に合致、と推奨） | ロード後、text chat で `<\|image\|>` `<\|audio\|>` 等の**特殊トークンを吐いて出力崩壊**。どのプロンプト整形でも再現 | **これは `-it`（instruction-tuned）無しの生 unified-multimodal ダンプ**で、会話には使えない。**正しくは `mlx-community/gemma-4-12B-it-4bit`**（6.77GB、text パス）。`-4bit` と `-it-4bit` は別物 |
| 2 | 「Ollama に公式 `gemma4:12b-mlx` が出た → HOLD 解消」 | 手元 LM Studio の **MLX ランタイム 1.6.0 が新アーキ未対応**でロード自体が失敗（`ValueError: Model type gemma4_unified not supported. No module named 'mlx_vlm.models.gemma4_unified'`） | 「公式 MLX タグの存在」＝「自分のランタイムでロードできる」ではない。**ランタイム版の前提**（要 `mlx-llm` 1.9.x 以上）を明記すべき。`lms runtime update` で 1.6.0→1.9.1 にして解決 |
| 3 | （言及なし） | Gemma 4 の MLX quant は **`tokenizer_config.json` に `chat_template` 非同梱**（`-4bit`/`-it-4bit` 共に `has=false`）。これ自体が誤整形 garbage の一因 | Gemma4×MLX で広く既知の問題（[mlx-vlm #941](https://github.com/Blaizzy/mlx-vlm/issues/941)、`<unused24>` garbage と[同根](https://gemma4.dev/errors/gemma-4-unused24-tokens-llama-cpp)）。**ただし LM Studio 1.9.1 は arch 検出で内部テンプレを当てる**ため `-it` 版なら動く。研究はこの落とし穴を事前警告すべき |
| 4 | 「NO Thinking」を要件に挙げた（Qwen を reasoning で TTFT 60s+ により却下した経緯） | Gemma 4 は **thinking/reasoning がデフォルト ON**（[mlx-lm #1352](https://github.com/ml-explore/mlx-lm/issues/1352) 等で reasoning 無限化報告）。今回の既定構成では漏れは観測されず | 懸念の方向は正しいが、**具体的対処 `chat_template_kwargs={"enable_thinking": false}` を手順に入れる**べき。長め multi-turn での再発有無は要追検証 |
| 5 | 「12B は重い → 初音 TTFT が 2.5s budget を割る可能性」 | 実測 warm TTFT = **0.85〜1.07s**（Swallow 8B の warm ~0.91s と同等） | **リスク過大評価だった**。12B でも budget に余裕。`-it-4bit` のメモリは 6.31GiB（32GB で全サービス常駐でも余裕の見込み） |
| 6 | 「persona V2 は約400字で範囲内。3文制約遵守率・過学習傾向を Gemma で再測定」 | 実会話で**応答が"微妙"**（短く当たり障りなし／相談質問でキャラの趣味=お茶・読書に脱線）。persona だけ差し替えた A/B で**モデルではなく persona が原因**と確定 | 研究の「再評価が必要」は当たり。**真因は persona の過剰制約**（`1〜2文・3文以上NG` + 強いキャラ設定）。「相談時のみ 2〜4 文で踏み込む」**条件付き深さ persona** で解決 |

## 3. 最終的に動いた構成（確定値）

- **model: `mlx-community/gemma-4-12B-it-4bit`**（LM Studio 上 id = `gemma-4-12b-it`、ロード 6.31GiB / 11.5s）
- **MLX ランタイム: `mlx-llm-...@1.9.1`**（1.6.0 から更新必須）
- persona: 「普段は1〜2文、相談時のみ2〜4文で具体化」の条件付き版（3つのNO は維持）
- 品質: クリーン日本語 / persona・3つのNO 遵守 / thinking 漏れなし / TTFT 0.85-1.07s

## 4. 再リサーチしてほしい論点（open questions）

1. **Apple Silicon × text-chat で正準の Gemma 4 12B edition はどれか**。候補と品質/速度/サイズの比較を:
   - `mlx-community/gemma-4-12B-it-4bit`（標準・今回採用 / ~11GB DL・ロード6.3GiB）
   - `mlx-community/gemma-4-12B-it-OptiQ-4bit`（text特化・標準4bit比+6.4pt / 要 mlx-lm main で LM Studio 同梱版だと不可の恐れ）
   - GGUF（unsloth / lmstudio-community `gemma-4-12b-it-GGUF`、テンプレ同梱で確実だが MLX 比 1.5-2x 遅）
   - **Ollama `gemma4:12b-it-qat`（Google 公式 QAT, 7.2GB）/ `gemma4:12b-mlx`** ← テンプレ内包で chat_template 欠落を構造的に回避。STEP 2 本命として要評価
2. **chat_template 欠落の上流動向**: mlx-community 側が後日テンプレ同梱版を出すか／どのランタイム版が arch 検出で吸収するか。
3. **enable_thinking の挙動**: ランタイム差・長め multi-turn での reasoning 漏れ有無。avatar の TTFT 予算への影響。
4. **persona 設計の一般則**: 「静かな話し相手（companion）」と「役立つ助言者（assistant）」の両立。
   字数ハード制約はキャラの一貫性に効く一方で実用性を殺す → **状況分岐（雑談/相談）で深さを変える**設計が
   他キャラにも転用できるか。過学習で趣味設定に脱線する傾向の抑え方。
5. **multimodal（native audio/vision）**: text パス `-it` quant は towers 除去済み。WhisperKit を畳む構想は
   別 build（GGUF multimodal 等）が要る → 速度(MLX text) と multimodal の二者択一を改めて整理。

## 5. リサーチ更新時の推奨アクション（提案）

- 元レポートの「STEP 1 model ID」を **`-4bit` → `-it-4bit` に訂正**し、`-it` 有無の意味（instruction-tuned /
  template 同梱可否）を明記する。
- **ランタイム前提（`mlx-llm` ≥ 1.9.x、`gemma4_unified` 対応）を必須事項として追加**。
- 「公式 MLX タグ存在 ≠ ロード可能」「chat_template 欠落」「thinking デフォルト ON」を**既知の落とし穴節**にまとめる。
- 12B の latency リスクは**過大評価だったと下方修正**（実測 0.85-1.07s）。
- persona は**条件付き深さ設計**を推奨パターンとして加える。

---

### 出典 / 一次情報（再リサーチの起点）
- [mlx-vlm #941 — Gemma 4 missing chat_template](https://github.com/Blaizzy/mlx-vlm/issues/941)
- [gemma4.dev — `<unused24>` tokens fix（chat_template 欠落同根）](https://gemma4.dev/errors/gemma-4-unused24-tokens-llama-cpp)
- [mlx-lm #1352 — thinking で content 空になる](https://github.com/ml-explore/mlx-lm/issues/1352)
- [Ollama gemma4 tags（qat / mlx / gguf 一覧）](https://ollama.com/library/gemma4/tags)
- [HF mlx-community/gemma-4-12B-it-OptiQ-4bit](https://huggingface.co/mlx-community/gemma-4-12B-it-OptiQ-4bit)
- 実機検証の詳細ログ: [`./README.md` の「結果メモ」](./README.md#結果メモ)
