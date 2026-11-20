# 地下室耳語的來源

- `basement_whisper_8s.wav`：第二圈耳語事件播放的 8 秒耳語。由六段耳語短音依不規則節奏重新排列而成，單聲道 PCM16 / 44100 Hz / 正好 8 秒，不循環，沒有生成新的人聲。
- 短音的源錄音是 Thorsten Müller / Thorsten-Voice 的真實耳語錄音，CC0 1.0，完整授權見 `THORSTEN_CC0.txt`。
- 精確的源路徑、SHA-256 與剪輯時間表見 `voice_sources.json`。

來源：https://github.com/thorstenMueller/Thorsten-Voice

源錄音：https://raw.githubusercontent.com/thorstenMueller/Thorsten-Voice/master/samples/thorsten-21.06-emotional/whisper.wav

錄音身分紀錄：https://github.com/thorstenMueller/Thorsten-Voice/blob/6efb25310a303af541d83047627c0f4d79aaad7c/README.md

`03_muted_narrator/`（企劃選的旁白單音 `blip_01.wav`–`blip_06.wav`，專案自行合成、不含第三方錄音）已從舊版複製回來，開場旁白逐字播放（`scripts/audio/narration_blips.gd`，執行時用 `AudioStreamWAV.load_from_file` 載入，不經匯入）。原因：負責人比對舊版後發現 demo 少了旁白聲。`voice_sources.json` 裡 `03_muted_narrator/` 的路徑與 SHA-256 即這六個檔案。

`voice_sources.json` 列到的 `D_whisper_fragments/`（耳語短音）目前遊戲沒有用到，只留在 `main` 的歷史裡（commit `a5ad585`）。
