# 已选旁白与地下室耳语

- `03_muted_narrator/`：用户选中的第一组 03，六个单音原样复制。项目内原创程序合成，不含第三方录音。原生成器位于外层工作区 `tools/generate_dialogue_blip_previews.py`。
- `D_whisper_fragments/`：用户保留的 D 耳语，六个单音原样复制。源录音为 Thorsten Müller / Thorsten-Voice 的真实耳语录音，CC0 1.0。完整许可证见 `THORSTEN_CC0.txt`。
- `basement_whisper_8s.wav`：D 的六个单音按不规则节奏重新排列，单声道 PCM16 / 44100 Hz / 恰好 8 秒；不循环。未生成新的人声。
- 精确源路径、文件 SHA256 和剪辑时间表见 `voice_sources.json`；可用外层 `tools/build_chapter_voice_assets.py` 重建。

来源：https://github.com/thorstenMueller/Thorsten-Voice

源录音：https://raw.githubusercontent.com/thorstenMueller/Thorsten-Voice/master/samples/thorsten-21.06-emotional/whisper.wav

录音身份记录：https://github.com/thorstenMueller/Thorsten-Voice/blob/6efb25310a303af541d83047627c0f4d79aaad7c/README.md
