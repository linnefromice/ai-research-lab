# OLV `conf.yaml` への lab 拡張上書き

Phase 5 採用時、`$OLV/conf.yaml` を `config_templates/conf.default.yaml` から
copy した直後に以下を yq で適用する。

## キー一覧

| キー | 値 | 由来 |
|---|---|---|
| `character_config.character_name` | `ナオ` | 表示名 (`live2d_model_name: mao_pro` は filesystem 参照なので変更しない) |
| `character_config.persona_prompt` | (V2、下記) | Phase 4b chunker.py の NEW_SP から「あんまり詳しくないかも」 hard-code を削除した版 |
| `character_config.agent_config.agent_settings.basic_memory_agent.llm_provider` | `lmstudio_llm` | D1=A + Phase 4a Swallow 採用 |
| `character_config.agent_config.agent_settings.basic_memory_agent.use_mcpp` | `false` | Phase 5 Minimum で MCP は不要、起動時 surface area 最小化 |
| `character_config.agent_config.llm_configs.lmstudio_llm.model` | `llama-3.1-swallow-8b-instruct-v0.5` | LM Studio 上の model id |
| `character_config.agent_config.llm_configs.lmstudio_llm.temperature` | `0.7` | Phase 4b chunker.py との整合 |
| `character_config.tts_config.tts_model` | `voicevox_tts` | サブタスク 4 で自作の plugin |
| `character_config.tts_config.voicevox_tts.base_url` | `http://127.0.0.1:50021` | `docker run -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest` |
| `character_config.tts_config.voicevox_tts.speaker_id` | `8` | 春日部つむぎ:ノーマル (Phase 4b 確定、warm 中央値 534ms) |

## yq コマンド (yq v4 mikefarah)

```bash
OLV=~/projects/Open-LLM-VTuber   # ご自身の path に置き換え

# ナオ persona V2 (一字エスケープ不要、env var 経由で安全に渡す)
export NAO_PERSONA='あなたは「ナオ」という物静かなタイプのアイドル的なキャラクターです。一人称は「私」、相手のことは「キミ」と呼びます。物静かで人見知りですが、落ち着いた優しいトーンで話します。比較的インドアでアニメの話になると少しテンションが上がります。1〜2文だけで簡潔に答え、3文以上はNG、絵文字は使わないでください。好きなジャンルは日常系アニメ。『ゆるキャン△』はキャンプの雰囲気、『のんのんびより』は田舎の静けさ、『けいおん！』はのんびりした部活感が好きで、それ以外の細かい設定は知ったかぶりせず曖昧に答えます。インドア寄りで、ほうじ茶とおせんべいが好き。趣味は読書と短い散歩。スポーツ・流行りの芸能人・最新のファッションには疎いです。知らないことは無理に断定せず、曖昧でも素直に答えてください。作品の細部を勝手に作らないでください。政治・宗教・戦争には踏み込みません。なお、ユーザーの発話に「なお」「ナオ」が含まれる場合は、あなた自身への呼びかけと解釈してください。'

yq -i '.character_config.character_name = "ナオ"' "$OLV/conf.yaml"
yq -i '.character_config.persona_prompt = strenv(NAO_PERSONA)' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.agent_settings.basic_memory_agent.llm_provider = "lmstudio_llm"' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.agent_settings.basic_memory_agent.use_mcpp = false' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.lmstudio_llm.model = "llama-3.1-swallow-8b-instruct-v0.5"' "$OLV/conf.yaml"
yq -i '.character_config.agent_config.llm_configs.lmstudio_llm.temperature = 0.7' "$OLV/conf.yaml"
yq -i '.character_config.tts_config.tts_model = "voicevox_tts"' "$OLV/conf.yaml"
yq -i '.character_config.tts_config.voicevox_tts.base_url = "http://127.0.0.1:50021"' "$OLV/conf.yaml"
yq -i '.character_config.tts_config.voicevox_tts.speaker_id = 8' "$OLV/conf.yaml"
```

## ⚠️ 落とし穴 (Phase 5 でやらかした)

- **`tts_config` は `character_config` 配下にネスト** されている。`.tts_config.*` (top level) で書こうとすると yq が rogue な top-level key を作ってしまう。`.character_config.tts_config.*` を必ず指定。
- 修復法 (やらかした場合): `yq -i 'del(.tts_config)' conf.yaml` で rogue key を削除 → 正しい path で書き直し。
- 編集後は `yq 'keys' conf.yaml` で top-level key が `system_config / character_config / live_config` の 3 つだけになっているか確認。

## persona V1 → V2 の差分

```diff
- 知らないことは「んー、あんまり詳しくないかも」と素直に言い、作品の細部を勝手に作らないでください。
+ 知らないことは無理に断定せず、曖昧でも素直に答えてください。作品の細部を勝手に作らないでください。
```

理由: 副次発見として 2026-04-30 の chat session で 11 ターン中 4 回 (36%)
「あんまり詳しくないかも」 が出現。朝の挨拶や、答えた直後にも付くなど不自然な
使用パターンが多発。**hard-code フレーズが LLM に定型語尾として過学習される**
傾向と判断し、具体フレーズの hard-code を外して trait 指示のみに緩和。
