import os
import urllib.parse
import urllib.request

from loguru import logger
from .tts_interface import TTSInterface


# VOICEVOX TTS plugin (Open-LLM-VTuber 拡張)
#
# 起点: Phase 5 D1=A 採用 (Open-LLM-VTuber v1.2.x 本命)、ただし VOICEVOX native 未サポート
#       のため tts_factory.py に plugin を自作する方針 (50-100 行想定)。
# 実装: ai-research-pipeline Phase 4b の chunker.py 内 synth_voicevox (urllib 直叩き)
#       を class 化して移植。stdlib のみ依存。
# Engine: docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest
# Voices: GET http://127.0.0.1:50021/speakers で取得可能。Phase 4b で
#         ID 8 (春日部つむぎ:ノーマル) を採用 (warm 中央値 534ms、budget < 700ms 達成)。


class TTSEngine(TTSInterface):
    def __init__(
        self,
        base_url: str = "http://127.0.0.1:50021",
        speaker_id: int = 8,
    ):
        self.base_url = (base_url or "http://127.0.0.1:50021").rstrip("/")
        self.speaker_id = int(speaker_id) if speaker_id is not None else 8

        self.file_extension = "wav"
        self.new_audio_dir = "cache"
        if not os.path.exists(self.new_audio_dir):
            os.makedirs(self.new_audio_dir)

    def generate_audio(self, text, file_name_no_ext=None):
        """
        VOICEVOX engine に /audio_query → /synthesis の 2 step request を投げ、
        WAV ファイルを cache/ に保存してパスを返す。
        """
        file_name = self.generate_cache_file_name(file_name_no_ext, self.file_extension)

        try:
            qparams = urllib.parse.urlencode({"text": text, "speaker": self.speaker_id})
            qreq = urllib.request.Request(
                f"{self.base_url}/audio_query?{qparams}",
                method="POST",
            )
            with urllib.request.urlopen(qreq, timeout=10) as r:
                query = r.read()

            sreq = urllib.request.Request(
                f"{self.base_url}/synthesis?speaker={self.speaker_id}",
                data=query,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            with urllib.request.urlopen(sreq, timeout=30) as r:
                wav = r.read()

            with open(file_name, "wb") as f:
                f.write(wav)
        except Exception as e:
            logger.critical(f"\nError: voicevox-tts unable to generate audio: {e}")
            logger.critical(
                f"Check VOICEVOX engine running at {self.base_url} "
                f"(docker run -d --name voicevox -p 50021:50021 voicevox/voicevox_engine:cpu-arm64-latest)"
            )
            return None

        return file_name
