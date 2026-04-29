# Qwen3-TTS feasibility report — avatar 用 2nd TTS backend 検討

## 起点

- Phase 4b TTS bench: [`./phase4b-tts-bench/README.md`](./phase4b-tts-bench/README.md)
  - 該当節「WhisperKit Qwen3-TTS — 未計測 (skipped)」: 「VOICEVOX 春日部つむぎ で
    budget 700ms を 166ms 下回り (534ms)、AivisSpeech も計測済で比較結論が出たため、
    3rd TTS の bench には進まず Phase 4b の TTS 部 (B) は終了。MLX スタック統合性の
    メリットは将来再評価の余地あり」
- pipeline 側 Phase 4b 実装ログ: `../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/06-phase4b-implementation-log.md`
  - §1 TTS 採用結論で `Qwen3-TTS — 未計測 (打ち切り)` と記録
  - 残課題節「TTS optimization (将来) — WhisperKit Qwen3-TTS で MLX 統合再評価」

## 調査日 / 担当 / スコープ

- 調査日: **2026-04-29**
- 担当: linnefromice (lab、Web 調査のみ。**M1 Pro 実機での bench は未実施**)
- スコープ: avatar の 2nd TTS backend として Qwen3-TTS を採用すべきかの **GO / WAIT / SKIP** 判断材料を揃える
- 対象ハード: M1 Pro 32GB (avatar 開発機)

## 結論 (TL;DR)

| 判定 | 理由 (要約) |
|---|---|
| **WAIT** (推奨) | 上流は健在 (Apache-2.0、活発、MLX 移植済) だが、**M1 / M1 Pro での RTF が ~1.8-2.2** と公開ベンチで非リアルタイム。avatar の 700ms budget には届かない可能性が高い。**M2 Max RTF 0.55 / M3+ なら現実的** であり、ハード更新タイミングまで保留が現実的 |

詳細は §7 推奨。

## 1. 現状 (release / repo / 活動)

| 項目 | 値 | 備考 |
|---|---|---|
| 上流 repo | [QwenLM/Qwen3-TTS](https://github.com/QwenLM/Qwen3-TTS) | Alibaba Cloud Qwen team |
| ライセンス | **Apache-2.0** | Tokenizer / model weights とも |
| 公開時期 | **2026-01-22 OSS 化** | 公式アナウンス |
| Technical report | arXiv 2601.15621 | HuggingFace papers でも公開 |
| HF org | [Qwen/](https://huggingface.co/Qwen) | 5+ モデルが公開 |
| 上流 release tag | **未発行** ("No releases published") | main branch で commit ベース運用 |
| HF 月間 DL (0.6B-Base) | 687,713 | 2026-04 時点 |
| MLX 移植 | ✅ Blaizzy/mlx-audio に統合済 (mlx-audio v0.4.3 = 2026-04-28) | 直近活発 |

**判定**: プロジェクト自体は **健在 / 活発**。OSS 化から 3 ヶ月で MLX 移植 + Swift 移植 + Apple Silicon 専用フォーク複数が出ている。Stability に懸念なし。

## 2. M1 arm64 install paths

公開されている install 経路を整理。

| 経路 | 提供元 | パッケージ | M1 arm64 | 備考 |
|---|---|---|---|---|
| **mlx-audio** | [Blaizzy/mlx-audio](https://github.com/Blaizzy/mlx-audio) | `pip install -U mlx-audio` | ✅ ネイティブ MLX | **今回の本命**。CLI / Python API / HTTP server 全部あり |
| HF transformers (qwen-tts) | QwenLM 公式 | `pip install -U qwen-tts` | △ (CUDA 前提、Mac は重い) | `device_map="cuda:0"` 例が default。Mac は MPS/CPU fallback で遅い |
| Apple Silicon フォーク | [kapi2800/qwen3-tts-apple-silicon](https://github.com/kapi2800/qwen3-tts-apple-silicon) | git clone + pip | ✅ MLX 利用 | CLI のみ、HTTP server なし。M4 Air で RAM 2-3GB / CPU 40-50°C |
| Swift パッケージ | [AtomGradient/swift-qwen3-tts](https://github.com/AtomGradient/swift-qwen3-tts) | SwiftPM | ✅ ネイティブ MLX | Swift API + CLI、4-bit 量子化で 808MB |
| WhisperKit bundled | argmaxinc/WhisperKit | — | ❌ (TTS 機能なし) | WhisperKit は ASR 専門。**Phase 4b の `WhisperKit Qwen3-TTS` 表記は誤り**で、正しくは「WhisperKit + Qwen3-TTS (別製品の組み合わせ)」 |
| Docker image | — | — | ❌ 公式なし | Linux/CUDA 用は third-party 散見 |

### 確認: Phase 4b README の `WhisperKit Qwen3-TTS` 記述

phase4b-tts-bench/README.md の候補表で `WhisperKit Qwen3-TTS` と書いていたが、調査結果として
**WhisperKit は TTS をサポートしない** (argmaxinc/WhisperKit は ASR 専用) ため、本来意図して
いたのは:

> 「WhisperKit と同じ MLX スタック (= Apple ml-explore/mlx + Blaizzy/mlx-audio) で動く Qwen3-TTS」

の意。LLM (LM Studio + MLX) と TTS (mlx-audio) を **同じ MLX runtime / unified memory 上で
共存** できれば、KV cache メモリ圧迫が小さい、GPU/Neural Engine の利用効率が上がる、等の
利点を期待した — というのが Phase 4b の deferral 理由として正しい解釈。

## 3. API 特性

mlx-audio (本命) を前提に整理。

| 項目 | 値 | 備考 |
|---|---|---|
| 同期 / 非同期 | **両方** (`stream=True` で chunk yield) | VOICEVOX は同期 only |
| API 形態 | (a) Python `load_model().generate()` (b) CLI `python -m mlx_audio.tts.generate` (c) HTTP server `mlx_audio.server --port 8000` (OpenAI 互換 REST) | 選択肢豊富 |
| **HTTP server** | ✅ 利用可能 (FastAPI ベース、port 任意) | VOICEVOX と同様にプロセス分離可 |
| Streaming chunk | `streaming_interval` 秒で制御 (例: 0.32s = ~4 token at 12.5 FPS) | chunker.py との相性 ◎ |
| 出力 sample rate | **16 kHz** (audio output) | モデル名の "12Hz" は **token rate** (12.5 frames/s) で誤解しやすい |
| Voice 選択 | `voice="serena"` 等の named speaker、または `ref_audio` で voice clone (3 秒音声) | VOICEVOX (40 speaker / 200+ style) 比で named voice は少ない |
| 日本語 voice | **`Ono_Anna` (Japanese female、playful、light tone)** が公式に存在 | mlx-audio の README には未掲載で **upstream のみ動作確認**、MLX 移植版での挙動は要検証 |
| 多言語 | 中国語 / 英語 / **日本語** / 韓国語 / 独 / 仏 / 露 / 葡 / 西 / 伊 (10 言語) | ナオは日本語のみで OK |

### VOICEVOX (現行) との API 比較

| 項目 | VOICEVOX | Qwen3-TTS (mlx-audio) |
|---|---|---|
| Endpoint | `/audio_query` (POST) → JSON、`/synthesis` (POST + JSON) → WAV | OpenAI 互換 (例: `/v1/audio/speech`) または mlx-audio 独自 |
| Speaker 指定 | `speaker=8` (整数 ID) | `voice="Ono_Anna"` (string) または `ref_audio=path` |
| 出力形式 | WAV (24kHz?) | WAV 16kHz |
| Streaming | ❌ (1 文 = 1 round-trip) | ✅ (chunk emission、interval 0.1-0.5s) |
| プロセス起動 | Docker `-p 50021:50021` で常駐 | `mlx_audio.server --port 8000` で常駐 |

## 4. 期待 latency (1 文日本語、warm)

ターゲット: `"んー、おはようございます。"` (Phase 4a/4b 計測用テキスト)、warm 状態。

### 公開ベンチ値

| 環境 | モデル | 指標 | 値 | 出典 |
|---|---|---|---|---|
| 上流 streaming (Alibaba 内部) | Qwen3-TTS-12Hz | E2E first-packet | **97ms** | 公式技術レポート (理想値、cloud GPU) |
| Cloud GPU (RTX 3090) | 1.7B | RTF | 1.26x (= 35s 音声を 44s で生成) | 第三者記事 |
| **M1 / M1 Pro / M2 (MLX)** | **0.6B** | **RTF ~1.8-2.2** | qwen3-tts.app + dev.to で同一値 (引用元同一の可能性高) | 公開記事 (実測ソース不明、要 lab 実機追試) |
| **M2 Max (Swift, MLX)** | 1.7B (batch synth) | **RTF ~0.55** | AtomGradient/swift-qwen3-tts README | リアルタイム達成 |
| M2 mac mini (mlx-audio) | 1.7B | "1000 chars/min — not great" | myByways blog | 体感評価 (latency 数値なし) |
| mlx-audio batch=1 (公式 README) | 6-bit 量子化 (チップ非開示) | TTFB 84.8ms / Memory 3.88GB | mlx-audio Qwen3-TTS README | **チップ未明示**、おそらく M3/M4 系 |

### M1 Pro での予想 (推定、要実機確認)

`"んー、おはようございます。"` ≈ 約 2.0-2.5 秒の音声 (16kHz)。M1/M1 Pro RTF ~2 から逆算:

- **生成所要時間 ≈ 4-5 秒** (全文)
- ただし streaming で **first chunk emission は streaming_interval (0.32s) + token decode** で
  数百 ms 程度に抑えられる可能性あり (要実測)
- **第 1 chunk が 700ms budget に入るかは ボーダーライン**

**比較**: VOICEVOX 春日部つむぎ warm 中央値 = **534ms** (確定値)。

| TTS | warm latency (M1 Pro 32GB) | 信頼度 |
|---|---|---|
| **VOICEVOX 春日部つむぎ:ノーマル** | **534ms (実測)** | ✅ 確定 (5 trials、Phase 4b) |
| AivisSpeech まお:おちつき | 634ms (実測) | ✅ 確定 (5 trials、Phase 4b) |
| Qwen3-TTS 0.6B (推定 M1 Pro) | **要 M1 で実機確認** (~700-1500ms 予想) | ⚠️ 推定のみ |

### 注意点

- **97ms claim は誤誘導されやすい**: cloud streaming + 内部 dual-track 最適化下の値。Mac
  ローカル実行で再現する保証なし
- **0.6B vs 1.7B**: 0.6B は声質が劣る可能性あり (公式は 1.7B Base/CustomVoice/VoiceDesign 推奨)
- **"M1 / M2 RTF 1.8-2.2"** の引用元は qwen3-tts.app と dev.to の 2 か所で同値。**チップ世代の
  分解能なし** (M1 Pro 単体では未確認)。M1 Pro 16-core GPU で多少改善する可能性はあるが、
  実機 bench なしには断言不可

## 5. メモリフットプリント (M1 Pro 32GB 共存可否)

avatar の同居プロセス:

| プロセス | メモリ実効値 |
|---|---|
| LM Studio (Llama-3.1-Swallow-8B 4bit、MLX) | ~4.5 GB |
| WhisperKit serve (large-v3-v20240930_turbo) | ~1-2 GB |
| VOICEVOX engine (cpu-arm64-latest, Docker) | ~1 GB |
| afplay / Python chunker / sox VAD | < 0.5 GB |
| **小計** | **~7-8 GB** |
| OS / その他 | ~6-8 GB |
| **空き枠** | **~16-19 GB** |

### Qwen3-TTS のメモリ要求

| 量子化 | モデルサイズ (disk) | RAM 実行時 (報告値) |
|---|---|---|
| 0.6B-Base-4bit (MLX) | **1.71 GB** | 推定 2-3 GB (kapi2800 報告: M4 Air で 2-3GB) |
| 0.6B-Base-bf16 (MLX) | ~1.2 GB | 3-4 GB 程度 |
| 1.7B-Base-bf16 (MLX) | ~3.4 GB | 6 GB 程度 (mlx-audio 公式 batch=8 で 4.10GB) |
| 1.7B-Base 標準 (PyTorch) | — | **10+ GB** (kapi2800 報告) ← MLX 必須の根拠 |

**判定**: **空き 16-19 GB に対して MLX 版 1.7B でも余裕あり**。Swallow 8B との共存は
メモリ的に問題なし。

ただし共存時に **MLX runtime の GPU 競合** が発生する可能性あり (LM Studio も MLX バックエンド)。
→ HTTP server で別プロセス化 + 順次推論 (LLM stream → 1 文 → TTS) なら影響限定的なはず。要実機検証。

## 6. chunker.py 統合コスト

[`./phase4b-llm-stream-chunker/chunker.py`](./phase4b-llm-stream-chunker/chunker.py)
(現状 322 行) への追加変更を見積もる。

### 現状の TTS 呼び出し (VOICEVOX 専用、L160-179)

```python
def synth_voicevox(text: str, speaker_id: int) -> str:
    qparams = urllib.parse.urlencode({"text": text, "speaker": speaker_id})
    qreq = urllib.request.Request(f"{VOICEVOX_URL}/audio_query?{qparams}", method="POST")
    with urllib.request.urlopen(qreq, timeout=10) as r:
        query = r.read()
    sreq = urllib.request.Request(
        f"{VOICEVOX_URL}/synthesis?speaker={speaker_id}",
        data=query,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(sreq, timeout=30) as r:
        wav = r.read()
    f = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    f.write(wav)
    f.close()
    return f.name
```

### Qwen3-TTS 統合の選択肢

#### 案 A: HTTP server (mlx-audio.server、推奨)

VOICEVOX と同じ「外部プロセスへの POST → WAV」モデルで統合摩擦が最小。

```python
# chunker.py に追加 (~30 行)
QWEN3_URL = os.environ.get("QWEN3_URL", "http://127.0.0.1:8000")

def synth_qwen3(text: str, voice: str) -> str:
    # mlx-audio server の OpenAI 互換 endpoint
    body = json.dumps({
        "model": "mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit",
        "input": text,
        "voice": voice,  # "Ono_Anna" 等
        "response_format": "wav",
    }).encode("utf-8")
    req = urllib.request.Request(
        f"{QWEN3_URL}/v1/audio/speech",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        wav = r.read()
    f = tempfile.NamedTemporaryFile(delete=False, suffix=".wav")
    f.write(wav)
    f.close()
    return f.name

# 既存の synth 呼び出し箇所 (L267) で backend 切り替え:
TTS_BACKEND = os.environ.get("TTS_BACKEND", "voicevox")  # voicevox|qwen3
if TTS_BACKEND == "qwen3":
    wav = synth_qwen3(sent, args.voice)
else:
    wav = synth_voicevox(sent, args.speaker)
```

**変更行数見積**: chunker.py に **+30〜50 行** (HTTP API、env 切り替え、CLI flag)。
起動 sequence (avatar-helpers.sh) に `mlx_audio.server &` 起動 step 追加 (+5 行)。

#### 案 B: in-process Python load_model (非推奨)

```python
from mlx_audio.tts.utils import load_model
_qwen3_model = load_model("mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit")  # cold ~5-10s
results = list(_qwen3_model.generate(text=sent, voice="Ono_Anna"))
```

**問題**:
- chunker.py が現状 **stdlib のみ依存** (Phase 4b 設計判断 §2)。`mlx_audio` を依存に
  足すと pipeline 書き戻し時の摩擦増 (lab CLAUDE.md「stdlib のみ」原則)
- chunker.py を毎回 spawn する設計 (`avatar-helpers.sh` 経由) のため、Python プロセス
  毎に model load (~5-10s) が走る。warm 状態を維持できない
- → **HTTP server 案 A 一択**

#### 案 C: streaming chunk 採用 (将来最適化)

`stream=True` + `streaming_interval=0.32` で chunk 単位で audio を queue に push。
理論上 first audio ~ 数百 ms に短縮可能だが、wave concatenation や afplay の chunk 再生
ハンドリングが必要。**初期実装では案 A の synchronous で十分**。

### 統合コスト総括

| 項目 | 値 |
|---|---|
| chunker.py 改変 | **+30-50 行** (`synth_qwen3` + backend 切り替え) |
| avatar-helpers.sh 改変 | +5-10 行 (server 起動 helper) |
| ドキュメント (起動 sequence) | +1 ステップ |
| 試験工数 | M1 Pro 実機 bench (5 trials × 数 voice、~1h) + 統合動作確認 (~1h) |
| **総合** | **2-3 時間** で 2nd backend 切り替え可能な状態に到達 (実機 latency が budget を満たすことが前提) |

## 7. 推奨 — WAIT

### 推奨理由

| 軸 | 評価 |
|---|---|
| 上流の安定性 | ✅ 強い (Apache-2.0、活発、MLX 移植 v0.4.3 直近、Swift 版もあり) |
| install path | ✅ mlx-audio で simple (`pip install -U mlx-audio`) |
| **M1 Pro での実用性** | ⚠️ **未確認だが公開ベンチで RTF ~2 (M1/M2)、M2 Max でようやく RTF 0.55** |
| メモリ | ✅ 0.6B-4bit 1.71GB、Swallow 8B との同居問題なし |
| 統合コスト | ✅ +30-50 行 / 2-3 時間 |
| 日本語 voice | △ `Ono_Anna` 1 体のみ (VOICEVOX 40 speaker / AivisSpeech 1 speaker と比較) |
| budget < 700ms 達成見込み | ⚠️ ボーダーライン (実機未確認) |

### なぜ GO ではないか

1. **VOICEVOX 春日部つむぎが既に budget を 166ms 下回って動作中** (534ms)。差し替え動機が
   弱い。「困ってない」状態で 2nd backend を入れる工数対効果が低い
2. **M1 Pro 実機での RTF 未測定**。最楽観で RTF 1.0 (M3 級) 仮定でも、4-5 文を全 Qwen3 で
   回すと VOICEVOX より遅くなる確率がそれなりにある
3. mlx-audio README の Qwen3-TTS section に **日本語 voice の挙動 / 評価が未掲載** (中国語と
   英語の voice しか記載なし)。`Ono_Anna` は upstream のみ確認、MLX 移植版での挙動 / 声質は
   要検証

### なぜ SKIP ではないか

1. **MLX 統合の旨み (Phase 4b README で言及した点) は依然として有効**: LLM (Swallow) と TTS
   が同じ MLX runtime / unified memory に乗ることで KV cache 圧迫低減、Neural Engine 活用
2. **Voice cloning 機能 (3 秒の参照音声)** は VOICEVOX にはない強み。ナオの「声を作る」段階
   (Phase 5+ で考えるなら) で活きる
3. **streaming API** は VOICEVOX にない。chunker.py の 1 文単位 queue 設計より細かい粒度で
   first audio を出せる可能性あり (chunk-level streaming)
4. ハード更新 (M3+ や M4 Pro) で RTF が一気に実用域に入るので、**今 SKIP すると将来の機会
   損失が大きい**

### WAIT trigger (再評価する条件)

以下のいずれかを満たしたら GO 検討:

- [ ] M1 Pro 実機で `"んー、おはようございます。"` 1 文の **first chunk latency < 700ms** を
      `mlx_audio` で実測 (5 trials 中央値)
- [ ] Avatar 開発機を M3 Pro+ に更新したタイミング (RTF が実用域へ)
- [ ] mlx-audio が **公式に Japanese voice (Ono_Anna) の M1 動作報告** を README に追記
- [ ] VOICEVOX に **不満が出た** (例: ナオの声質を変えたい、voice cloning が必要、streaming
      が欲しい等の具体的要件)
- [ ] Phase 5 (Live2D) 実装で口パク同期に **音素タイミング API** が必要になり、Qwen3-TTS
      streaming のほうが連携しやすい場面が出た

## 補足: 軽量 PoC (時間に余裕があるとき向け、< 1h)

`mlx_audio` を試すだけなら別 slug で M1 Pro bench だけ取れる:

```bash
# 0.6B-4bit を bench (chunker.py 統合は後回し、まず素の性能だけ見る)
pip install -U mlx-audio soundfile
python -m mlx_audio.tts.generate \
  --model mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit \
  --text "んー、おはようございます。" \
  --voice Ono_Anna  # 動かない可能性あり、その場合は default voice
```

これで `"んー、おはようございます。"` の生成時間と Ono_Anna の音質を 30 分程度で確認可能。
**結果が < 700ms / 音質 OK なら本格統合 (案 A) へ進む**、それ以外は WAIT 維持。

## References (実際にチェックした URL)

### 上流 / モデル

- [QwenLM/Qwen3-TTS (GitHub)](https://github.com/QwenLM/Qwen3-TTS) — 上流 repo
- [Qwen3-TTS Collection on HuggingFace](https://huggingface.co/collections/Qwen/qwen3-tts) — モデル一覧
- [Qwen/Qwen3-TTS-12Hz-0.6B-Base](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-0.6B-Base) — 0.6B base モデルカード
- [Qwen/Qwen3-TTS-12Hz-1.7B-Base](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-Base) — 1.7B base、Ono_Anna (Japanese) 記載
- [Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign) — VoiceDesign 版
- [Qwen3-TTS Demo Space](https://huggingface.co/spaces/Qwen/Qwen3-TTS) — 公式 demo (HF Space)
- [Qwen3-TTS Technical Report (arXiv 2601.15621)](https://huggingface.co/papers/2601.15621)

### MLX 移植

- [Blaizzy/mlx-audio (GitHub)](https://github.com/Blaizzy/mlx-audio) — MLX 移植本命、HTTP server あり
- [mlx-audio Qwen3-TTS README](https://github.com/Blaizzy/mlx-audio/blob/main/mlx_audio/tts/models/qwen3_tts/README.md) — 使用例、ベンチ
- [mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit](https://huggingface.co/mlx-community/Qwen3-TTS-12Hz-0.6B-Base-4bit) — MLX 4bit、1.71GB
- [mlx-audio on PyPI](https://pypi.org/project/mlx-audio/)

### Apple Silicon 専用フォーク / 参考実装

- [kapi2800/qwen3-tts-apple-silicon](https://github.com/kapi2800/qwen3-tts-apple-silicon) — M1-M4 用 CLI、RAM 2-3GB on M4 Air
- [kapi2800/qwen3-tts-mac](https://github.com/kapi2800/qwen3-tts-mac) — 旧版 (上記が後継)
- [AtomGradient/swift-qwen3-tts](https://github.com/AtomGradient/swift-qwen3-tts) — Swift パッケージ、M2 Max RTF 0.55

### 第三者ベンチ / レビュー

- [myByways: Qwen3-TTS with MLX-Audio on macOS](https://mybyways.com/blog/qwen3-tts-with-mlx-audio-on-macos) — M2 mac mini で「1000 chars/min, not great」
- [qwen3-tts.app: Performance Benchmarks Hardware Guide 2026](https://qwen3-tts.app/blog/qwen3-tts-performance-benchmarks-hardware-guide-2026) — Mac MLX RTF 1.8-2.2 (0.6B)
- [dev.to: Qwen3-TTS Complete 2026 Guide](https://dev.to/czmilo/qwen3-tts-the-complete-2026-guide-to-open-source-voice-cloning-and-ai-speech-generation-1in6) — 「As of January 2026, Qwen3-TTS primarily supports CUDA. Mac users may experience slower performance」
- [adrianwedd: Voice Cloning with Qwen3-TTS and MLX](https://adrianwedd.com/blog/voice-cloning-qwen3-tts-mlx/) — voice clone レビュー

## 履歴 / TODO

- [x] 2026-04-29: 本フィージビリティ作成
- [ ] M1 Pro 実機 bench (`"んー、おはようございます。"` × 5 trials、4bit / bf16) — WAIT trigger
- [ ] mlx-audio server を別 slug で立ち上げ、chunker.py 案 A の最小統合 PoC — WAIT trigger
