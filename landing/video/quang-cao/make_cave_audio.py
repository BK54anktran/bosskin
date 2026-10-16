#!/usr/bin/env python3
"""Ghép âm thanh cho video Cave: giọng thoại vo-cave/N.mp3 đặt đúng thời điểm trong src/cave-timings.json,
nhạc nền tự tạo (căng thẳng nhẹ khi cãi vã → sáng và có nhịp khi vào phần BossKin), rồi mux vào out/bosskin-cai-va.mp4.
  python3 make_cave_audio.py  → bosskin-cai-va.mp4"""
import json, os, subprocess, wave, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); SR = 44100
T = json.load(open(f'{HERE}/src/cave-timings.json', encoding='utf-8')); DUR = T['total']; SEG = T['segments']
t = np.arange(int(SR * DUR)) / SR
solve = SEG[5]['start']; rng = np.random.default_rng(3)
k = np.clip((t - (solve - 0.8)) / 0.8, 0, 1)          # 0 = cãi vã, 1 = giải pháp
# cãi vã: drone trầm + nốt lệch (căng thẳng nhẹ)
drone = (np.sin(2 * np.pi * 55 * t) + .6 * np.sin(2 * np.pi * 58.3 * t) + .3 * np.sin(2 * np.pi * 110 * t)) * .05 * (1 - k)
drone *= 0.75 + 0.25 * np.sin(2 * np.pi * 0.7 * t)
# giải pháp: pad Am–F–C–G + nhịp 120 bpm
chords = [(220, 261.63, 329.63), (174.61, 220, 261.63), (261.63, 329.63, 392), (196, 246.94, 293.66)]
pad = np.zeros_like(t); L = 3.0
for i in range(int(DUR / L) + 2):
    s, e = solve + (i - 1) * L, solve + i * L
    m = (t >= s) & (t < e + .3)
    if not m.any(): continue
    g = np.clip((t[m] - s) / .5, 0, 1) * np.clip((e + .3 - t[m]) / .5, 0, 1)
    for f in chords[i % 4]: pad[m] += g * (np.sin(2 * np.pi * f * t[m]) + .4 * np.sin(2 * np.pi * 2 * f * t[m]))
pad *= .06 * k
beat = np.zeros_like(t)
for n in range(int(DUR * 2)):
    s = int(n * .5 * SR)
    if s / SR < solve: continue
    d = min(int(.25 * SR), len(t) - s); tt = np.arange(d) / SR
    beat[s:s + d] += .32 * np.sin(2 * np.pi * (50 + 90 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 14)
    h = int(s + .25 * SR)
    if h + int(.05 * SR) < len(t):
        hn = int(.05 * SR); beat[h:h + hn] += .05 * rng.standard_normal(hn) * np.exp(-np.arange(hn) / SR * 90)
env = np.clip(t / .4, 0, 1) * np.clip((DUR - t) / .8, 0, 1)
music = (drone + pad + beat) * env
os.makedirs(f'{HERE}/out', exist_ok=True)
wav = f'{HERE}/out/cave-music.wav'
data = (np.clip(music / max(1e-6, np.abs(music).max()) * .8, -1, 1) * 32767).astype('<i2')
with wave.open(wav, 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

src, dst = f'{HERE}/out/bosskin-cai-va.mp4', f'{HERE}/bosskin-cai-va.mp4'
cmd = ['ffmpeg', '-v', 'error', '-y', '-i', src, '-i', wav]
for i in range(len(SEG)): cmd += ['-i', f'{HERE}/vo-cave/{i + 1}.mp3']
parts = [f'[{i + 2}:a]adelay={int(s["start"] * 1000 + 150)}:all=1,volume=1.7[v{i}]' for i, s in enumerate(SEG)]
mix = ''.join(f'[v{i}]' for i in range(len(SEG)))
filt = ';'.join(parts) + f';{mix}amix=inputs={len(SEG)}:normalize=0[vo];[vo]asplit[vo1][vo2];' \
    '[1:a][vo1]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=300[duck];[duck][vo2]amix=inputs=2:normalize=0:duration=longest[a]'
cmd += ['-filter_complex', filt, '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-t', f'{DUR:.2f}', dst + '.tmp.mp4']
subprocess.run(cmd, check=True); os.replace(dst + '.tmp.mp4', dst); print('ok', dst)
