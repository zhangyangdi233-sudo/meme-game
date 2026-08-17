#!/usr/bin/env python3
"""Generate deterministic lo-fi audio for the standalone Babel game."""

from __future__ import annotations

import argparse
import hashlib
import math
import os
import random
import struct
import wave
from collections.abc import Callable


ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "generated", "audio")
SAMPLE_RATE = 22_050
TAU = math.tau
EXPECTED_SHA256 = {
	"action_tick.wav": "776a93f470b53d5691d4ab338ddcab6a8eaf3a85f88e54df42666ddbefd4a2e0",
	"pollution_flashback.wav": "154a71cbcd0d2d75468a85e4f7f9d1b13b22d7769557b456fb0cfb0a394b4584",
	"reality_room_loop.wav": "c13f97fee2ae5c35efb51d4f3425d370922966c51f26ab683b2787d995403c9c",
	"phone_road_loop.wav": "e19219a86670f9f41b9af12501a005146d983da2e0fb0bb60ca3e3f874e692b7",
}


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
	return max(low, min(high, value))


def write_wav(filename: str, duration: float, sample_fn: Callable[[float, int], float]) -> None:
	frame_count = round(duration * SAMPLE_RATE)
	samples = [sample_fn(index / SAMPLE_RATE, index) for index in range(frame_count)]
	peak = max(0.001, max(abs(sample) for sample in samples))
	normalization = 0.82 / peak
	pcm = bytearray()
	for sample in samples:
		pcm.extend(struct.pack("<h", round(clamp(sample * normalization) * 32767)))
	os.makedirs(OUT_DIR, exist_ok=True)
	with wave.open(os.path.join(OUT_DIR, filename), "wb") as wav_file:
		wav_file.setnchannels(1)
		wav_file.setsampwidth(2)
		wav_file.setframerate(SAMPLE_RATE)
		wav_file.writeframes(bytes(pcm))


def phone_road_sample(t: float, _index: int) -> float:
	breath = 0.78 + 0.12 * math.sin(TAU * 0.25 * t)
	hum = 0.34 * math.sin(TAU * 45.0 * t) + 0.12 * math.sin(TAU * 90.0 * t)
	road = 0.055 * math.sin(TAU * 713.0 * t + 0.7 * math.sin(TAU * 0.5 * t))
	road += 0.035 * math.sin(TAU * 1193.0 * t + 0.3 * math.sin(TAU * 0.25 * t))
	pulse_gate = max(0.0, math.sin(TAU * 0.5 * t)) ** 12
	pulse = pulse_gate * 0.10 * math.sin(TAU * 238.0 * t)
	return hum * breath + road + pulse


def reality_room_sample(t: float, _index: int) -> float:
	room = 0.28 * math.sin(TAU * 50.0 * t) + 0.08 * math.sin(TAU * 100.0 * t)
	electric = 0.025 * math.sin(TAU * 799.0 * t + math.sin(TAU * 0.125 * t))
	breathing = (0.68 + 0.18 * math.sin(TAU * 0.125 * t)) * room
	return breathing + electric


def _phase_envelope(t: float, start: float, end: float, attack: float = 0.02, release: float = 0.03) -> float:
	if t < start or t > end:
		return 0.0
	rise = min(1.0, (t - start) / max(attack, 1e-6))
	fall = min(1.0, (end - t) / max(release, 1e-6))
	return max(0.0, min(rise, fall))


def build_flashback_samples(duration: float) -> list[float]:
	"""3.70s 八拍闪回音轨,与 pollution_flashback_director.gd 的相位表逐拍对位。

	原创合成层:房间底噪(先死)、布料摩擦、电话带宽语音占位、单次门扣与反向尾音、
	高频耳鸣细线、保存点击与编排静默。无采样、无爆音、无尖叫;最响的事件是静默本身。
	"""
	rng = random.Random(60013)
	frame_count = round(duration * SAMPLE_RATE)
	result: list[float] = []
	latch_time = 2.60
	for index in range(frame_count):
		t = index / SAMPLE_RATE
		value = 0.0

		# P0 冻结 0.00-0.50:房间底噪保持,0.34 起迅速死掉(声音预兆先于黑场)。
		room_gate = 1.0 if t < 0.34 else max(0.0, 1.0 - (t - 0.34) / 0.06)
		if room_gate > 0.0:
			room = 0.30 * math.sin(TAU * 50.0 * t) + 0.09 * math.sin(TAU * 100.0 * t)
			value += room * room_gate * (0.7 + 0.1 * math.sin(TAU * 0.5 * t))

		# P2 玩偶场 0.70-1.45:很近的布料摩擦(三次抚摸状噪声),外加一次低呼吸前音。
		cloth_env = _phase_envelope(t, 0.72, 1.40, 0.05, 0.08)
		if cloth_env > 0.0:
			stroke = max(0.0, math.sin(TAU * 2.0 * (t - 0.72))) ** 3
			cloth = rng.uniform(-1.0, 1.0) * 0.16 * stroke
			cloth += 0.05 * math.sin(TAU * 118.0 * t) * _phase_envelope(t, 0.72, 0.95, 0.06, 0.1)
			value += cloth * cloth_env

		# P4 医生场 1.62-2.37:电话带宽的语音占位(共振峰式音节包络,不构成词)。
		voice_env = _phase_envelope(t, 1.64, 2.32, 0.03, 0.05)
		if voice_env > 0.0:
			syllable = max(0.0, math.sin(TAU * 3.4 * (t - 1.64))) ** 2
			formants = (
				0.16 * math.sin(TAU * 340.0 * t)
				+ 0.10 * math.sin(TAU * 1180.0 * t + 0.8)
				+ 0.05 * math.sin(TAU * 2420.0 * t + 1.9)
			)
			narrowband = formants * syllable
			narrowband = round(narrowband * 24.0) / 24.0  # 轻度带宽压缩质感
			value += narrowband * voice_env

		# P5-P7 耳鸣细线 2.37-3.28:接近听觉边缘的高频正弦,极低电平。
		tinnitus_env = _phase_envelope(t, 2.37, 3.28, 0.20, 0.10)
		if tinnitus_env > 0.0:
			value += 0.035 * math.sin(TAU * 9700.0 * t) * tinnitus_env

		# P6 三重错位 2.57-2.95:远处单次门扣,尾音反向渐强但不形成尖叫。
		if latch_time <= t < latch_time + 0.05:
			latch_t = t - latch_time
			value += math.exp(-latch_t * 90.0) * (0.5 * math.sin(TAU * 1280.0 * latch_t) + rng.uniform(-0.3, 0.3))
		reversed_tail_env = _phase_envelope(t, latch_time + 0.06, 2.93, 0.24, 0.01)
		if reversed_tail_env > 0.0:
			value += rng.uniform(-1.0, 1.0) * 0.05 * reversed_tail_env * reversed_tail_env

		# P7 残响回归 2.95-3.28:半电平房间底噪带缓慢晃动,然后被硬切。
		return_env = _phase_envelope(t, 2.95, 3.28, 0.04, 0.008)
		if return_env > 0.0:
			wobble = 1.0 + 0.012 * math.sin(TAU * 1.7 * t)
			room_return = 0.16 * math.sin(TAU * 50.0 * wobble * t) + 0.05 * math.sin(TAU * 100.0 * wobble * t)
			grain = 1.0 + 0.22 * math.sin(TAU * 120.0 * t)
			value += room_return * grain * return_env

		# P8 空方框 3.30-3.55:静默中的一次很轻的保存点击(3.42)。
		if 3.42 <= t < 3.46:
			click_t = t - 3.42
			value += math.exp(-click_t * 160.0) * 0.22 * math.sin(TAU * 640.0 * click_t)

		fade = min(1.0, t / 0.02, (duration - t) / 0.04)
		result.append(value * max(0.0, fade))
	return result


def write_samples(filename: str, samples: list[float]) -> None:
	peak = max(0.001, max(abs(sample) for sample in samples))
	pcm = bytearray()
	for sample in samples:
		pcm.extend(struct.pack("<h", round(clamp(sample * 0.88 / peak) * 32767)))
	os.makedirs(OUT_DIR, exist_ok=True)
	with wave.open(os.path.join(OUT_DIR, filename), "wb") as wav_file:
		wav_file.setnchannels(1)
		wav_file.setsampwidth(2)
		wav_file.setframerate(SAMPLE_RATE)
		wav_file.writeframes(bytes(pcm))


def action_tick_sample(t: float, _index: int) -> float:
	envelope = math.exp(-t * 28.0)
	return envelope * (0.42 * math.sin(TAU * 620.0 * t) + 0.16 * math.sin(TAU * 82.0 * t))


def verify_audio_assets() -> None:
	for filename, expected_hash in EXPECTED_SHA256.items():
		path = os.path.join(OUT_DIR, filename)
		if not os.path.exists(path):
			raise FileNotFoundError(f"Missing generated audio asset: {filename}")
		with open(path, "rb") as audio_file:
			actual_hash = hashlib.sha256(audio_file.read()).hexdigest()
		if actual_hash != expected_hash:
			raise RuntimeError(f"Generated audio changed unexpectedly: {filename}")


def main() -> None:
	parser = argparse.ArgumentParser()
	parser.add_argument("--verify", action="store_true", help="verify generated audio without writing files")
	args = parser.parse_args()
	if args.verify:
		verify_audio_assets()
		return
	write_wav("phone_road_loop.wav", 8.0, phone_road_sample)
	write_wav("reality_room_loop.wav", 8.0, reality_room_sample)
	write_samples("pollution_flashback.wav", build_flashback_samples(3.70))
	write_wav("action_tick.wav", 0.18, action_tick_sample)
	verify_audio_assets()


if __name__ == "__main__":
	main()
