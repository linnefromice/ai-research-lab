# OLV (Open-LLM-VTuber v1.2.1) patches — Phase 5 D1=A 適用

Phase 5 サブタスク 4 で実装した OLV への 拡張 patch の snapshot。
**OLV 本体は lab 外** (`~/projects/Open-LLM-VTuber` 等) にあり、本ディレクトリは
OLV repo に対して当てる差分のみ保管する (lab is public で OLV 本体を抱え込まない方針)。

## 内容

| ファイル | 内容 | 行数 |
|---|---|---|
| `voicevox_tts.py` | 新規作成、`src/open_llm_vtuber/tts/voicevox_tts.py` に置く | ~60 |
| `tts_factory.patch` | `src/open_llm_vtuber/tts/tts_factory.py` への factory branch 追加 | +8 |
| `config_manager_tts.patch` | `src/open_llm_vtuber/config_manager/tts.py` への Pydantic schema 拡張 (5 箇所) | +29 |
| `conf-overrides.md` | `conf.yaml` に当てる yq コマンド一覧 + persona V2 全文 | — |

## 適用手順

OLV を `v1.2.1` tag に checkout 済みの前提:

```bash
OLV=~/projects/Open-LLM-VTuber  # ご自身の OLV repo path に置き換え
PATCHES=$(pwd)  # この olv-patches/ ディレクトリの絶対パス想定

# 1. 新規 plugin file
cp "$PATCHES/voicevox_tts.py" "$OLV/src/open_llm_vtuber/tts/voicevox_tts.py"

# 2. factory + schema patch
git -C "$OLV" apply --check < "$PATCHES/tts_factory.patch"
git -C "$OLV" apply < "$PATCHES/tts_factory.patch"
git -C "$OLV" apply --check < "$PATCHES/config_manager_tts.patch"
git -C "$OLV" apply < "$PATCHES/config_manager_tts.patch"

# 3. conf.yaml 編集 (conf-overrides.md 参照、yq で適用)

# 4. 起動
cd "$OLV" && uv run run_server.py
# Browser: http://localhost:12393
```

## License / 帰属

`voicevox_tts.py` は本 lab repo の license に従う (lab は public、上流規約と整合)。
OLV 本体は MIT、Phase 5 採用時は `v1.2.1` tag pin (D1 決断、v1.3+ で license 変更予定の回避)。
パッチを upstream PR として提出するかは未決 (Phase 5 完了後の検討事項)。

## Phase 5 サブタスク 4 で得た知見

- **OLV plugin 自作は 3 階層触る必要あり**: (a) impl class、(b) factory registration、(c) Pydantic schema (5 箇所)
- 研究の「50-100 行 plugin」は (a)+(b) のみ前提で、(c) schema は研究見積もりにない overhead
- Pydantic Literal 型で `tts_model` を縛る設計は OLV の防御策として合理 (起動時に invalid config を弾く)
- 詳細は親 `phase5-live2d/README.md` の「サブタスク 3-7 実装ログ」節
