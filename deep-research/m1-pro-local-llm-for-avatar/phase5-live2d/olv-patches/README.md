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
| `apply-patches.sh` | 上記 3 つを冪等に適用するスクリプト | — |
| `conf-overrides.md` | `conf.yaml` に当てる yq コマンド一覧 + persona V2 全文 | — |

## 他環境でゼロから再現する手順

### 前提

- macOS (M1/M1 Pro 想定、Intel でも理屈は同じ)
- Docker (VOICEVOX 用)
- LM Studio.app (LLM 用、手動起動)
- `uv` または `pixi` (OLV の依存解決)
- `yq` v4 (mikefarah、conf.yaml 編集用)
- `git`

### Step 1. OLV repo を clone + v1.2.1 に pin

`OLV_DIR` は任意の場所で OK (例: `~/projects/Open-LLM-VTuber`、`~/repository/.../Open-LLM-VTuber`)。
以降の手順で `$OLV_DIR` 環境変数として参照する:

```bash
export OLV_DIR=~/projects/Open-LLM-VTuber   # ご自身が clone したい場所
git clone https://github.com/Open-LLM-VTuber/Open-LLM-VTuber.git "$OLV_DIR"
cd "$OLV_DIR"
git checkout v1.2.1   # Phase 6「踏まないリスト」、v1.3+ では license 変更予定
git submodule update --init --recursive   # frontend (Open-LLM-VTuber-Web build branch) を取得
```

### Step 2. 依存解決

```bash
cd "$OLV_DIR"
uv sync   # or `pixi install`
```

### Step 3. lab patches を適用

`apply-patches.sh` を `$OLV_DIR` 引数付きで実行 (冪等):

```bash
# lab repo の olv-patches/ ディレクトリで
cd /path/to/ai-research-lab/deep-research/m1-pro-local-llm-for-avatar/phase5-live2d/olv-patches
./apply-patches.sh "$OLV_DIR"
```

期待出力 (初回):

```
[ok]   voicevox_tts.py 配置 → src/open_llm_vtuber/tts/voicevox_tts.py
[ok]   tts_factory.patch 適用
[ok]   config_manager_tts.patch 適用
```

再実行時は全て `[skip]` になる。

### Step 4. `conf.yaml` を生成 + 編集

```bash
cd "$OLV_DIR"
cp config_templates/conf.default.yaml conf.yaml
```

[`./conf-overrides.md`](./conf-overrides.md) の yq コマンド一覧を順に実行し、
`character_name` / `persona_prompt` / `llm_provider` / `tts_config` を上書きする。

### Step 5. Live2D モデル

`mao_pro` は OLV v1.2.1 に **同梱**されている (`$OLV_DIR/live2d-models/mao_pro/`)。
追加の DL 作業は不要。`conf-overrides.md` の `live2d_model_name: mao_pro` はそのまま機能する。

### Step 6. VOICEVOX engine を Docker で起動

```bash
docker run -d --name voicevox \
  -p 50021:50021 \
  voicevox/voicevox_engine:cpu-arm64-latest
```

ARM64 (M1/M2) 以外の Mac は `cpu-ubuntu20.04-latest` 等に置き換え。

### Step 7. LM Studio で Swallow 8B をロード

LM Studio.app を起動し、以下を実施:

1. `mlx-community/Llama-3.1-Swallow-8B-Instruct-v0.5-4bit` をダウンロード
2. モデルをロード
3. `Local Server` を ON (port 1234)

(自動化不可。`avatar-start.sh` の Step 2 で応答チェックは行うが、起動自体は手動)

### Step 8. avatar 起動

```bash
cd /path/to/ai-research-lab/deep-research/m1-pro-local-llm-for-avatar
OLV_DIR="$OLV_DIR" ./avatar-start.sh
```

`http://localhost:12393` がブラウザで自動的に開く。

## ファイル単位の手動適用 (apply-patches.sh を使わない場合)

OLV を `v1.2.1` tag に checkout 済みの前提:

```bash
PATCHES=$(pwd)  # この olv-patches/ ディレクトリの絶対パス想定

# 1. 新規 plugin file
cp "$PATCHES/voicevox_tts.py" "$OLV_DIR/src/open_llm_vtuber/tts/voicevox_tts.py"

# 2. factory + schema patch
git -C "$OLV_DIR" apply --check < "$PATCHES/tts_factory.patch"
git -C "$OLV_DIR" apply < "$PATCHES/tts_factory.patch"
git -C "$OLV_DIR" apply --check < "$PATCHES/config_manager_tts.patch"
git -C "$OLV_DIR" apply < "$PATCHES/config_manager_tts.patch"
```

## トラブルシュート

| 症状 | 原因 / 対処 |
|---|---|
| `apply-patches.sh` が `[error] ... 適用も検出もできません` | OLV が `v1.2.1` 以外にいる可能性。`git -C "$OLV_DIR" describe --tags` で確認 |
| `apply-patches.sh` の出力で `[ok]` の後に再実行で `[ok]` が再度出る | (本来 skip になるはず) lab の patch が更新された可能性。`git diff` で確認 |
| `avatar-start.sh` が `OLV_DIR が未設定` で終了 | 環境変数を渡し忘れ。`OLV_DIR=/path/to/Open-LLM-VTuber ./avatar-start.sh` |
| OLV 起動時に `voicevox_tts` not found | apply-patches.sh が走っていない / `uv sync` 後にもう一度 import path 確認 |
| ブラウザで Live2D モデルが出ない | OLV submodule (`frontend`) が init されていない可能性。`git submodule update --init --recursive` |

## License / 帰属

`voicevox_tts.py` は本 lab repo の license に従う (lab は public、上流規約と整合)。
OLV 本体は MIT、Phase 5 採用時は `v1.2.1` tag pin (D1 決断、v1.3+ で license 変更予定の回避)。
パッチを upstream PR として提出するかは未決 (Phase 5 完了後の検討事項)。

## Phase 5 サブタスク 4 で得た知見

- **OLV plugin 自作は 3 階層触る必要あり**: (a) impl class、(b) factory registration、(c) Pydantic schema (5 箇所)
- 研究の「50-100 行 plugin」は (a)+(b) のみ前提で、(c) schema は研究見積もりにない overhead
- Pydantic Literal 型で `tts_model` を縛る設計は OLV の防御策として合理 (起動時に invalid config を弾く)
- 詳細は親 `phase5-live2d/README.md` の「サブタスク 3-7 実装ログ」節
