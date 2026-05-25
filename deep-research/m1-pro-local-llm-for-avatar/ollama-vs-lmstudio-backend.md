# Ollama vs LM Studio — Avatar LLM backend 再評価 (調査のみ)

## 起点

- 現構成 (Phase 4a 確定): [`./README.md`](./README.md) §現在の確定構成
  - 「LLM: `mlx-community/Llama-3.1-Swallow-8B-Instruct-v0.5-4bit` on **LM Studio** (port 1234) ✅ 確定」
- pipeline 側 研究レポートでの runtime 比較: `../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/02-analysis.md`
  - §2.6「ランタイム比較 (Ollama vs LM Studio vs llama.cpp vs MLX)」
  - §2.2「Avatar 選定の『3 つの NO』」のうち **NO GGUF on Mac** — MLX 4bit は Ollama より 1.5-2x 速い
  - §2.6.3 結論「avatar 用途では LM Studio (MLX) または mlx-lm が最速。**Ollama は MLX preview backend が安定するまでは速度面で劣る (使い勝手では Ollama が依然優位)**」
- 運用上の痛点が表面化している file: [`./avatar-start.sh`](./avatar-start.sh) L84-93
  - 「[2/3] LM Studio (LLM, :1234) — **GUI アプリ。自動起動不可 → 検知して警告のみ**」とハードコード

## 調査日 / 担当 / スコープ

- 調査日: **2026-05-23**
- 担当: linnefromice (lab、コード調査 + pipeline 側既存研究の再評価。**実機 bench は未実施**)
- スコープ: pipeline 研究は「速度」軸が主で「**backend / API 接続性**」軸の評価が手薄。avatar 運用 (Phase 6 の 30 分稼働、自動起動) を見据えて、Ollama に切り替える価値があるかの **論点整理** を行う
- やらないこと: 実機 bench、コード変更、`conf.yaml` 切り替え

## 結論 (TL;DR)

| 判定 | 理由 (要約) |
|---|---|
| **HOLD / 条件付き再評価** | Backend/API 接続性は Ollama が明確に優位 (daemon・自動起動・OLV provider の深さ)。ただし pipeline 研究の「NO GGUF on Mac」原則と、Ollama MLX backend の 2026-05 時点 stability が未確認のため即時切替は推奨せず。**未解決 3 項目 (§5) を確認した上で Phase 7 候補として判断** する |

詳細は §4 推奨 / §5 未解決事項。

## 1. Backend / API 接続性の比較 (本調査の追加軸)

pipeline 研究の §2.6 は速度比較が中心。本節は**運用・統合の観点**で再評価する。

| 観点 | LM Studio (現状) | Ollama |
|---|---|---|
| プロセスモデル | macOS GUI .app | バックグラウンド daemon |
| 自動起動 | ✗ GUI アプリ。`avatar-start.sh` で「検知して警告のみ」 | ◎ `ollama serve` / `brew services start ollama` / launchd 化可 |
| ログ | GUI 内のみ、tail 困難 | stderr / `~/.ollama/logs/server.log` |
| プロセス監視 | `lsof -ti:1234` で port は見えるがロード状態は不明 | `curl /api/ps` で「現在ロード中のモデル」が JSON で取れる |
| 設定の declarative 化 | ✗ GUI 操作のみ (model load / temperature / system prompt) | ◎ `Modelfile` で git 管理可 |
| モデル切替 API | OpenAI compat の範囲のみ | `/api/pull` / `/api/load` で programmatic に可能 |
| OpenAI compat API | ◎ (port 1234) | ◎ (port 11434) |

## 2. OLV (Open-LLM-VTuber) provider 実装の深さ比較

OLV repo (`Open-LLM-VTuber/src/open_llm_vtuber/agent/stateless_llm/`) の provider 実装を見ると、**Ollama 専用 provider は単なる OpenAI compat ラッパーではなく、Ollama 固有 API を叩いている**。

### `ollama_llm.py` (抜粋)

```python
class OllamaLLM(AsyncLLM):
    def __init__(self, ..., keep_alive: float = -1, unload_at_exit: bool = True):
        ...
        # preload model — KV cache warmup を OLV が自動でやる
        requests.post(base_url.replace("/v1", "") + "/api/chat",
                      json={"model": model, "keep_alive": keep_alive})
        # atexit に unload を登録 (keep_alive < 0 の場合)
```

実装が提供する機能:

| 機能 | 効果 |
|---|---|
| `/api/chat` への preload リクエスト | OLV 起動時に KV cache を構築 → **現状の `warmup_llm` (avatar-helpers.sh) が不要になる** |
| `keep_alive: -1` | OLV 生存中はモデル常時ホット (Cold start なし) |
| `atexit` での unload | OLV 終了時に自動でメモリ解放 → M1 Pro 32GB のメモリ衛生改善 |

### `lmstudio_llm` の扱い

`stateless_llm_factory.py:33` を見ると `lmstudio_llm` は **OpenAI compat と同じコードパスに合流するのみ**。Ollama のような lifecycle 制御は持たない。

```python
if (llm_provider == "openai_compatible_llm"
    or llm_provider == "lmstudio_llm"):  # ← 同列扱い
    ...
```

つまり OLV から見ると **Ollama は「first-class citizen」、LM Studio は「OpenAI compat の名前違い」**。

## 3. 設定切替時の差分 (理論値)

OLV `conf.yaml` の差分は YAML 1 ブロックのみ。

```yaml
# 現在 (LM Studio)
agent_settings:
  basic_memory_agent:
    llm_provider: lmstudio_llm
llm_configs:
  lmstudio_llm:
    model: llama-3.1-swallow-8b-instruct-v0.5
    base_url: http://localhost:1234/v1
    temperature: 0.7

# Ollama に切替する場合
agent_settings:
  basic_memory_agent:
    llm_provider: ollama_llm
llm_configs:
  ollama_llm:
    model: <Ollama 上の model id — §5-未解決 2 参照>
    base_url: http://localhost:11434/v1
    temperature: 0.7
    keep_alive: -1
    unload_at_exit: true
```

`avatar-start.sh` 側も Step 2 が「警告のみ」から**実際に起動できる数行**になる:

```bash
# 現在 (warn のみ)
warn "LM Studio.app を起動 → 'llama-3.1-swallow-8b...' を Load → Local Server を ON"

# Ollama 切替後の想定
if ! curl -s --max-time 2 "http://localhost:11434/api/tags" >/dev/null; then
  ollama serve &  # or `brew services start ollama`
fi
ollama show llama-3.1-swallow-8b >/dev/null 2>&1 || ollama pull <model>
# OLV 側の OllamaLLM provider が起動時に preload するので warmup_llm 不要
```

## 4. 推奨

- **即時切替は推奨しない**。pipeline 研究の「3 つの NO」のうち **NO GGUF on Mac** は依然有効で、Ollama 採用 = GGUF fallback を強いられる場合 TTFT が 0.4s → 0.7s (~1.7x) に劣化する。Phase 4b で達成済の「初音 1491ms < budget 2.5s」が崩れる可能性
- ただし**運用負荷の高い局面で再評価する価値はある**:
  - Phase 6 の「30 分稼働」要件で自動再起動・再ロードが必要になった時
  - Avatar を CI/launchd で完全自動起動したくなった時
  - 複数モデルを programmatic に切替したくなった時 (キャラ別 system prompt × モデル組合せ等)
- 切替判断には **§5 の未解決 3 項目** を先に確認する必要がある

## 5. 未解決の調査項目 (Phase 7 候補)

| # | 項目 | 確認方法 | これが解ければ何が決まるか |
|---|---|---|---|
| 1 | Ollama MLX backend の 2026-05 時点 stability | Ollama 最新リリースの release notes、`OLLAMA_USE_MLX` / `--backend mlx` flag が GA 昇格したか | stable なら速度劣後の理由が消える → 切替コスト最大の障害解消 |
| 2 | `mlx-community/Llama-3.1-Swallow-8B-Instruct-v0.5-4bit` の Ollama ロード可否 | `ollama pull hf.co/mlx-community/...` で食えるか、`Modelfile FROM` でラップが必要か、GGUF 版 (`mradermacher/...` 等) に乗り換えるかの 3 択 | 採用モデル決定。GGUF 版に乗り換える場合は別途品質回帰の確認が必要 |
| 3 | TTFT 実測比較 | 上記 2 を満たした上で `warmup_llm` 相当を Ollama で実施し、`ttft` / `ttft_sys` (avatar-helpers.sh) を流用してベンチ | LM Studio (0.4s) と互角なら切替価値あり / 0.7s 級なら Phase 4b budget を再評価する必要 |

副次論点 (後追いで OK):

- `keep_alive: -1` 設定時の Unified Memory 占有量 (8B モデルで ~5GB 想定、M1 Pro 32GB なら余裕だが他作業との競合に注意)
- OLV `OllamaLLM` の `unload_at_exit` 挙動が Phase 5 のキャラ persona 切替に与える影響 (毎回 cold start にならないか)
- Swallow 8B 以外で Ollama 側が強い model (例: `gpt-oss`, `qwen2.5:7b-instruct-q4_K_M`) を試す価値

## 6. 関連ファイル / 参照

- 現構成: [`./README.md`](./README.md)
- 自動起動スクリプトの痛点: [`./avatar-start.sh`](./avatar-start.sh) L84-93
- helpers: [`./avatar-helpers.sh`](./avatar-helpers.sh) (lab snapshot、SoT は pipeline 側)
- OLV LM Studio 適用手順: [`./phase5-live2d/olv-patches/conf-overrides.md`](./phase5-live2d/olv-patches/conf-overrides.md)
- pipeline 側 runtime 比較: `../../../ai-research-pipeline/features/deep-research/research/m1-pro-local-llm-for-avatar/02-analysis.md` §2.6
- OLV Ollama provider 実装: `Open-LLM-VTuber/src/open_llm_vtuber/agent/stateless_llm/ollama_llm.py` (lab 外)

## 7. 進め方の提案

このドキュメントは **論点整理まで**。次のアクションは以下のいずれか:

1. 上記 §5 の項目 1 (Ollama MLX stability) を Web 調査で 30 分以内に確認 → GO/NO-GO 判断
2. `deep-research/m1-pro-local-llm-for-avatar/phase7-ollama-bench/` (仮) として実装 slug を切り、項目 2-3 を実機で検証
3. HOLD のまま保留 (Phase 6 完了後に再評価)
