# phase7-gemma4-12b

AI avatar「ナオ」の LLM を **Gemma 4 12B**（2026-06-03 リリース、encoder-free unified
multimodal）で運用する準備。Phase 4a で確定した `Llama-3.1-Swallow-8B-Instruct-v0.5-4bit`
からの差し替え検討。

## 起点
- 現構成: [`../README.md`](../README.md) §現在の確定構成（LLM = Swallow 8B on LM Studio :1234）
- backend 再評価: [`../ollama-vs-lmstudio-backend.md`](../ollama-vs-lmstudio-backend.md)
  （2026-05-23、**HOLD**。未解決 §5 の項目 1-2 = 「Ollama MLX の stability / MLX モデルの
  ロード可否」が GO/NO-GO の鍵だった）
- きっかけ: Gemma 4 12B が 2026-06-03 にリリースされ、**Ollama に公式 `gemma4:12b-mlx`
  タグ**が出た → 上記 HOLD の前提が変わった

> ⚠️ このドキュメントは机上準備（model ID 確定 + config 差分 + 注意点整理）まで。
> **実機 bench は未実施**。`## 結果メモ` は実機検証後に追記する。
>
> 🟢 **2026-06-27 実機検証の結論: STEP 1 GO（`-it` 版で会話成立）**。当初 `mlx-community/gemma-4-12B-4bit`
> （`-it` 無し＝生 unified ダンプ）は出力崩壊で NO-GO だったが、**`mlx-community/gemma-4-12B-it-4bit`
> （instruction-tuned, 6.77GB）で全項目クリア**: クリーン日本語 / persona・「3つのNO」遵守 / thinking 暴発なし /
> TTFT 0.85-1.07s（< 2.5s budget, 8B と同等）。**前提として MLX ランタイムを 1.6.0→1.9.1 に更新済**。
> avatar の conf.yaml は `lmstudio_llm.model = gemma-4-12b-it` に差し替え済み。詳細は [`## 結果メモ`](#結果メモ)。

## 目的
1. Gemma 4 12B と接続する手順を確定する（LM Studio / Ollama 両 backend）
2. Gemma 4 12B を前提にした場合の仕組み改善点を洗い出す
3. Gemma 4 12B × M1 Mac の注意点・補足をまとめる

## TL;DR / 推奨
> **backend 方針 (2026-06-04 決定)**: **最終ゴールは Ollama への乗り換え**。ただし現 PC は
> **LM Studio のみ導入済**（Ollama 未導入）なので、**当面は LM Studio で Gemma 4 12B を繋ぎ**、
> モデル品質・latency を確定させてから Ollama へ移す 2 段構え。

- **STEP 1（当面・現環境）= LM Studio + `mlx-community/gemma-4-12B-4bit`**。現行パスからの変更が
  最小、NO-GGUF-on-Mac 原則に合致、proven な起動シーケンスをそのまま流用。ここで [TL;DR 要再検証
  3 点] を潰す（backend 非依存の検証は LM Studio 上で済ませておくと移行が楽）。
- **STEP 2（乗り換え・本命）= Ollama + `gemma4:12b-mlx`**。公式 MLX タグの登場で
  [`../ollama-vs-lmstudio-backend.md`](../ollama-vs-lmstudio-backend.md) の HOLD 理由が解消。
  daemon 自動起動 / `keep_alive` / `unload_at_exit` の運用上の利点（Phase 6 の 30 分稼働・
  `avatar-start.sh` の自動起動化）が効く。移行トリガは [3] の「乗り換え判断」参照。
- **要再検証 3 点（STEP 1 で確定させる）**: ① 12B で初音 latency < 2.5s budget を守れるか
  （8B→12B でTTFT増）、② persona/「3つのNO」が Gemma で通用するか（chat template が Llama 系と別）、
  ③ native audio を使って WhisperKit を畳めるか（MLX build が text-only な可能性）。

---

## [1] Gemma 4 12B と繋げる

### 確定 model ID

| Backend | Model ID | Quant / Size | 備考 |
|---|---|---|---|
| **LM Studio (MLX)** ← 推奨初手 | `mlx-community/gemma-4-12B-4bit` | MLX 4bit (~7-8GB) | Apple Silicon 向け、NO-GGUF-on-Mac に合致 |
| **Ollama (MLX)** ← 中期本命 | `gemma4:12b-mlx` | MLX 10GB / 128K ctx | **tags 上は Text-only 表記**（multimodal は要確認） |
| Ollama (default) | `gemma4:12b` | GGUF | Text+Image。Mac では GGUF=速度劣後 |
| LM Studio (GGUF) | `lmstudio-community/gemma-4-12B-it-GGUF` | GGUF | NO-GGUF-on-Mac 原則に抵触、非推奨 |

> chunker.py は `get_lm_model()` で `/v1/models` の先頭モデルを**自動検出**するため、
> CLI パスは「LM Studio で Gemma をロードするだけ」で model ID のハードコード変更は不要。
> 明示的に名前を使うのは shell helper の `LLM_MODEL` 環境変数と OLV `conf.yaml` のみ。

### A. CLI パス（`chunker.py` 単体検証）

```bash
# 1. LM Studio で mlx-community/gemma-4-12B-4bit をロード + Local Server (:1234) ON
# 2. helper を読み込み、LLM_MODEL を Gemma に上書き（warmup_llm / ttft 系が参照）
source ../avatar-helpers.sh
export LLM_MODEL='gemma-4-12b'        # LM Studio 上の表示 id に合わせる
# 3. SYSTEM_PROMPT はそのまま流用（要 persona 再評価。下記 [2]）
warmup_llm                            # KV cache 加熱
voice_to_avatar                       # full pipeline（ASR→chunker→VOICEVOX）
```

`chunker.py` 自体は無改修で動く想定（auto-detect + OpenAI 互換 stream）。
`avatar-helpers.sh` は pipeline 側が SoT の snapshot なので**ファイル編集はせず env 上書きで対応**。

### B. OLV パス（本流、Live2D 込み）

[`../phase5-live2d/olv-patches/conf-overrides.md`](../phase5-live2d/olv-patches/conf-overrides.md)
の LLM ブロックだけを差し替える。

**B-1. LM Studio のまま Gemma に差し替え（最小変更）**
```bash
OLV=~/projects/Open-LLM-VTuber   # ご自身の path に
yq -i '.character_config.agent_config.llm_configs.lmstudio_llm.model = "gemma-4-12b"' "$OLV/conf.yaml"
# llm_provider は lmstudio_llm のまま、temperature 0.7 も据え置き
```

**B-2. Ollama に移行（中期本命、`gemma4:12b-mlx`）**
```bash
ollama pull gemma4:12b-mlx
OLV=~/projects/Open-LLM-VTuber
yq -i '.character_config.agent_config.agent_settings.basic_memory_agent.llm_provider = "ollama_llm"' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.ollama_llm.model = "gemma4:12b-mlx"' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.ollama_llm.base_url = "http://localhost:11434/v1"' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.ollama_llm.temperature = 0.7' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.ollama_llm.keep_alive = -1' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.ollama_llm.unload_at_exit = true' "$OLV/conf.yaml"
```
Ollama に移行すると `avatar-start.sh` の `[2/3]`（LM Studio を「警告のみ」でハードコード）も
`ollama serve` の自動起動に置換できる（`ollama-vs-lmstudio-backend.md` §3 のスニペット参照）。
OLV の `OllamaLLM` provider が起動時に preload するため `warmup_llm` も不要になる。

> ⚠️ yq の落とし穴（Phase 5 既知）: `tts_config` は `character_config` 配下。編集後は
> `yq 'keys' conf.yaml` で top-level が `system_config / character_config / live_config` の
> 3 つだけか確認。詳細は conf-overrides.md §⚠️。

### 接続確認
```bash
curl -s http://localhost:1234/v1/models | jq '.data[].id'      # LM Studio
curl -s http://localhost:11434/api/tags | jq '.models[].name'  # Ollama
curl -s http://localhost:11434/api/ps                          # ロード中モデル（Ollama のみ）
```

---

## [2] Gemma 4 12B ベースでの仕組み改善検討

### 改善ポテンシャル
| # | 改善案 | 効果 | リスク / 要検証 |
|---|---|---|---|
| 1 | **native audio で WhisperKit を畳む** | ASR を別プロセスで持たずに済む → 構成簡素化 + ASR/LLM 2 段 latency を 1 段に | **最重要かつ最不確実**。MLX 4bit build は **text-only の可能性**（Ollama tags 表記）。音声入力を使うには full-precision/GGUF multimodal build が要る → NO-GGUF-on-Mac とトレードオフ。OLV/chunker の入力経路も audio 対応に要改修 |
| 2 | **vision でアバターに「目」** | webcam 画像を渡してユーザーの様子に反応 | リアルタイム性・追加 latency・プライバシー。Phase 7 では scope 外推奨 |
| 3 | **128K context** | multi-turn history cap（現状 5 turn）を大幅に緩められる | 長文脈は TTFT/メモリを食う。avatar は短応答用途なので恩恵は限定的。現状維持で十分 |
| 4 | **Ollama lifecycle で warmup_llm を廃止** | `keep_alive:-1` で常時ホット、`unload_at_exit` でメモリ衛生改善 | [1]B-2 とセット。Phase 6 の 30 分稼働で効く |
| 5 | **MTP による出力高速化** | tok/s 向上で chunker の 1 文目→TTS 起動が速まる可能性 | ランタイム（MLX/llama.cpp）が MTP を活かせるか実装依存。実測で確認 |

### 「3つのNO」「persona」の再評価が必須
現行の persona / fewshot / chunker チューニングは **Swallow 8B（Llama系 chat template）前提**。
Gemma は **chat template・改行/turn token・system role の扱いが異なる**ため、移植時に以下を再確認:
- **NO Thinking**: Gemma 4 に reasoning デフォルト ON 系の挙動がないか（Swallow 採用理由が「Qwen の reasoning で TTFT 60s+」だった経緯）。
- **NO Heavy System Prompt (>800字)**: 現 persona V2 は約 400 字で範囲内だが、Gemma での 3 文制約遵守率・一人称揺れ・「あんまり詳しくないかも」過学習傾向を再測定（Phase 5 D4 の知見が Swallow 固有な可能性）。
- chunker.py の `SENTENCE_END = 。！？〜` 句読点 split は言語依存で backend 非依存 → 流用可。

---

## [3] Gemma 4 12B × M1 Mac の注意 / 補足

### ⚠️ メモリ前提の食い違い（最重要）
- 提供された Gemini 解説は **16GB Mac 前提**。一方このリポの確定構成は **M1 Pro 32GB**
  （[`../README.md`](../README.md) L3, L32）。**32GB ならメモリは余裕**、議論の力点が変わる。
- avatar は LLM 単体では動かない。**同時に常駐するサービスが多い**:
  WhisperKit (large-v3 turbo モデル常駐) + VOICEVOX (docker) + OLV (Python) + ブラウザ(Live2D描画)。
  - **16GB だと**: Gemma 4bit ~8GB + 上記群で swap 発生リスク大 → Gemini の「他アプリ閉じろ」は
    この同時起動を踏まえると一層シビア。**実用は厳しい寄り**。
  - **32GB なら**: Gemma 4bit ~8GB + 全サービスでも余裕。`keep_alive:-1` で常時ホットも可。
- → **実機（32GB）で `gemma4:12b-mlx` 常駐時の Unified Memory 占有を計測**して結論を出す（結果メモへ）。

### MLX vs GGUF（NO-GGUF-on-Mac 原則の現在地）
- pipeline 研究の「**NO GGUF on Mac**」（MLX 4bit が Ollama GGUF より 1.5-2x 速い）は依然有効。
- 朗報: Ollama に**公式 `gemma4:12b-mlx`** が出たので、Ollama を選んでも MLX を維持できる
  （旧 backend doc が GGUF fallback を懸念して HOLD にした最大要因が解消）。
- 注意: その `gemma4:12b-mlx` が **text-only 表記**。**native audio/vision を使いたいなら**
  multimodal build（=現状 GGUF 寄り）が要る → 「速度(MLX)」と「multimodal(GGUF)」が**二者択一**に
  なりうる。avatar は当面テキスト I/O（音声は WhisperKit/VOICEVOX が担当）なので **MLX text を採る**
  のが妥当。multimodal はマイルストーンを分けて別途検証。

### latency budget
- Phase 4b の達成値は「初音 1491ms < 2.5s budget」。これは **8B**。**12B は重い**ので
  **TTFT が増え budget を割る可能性**。`ttft` / `ttft_sys`（avatar-helpers.sh）で 8B vs 12B を
  実測比較し、割るなら `--max-sentences` を詰める / E4B（`gemma4:e4b`）への退避を検討。

### その他
- LM Studio は GUI で自動起動不可（`avatar-start.sh` が「警告のみ」）。常駐運用は Ollama 移行で解決。
- モデル DL サイズ: MLX 4bit ~7-8GB（LM Studio）/ `gemma4:12b-mlx` 10GB（Ollama）。初回 pull の帯域に注意。

### Ollama 乗り換え（STEP 2）の発火条件と手順
**発火条件（どれか1つ満たしたら移行に着手）:**
- STEP 1 で Gemma 4 12B の品質・latency が「採用」と確定した（=移行先の不確実性が消えた）
- avatar を**自動起動 / 30分以上の常駐**で回したくなった（Phase 6 本番運用）
- 終了時の自動アンロードで**メモリを綺麗にしたい**、または**モデルを programmatic に切替**したい

**移行チェックリスト:**
1. `brew install ollama`（現 PC は未導入）→ `ollama serve`（or `brew services start ollama`）
2. `ollama pull gemma4:12b-mlx`
3. OLV `conf.yaml` を [1]B-2 の yq で `ollama_llm` に差し替え（`keep_alive:-1` / `unload_at_exit:true`）
4. `curl http://localhost:11434/api/ps` でロード確認 → `ttft_sys` で **LM Studio 実測値と TTFT 比較**
5. 互角〜許容範囲なら `avatar-start.sh` の `[2/3]` を「警告のみ」→ `ollama serve` 自動起動に置換、
   `warmup_llm` 呼び出しを削除（OLV `OllamaLLM` が preload するため不要）
6. 退行がないことを確認できたら LM Studio を予備に降格

> STEP 1 / STEP 2 のどちらで止めても avatar は動く設計。**LM Studio を消す必要はない**
> （MLX bench の基準器として残すと移行判断がしやすい）。

---

## 実行方法（準備チェックリスト）
```bash
# 接続(最小): LM Studio で mlx-community/gemma-4-12B-4bit をロード → Local Server ON
# CLI 検証:
source ../avatar-helpers.sh && export LLM_MODEL='gemma-4-12b'
warmup_llm && ttft_sys "おはよう"        # TTFT を 8B と比較
voice_to_avatar                          # full pipeline
# OLV 検証: 上記 [1]B-1 の yq を流して avatar-start.sh
OLV_DIR=/path/to/Open-LLM-VTuber ../avatar-start.sh
```

## 結果メモ

### 2026-06-27 実機検証（M1 Pro 32GB / LM Studio）— 結論: STEP 1 は **NO-GO（会話不能）**

検証環境: Apple M1 Pro / 32GB、LM Studio（`lms` CLI 同梱）、`mlx-community/gemma-4-12B-4bit`（DL 完全＝
3 shard 計 10.98GB が `model.safetensors.index.json` の `total_size` と一致）。

**ブロッカーは 2 層。層1 は解決、層2 が未解決の実害。**

| 層 | 症状 | 原因 | 対処 |
|---|---|---|---|
| **層1 ランタイム** | `lms load gemma-4-12b` が `Failed to load model` | LM Studio の MLX ランタイム `mlx-llm-...@1.6.0` が新アーキ未対応。エラー実文言: `ValueError: Model type gemma4_unified not supported. No module named 'mlx_vlm.models.gemma4_unified'` | ✅ **解決**: `lms runtime update --yes` で **1.6.0 → 1.9.1** に更新 → `lms runtime select ...@1.9.1` → **20.02s でロード成功（10.26 GiB）** |
| **層2 モデル品質** | ロード後、text chat で**特殊トークンを吐いて出力崩壊**（`<image｜>` `<audio｜>` のスパム、markdown 崩れ、意味不明文字列）。chat API でも raw `/v1/completions` でも、どのプロンプト整形でも再現 | ① この MLX quant は `tokenizer_config.json` に **`chat_template` 同梱なし**（`has("chat_template")=false`）→ LM Studio が既定テンプレで誤整形。② Gemma 4 は**新トークン体系**（turn = `<｜turn>`/`<turn｜>`、multimodal = `<｜image｜>`/`<｜audio｜>`、`<｜think｜>` 等）で従来 `<start_of_turn>` と非互換。③ 正しい turn トークンで手動整形しても特殊トークンスパムが止まらず、**テンプレ不一致では説明できない＝4bit unified-multimodal 変換自体が text chat で機能していない（early/不良 quant の疑い）** | ❌ **未解決**（config だけでは直らない） |

- **TTFT 8B vs 12B 実測**: 未測定（保留）。層2 で**有用な出力が出ない以上 latency を測っても行動に繋がらない**ため。
  正常 quant 入手後に `ttft_sys` で再計測する（手順は本 README「実行方法」）。
- **32GB での Unified Memory 占有**: gemma 単体ロードで **10.26 GiB**（`lms ps` 表示 11.02GB）。
  全サービス常駐時の計測は層2 解決後に持ち越し（32GB なら理論上は余裕の範囲）。
- **persona 遵守率 / 「3つのNO」**: 評価不能（出力崩壊のため。実 `persona_prompt` を system に与えても garbage）。
- **native audio で WhisperKit を畳めるか**: 未評価。そもそも text chat が成立しないので multimodal 検証は後段。
- **LM Studio → Ollama 移行（STEP 2）の可否**: 本検証では判断保留。ただし**層2 回避の有力候補**（下記）。

### 取った状態（ロールバック済み）
- `conf.yaml` は **Swallow 8B に復元**（`...lmstudio_llm.model = llama-3.1-swallow-8b-instruct-v0.5`）。
  変更前に `conf.yaml.bak-pre-gemma` を取得。復元後 backup と **diff ゼロ**を確認。avatar は従来どおり稼働。
- gemma モデルは **DL 済みのまま保持**（再 DL 不要）、メモリからは unload（10GB 解放）。
- LM Studio MLX ランタイムは **1.9.1 に更新済みのまま**（1.6.0 も残存。Swallow 等の既存 MLX には無害）。

### 2026-06-27 追加 research: 「動く edition」は存在する（要点: `-it` 付きを使う）

**根本の取り違え**: 手元の `mlx-community/gemma-4-12B-4bit` は **`-it`（instruction-tuned）無しの unified
multimodal 生ダンプ**（`config.json` の `model_type=gemma4_unified` / `Gemma4UnifiedProcessor`、`chat_template`
非同梱）。これは layer2 の garbage の直接原因。**`-it` 付き edition は `chat_template` を同梱し、vision/audio
タワーを落とした text 推論パス**として配布されている。Gemma4×MLX の chat_template 欠落は広く既知
（[mlx-vlm #941](https://github.com/Blaizzy/mlx-vlm/issues/941)、`<unused24>` garbage = [同根](https://gemma4.dev/errors/gemma-4-unused24-tokens-llama-cpp)）。

**⚠️ もう一つの必須対応 — Gemma 4 は thinking/reasoning がデフォルト ON**。本 README [2] の「NO Thinking」
（Qwen を TTFT 60s+ で蹴った要件）に直撃する。採用時は `chat_template_kwargs={"enable_thinking": false}` で
明示 OFF が必須（[mlx-lm #1352](https://github.com/ml-explore/mlx-lm/issues/1352) 等で reasoning 無限化の報告）。

**候補 edition（優先順）**:

| # | Edition | 形式/サイズ | chat_template | 備考 |
|---|---|---|---|---|
| 1 | `mlx-community/gemma-4-12B-it-4bit` | MLX 4bit / ~11GB | ✅ 同梱 | **標準の instruction-tuned MLX。現ランタイム 1.9.1 で素直に動く公算が最も高い**。vision 対応 |
| 2 | `mlx-community/gemma-4-12B-it-OptiQ-4bit` | MLX 混合4bit / ~8.3GB | ✅ 同梱 | text パス（towers 除去）、標準4bit比 +6.40pt。ただし **mlx-lm main 必須**で LM Studio 同梱版だと動かない恐れ |
| 3 | Unsloth `gemma-4-12b-it-GGUF`（UD-Q4_K_XL）/ `lmstudio-community/...-GGUF` | GGUF 4bit / ~7.6GB | ✅ 同梱 | **確実に動く踏み台**。ただし NO-GGUF-on-Mac（MLX比 1.5-2x 遅）に抵触 → 品質/persona 確認用 |
| 4 | Ollama `gemma4:12b-it-qat`（7.2GB, QAT）/ `gemma4:12b-mlx`（6.8GB） | Ollama 内包 / 6.8-7.2GB | ✅ modelfile 内包 | **STEP 2 本命**。Ollama がテンプレを内包するので LM Studio の欠落問題を構造的に回避。`12b-it-qat` は Google 公式 QAT で 4bit でも品質高 |

**推奨**: まず **① `gemma-4-12B-it-4bit`** を LM Studio で試す（現環境・最小変更・NO-GGUF 維持）。
それでも MLX 側が不安定なら **③ GGUF** で「Gemma が persona/「3つのNO」を満たすか」を先に確定し、
本番は **④ Ollama QAT** に載せる、の三段が堅い。いずれも **`enable_thinking:false` 設定とセット**。

> 教訓: 「Ollama に公式 `gemma4:12b-mlx` が出た＝HOLD 解消」（本 README 起点）は**ランタイム対応の話**で、
> **MLX quant の text-chat 実用性は別問題**だった。さらに「`gemma-4-12B-4bit`」と「`gemma-4-12B-it-4bit`」は
> 別物（`-it` = instruction-tuned）。**model ID は `-it` 付きを指定する**のが今回の最大の学び。

### 2026-06-27（同日 追検証）`-it` 版で GO — 全項目クリア

`mlx-community/gemma-4-12B-it-4bit`（`lms get` で DL、LM Studio 上の id = **`gemma-4-12b-it`**、6.77GB / ロード
6.31GiB / 11.5s）で検証し直した結果、**STEP 1 成立**。

- **出力品質**: クリーンな日本語。layer2 の garbage は消えた。
  - 補足: この `-it` 版も `tokenizer_config.json` に `chat_template` は**非同梱**（`has=false`）。だが
    **LM Studio mlx-engine 1.9.1 が gemma4 arch を検出して内部テンプレを適用**するため動く。garbage の真因は
    「**`-it` 無し＝非 instruction-tuned の生 unified ダンプ**」だった（template だけの問題ではなかった）。
- **persona / 「3つのNO」**: 現行 `persona_prompt`（Swallow 用にチューニング）を**無改修で流用して合格**。
  - 一人称「私」維持 ✅ / 1-2 文遵守 ✅ / 知ったかぶり回避（進撃の巨人「あまり詳しく知らないの」）✅ /
    「なお/ナオ」呼びかけの自己認識 ✅ / 絵文字なし ✅
- **NO Thinking**: 既定構成で `reasoning_content` の漏れ・thinking 暴発は**観測されず**。現状は追加設定不要。
  （将来 thinking が出始めたら `chat_template_kwargs={"enable_thinking": false}` で抑制）
- **TTFT 実測**（persona system 付き, warm, `:1234`）:

  | モデル | warm TTFT | 備考 |
  |---|---|---|
  | Swallow 8B | ~0.91s（cold 初回 3.09s） | 既存基準 |
  | **Gemma 4 12B-it** | **0.85 – 1.07s** | **8B と同等。2.5s budget に余裕** |

  → README [3] の懸念「12B は重く budget を割る」は**否定**。12B でも 8B 同等の TTFT。
- **Unified Memory**: gemma-4-12b-it 単体ロードで **6.31 GiB**（非 it 版 10.26GiB より軽量＝text パス）。
  32GB なら全サービス常駐でも余裕の見込み（OLV/WhisperKit/VOICEVOX/ブラウザ同時起動時の実測は次段）。

**適用済みの状態**:
- `conf.yaml` の `lmstudio_llm.model = gemma-4-12b-it`（backup `conf.yaml.bak-pre-gemma` あり、差分は当該1行のみ）。
- LM Studio に `gemma-4-12b-it` ロード済み。MLX ランタイム 1.9.1 選択中。
- 壊れた非 it 版 `gemma-4-12b`（11.02GB）は DL 済みのまま残置・unload 済み。**不要なら削除可**
  （`lms ls` 上の `gemma-4-12b`）。ディスク 11GB を取り戻せる。

**残タスク（ユーザー検証 / 次段）**:
1. ~~`avatar-start.sh` で Live2D 込みの実会話~~ → **実施済**（下記 persona 知見）。
2. 全サービス常駐時の 32GB 占有を実測（`README [3]` のメモリ前提を確定）。
3. multi-turn での persona ドリフト / thinking 出現の有無を長め会話で確認。
4. 良ければ STEP 2（Ollama `gemma4:12b-it-qat` 等）への移行を検討（lifecycle 自動化の利得）。

### 2026-06-27（実会話）persona の過剰制約を発見 → 条件付き深さ persona で解決

`avatar-start.sh` で実会話したところ応答が"微妙"（短く当たり障りなし／相談質問でキャラの趣味=お茶・読書に
脱線）。**persona だけ差し替えた A/B で、モデルではなく persona が原因と確定**（gemma-4-12b-it は緩和 persona
だとポモドーロ等の具体助言を返せた）。真因は現 persona の `1〜2文・3文以上NG` + 強キャラ設定の**過剰制約**
（phase7 [2] が予告した「過学習傾向」が顕在化）。

対処: OLV `persona_prompt` を**条件付き深さ版**に更新済み —「普段は1〜2文で簡潔。**ただし相談/助けを求められた
ときだけ 2〜4 文で具体的に踏み込む**（手順・最初の一歩を1つ添える）。知らない事実は断定せず助言に留める」。
検証で **雑談=簡潔維持 / 相談=具体化 / 3つのNO=維持** の全てを確認。backup `conf.yaml.bak-pre-persona` あり。

> 教訓: 字数ハード制約はキャラの一貫性に効くが**実用性を殺す**。雑談/相談で深さを切り替える分岐設計が要。

### 🔁 リサーチへの差し戻し
本検証で判明した「初手の研究推奨が外れた点（model ID の `-it` 取り違え・ランタイム前提欠落・chat_template・
thinking・latency 過大評価・persona 過剰制約）」を **[`./feedback-to-research.md`](./feedback-to-research.md)** に
まとめた。これを deep-research repo に戻して**再リサーチ**の入力にする。

## 参照（一次情報）
- [Introducing Gemma 4 12B (Google blog)](https://blog.google/innovation-and-ai/technology/developers-tools/introducing-gemma-4-12b/)
- [Gemma 4 12B: The Developer Guide](https://developers.googleblog.com/gemma-4-12b-the-developer-guide/)
- [Ollama: gemma4](https://ollama.com/library/gemma4) / [`gemma4:12b-mlx`](https://ollama.com/library/gemma4:12b-mlx)
- [HF: mlx-community/gemma-4-12B-4bit](https://huggingface.co/mlx-community/gemma-4-12B-4bit)
- [HF: lmstudio-community/gemma-4-12B-it-GGUF](https://huggingface.co/lmstudio-community/gemma-4-12B-it-GGUF)
- backend 比較: [`../ollama-vs-lmstudio-backend.md`](../ollama-vs-lmstudio-backend.md)
</content>
</invoke>
