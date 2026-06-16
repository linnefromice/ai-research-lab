# ai-research-lab — 実験エントリーポイント集約
# 一覧: `just` または `just --list`   /   要: just (brew install just)
#
# 各実験スクリプトは従来どおり各フォルダ配下に置いたまま。この justfile は
# それをルートから叩くための薄いラッパー。詳細は各実験 README の「実行方法」節。

avatar := 'deep-research/m1-pro-local-llm-for-avatar'
readable_md := 'deep-research/readable-md-pipeline/readable-md'
md_to_html := 'deep-research/readable-md-pipeline/md-to-html'
md_to_slide := 'deep-research/readable-md-pipeline/md-to-slide'
md_pipeline := 'deep-research/readable-md-pipeline'
md_review := 'deep-research/readable-md-pipeline/review'

# コマンド一覧を表示
default:
    @just --list

# 読みやすい md か構造チェック (例: just md-check path/to/x.md ; --lint で markdownlint も)
md-check *args:
    {{readable_md}}/scripts/check-readable-md.sh {{args}}

# readable-md バンドルを任意プロジェクトへ持ち込む (例: just md-install /path/to/proj)
md-install *args:
    {{readable_md}}/install.sh {{args}}

# md → テーマ付き HTML を決定論変換 (例: just md-html path/to/x.md ; -o で出力先)
md-html *args:
    {{md_to_html}}/scripts/render-html.sh {{args}}

# md-to-html バンドルを任意プロジェクトへ持ち込む (例: just md-html-install /path/to/proj)
md-html-install *args:
    {{md_to_html}}/install.sh {{args}}

# Marp slides.md を HTML/PDF/PPTX にビルド (例: just slides-build x.slides.md --all)
slides-build *args:
    {{md_to_slide}}/scripts/build-slides.sh {{args}}

# md-to-slide バンドルを任意プロジェクトへ持ち込む (例: just slides-install /path/to/proj)
slides-install *args:
    {{md_to_slide}}/install.sh {{args}}

# パイプライン 3 Stage を任意プロジェクトへ一括導入 (例: just pipeline-install /path/to/proj)
pipeline-install *args:
    {{md_pipeline}}/install.sh {{args}}

# 生成 HTML の見た目を C.R.A.P. デザイン監査 (例: just design-audit path/to/x.html)
design-audit *args:
    {{md_review}}/scripts/design-audit.sh {{args}}

# seed から theme を生成 (例: just gen-theme --hue 200 --out /tmp/t.html)
gen-theme *args:
    {{md_review}}/scripts/gen-theme.sh {{args}}

# Live2D アバター「ナオ」を起動 (VOICEVOX + LM Studio 検知 + OLV)
avatar-start:
    cd {{avatar}} && ./avatar-start.sh

# VOICEVOX TTS 初音 latency ベンチ (env: SPEAKER_ID / TEXT / TRIALS)
tts-bench-voicevox:
    cd {{avatar}}/phase4b-tts-bench && ./bench-voicevox.sh

# AivisSpeech TTS 初音 latency ベンチ (env: SPEAKER_ID / TEXT / TRIALS)
tts-bench-aivisspeech:
    cd {{avatar}}/phase4b-tts-bench && ./bench-aivisspeech.sh

# persona V1/V2 マトリクス検証 (例: just persona-verify --smoke)
persona-verify *args:
    cd {{avatar}}/phase4b-llm-stream-chunker && python verify-persona-matrix.py {{args}}
