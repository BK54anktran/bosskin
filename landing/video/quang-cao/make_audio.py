#!/usr/bin/env python3
"""Âm thanh cho video quảng cáo: nhạc nền tự tạo (numpy, không cần file ngoài) + giọng đọc tuỳ chọn, rồi ghép vào mp4 bằng ffmpeg.
  python3 make_audio.py            → bosskin-quang-cao.mp4 có tiếng (nhạc nền)
Giọng đọc: đặt vo/1.mp3 … vo/6.mp3 (mỗi cảnh một file, tạo bằng ../tts_edge.py — xem lời đọc ở vo/loi-doc.txt);
có file nào thì tự chèn đúng đầu cảnh đó và hạ nhạc nền khi đọc."""
import os, subprocess, wave, numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); SR = 44100; DUR = 27
SCENE_START = [0, 5.4, 9.3, 12.8, 16.8, 20.2]
t = np.arange(int(SR * DUR)) / SR

def env(x, a=.4, r=.6):  # tai nghe êm: vào / ra chậm
    return np.clip(x / a, 0, 1) * np.clip((DUR - x) / r, 0, 1)

# Pad hợp âm Am – F – C – G, mỗi hợp âm 3,125 s, vào / ra mượt
chords = [(220, 261.63, 329.63), (174.61, 220, 261.63), (261.63, 329.63, 392), (196, 246.94, 293.66)]
pad = np.zeros_like(t)
for i in range(9):
    s, e = i * 3.0, (i + 1) * 3.0
    m = (t >= s) & (t < e + .3)
    tt = t[m] - s
    g = np.clip(tt / .5, 0, 1) * np.clip((e + .3 - t[m]) / .5, 0, 1)
    for f in chords[i % 4]:
        pad[m] += g * (np.sin(2 * np.pi * f * t[m]) + .4 * np.sin(2 * np.pi * 2 * f * t[m]))
pad *= .06

# Nhịp: kick mỗi phách (120 bpm), hi-hat nửa phách
rng = np.random.default_rng(7)
beat = np.zeros_like(t)
for k in range(int(DUR * 2)):
    s = int(k * .5 * SR)
    n = min(int(.25 * SR), len(t) - s)
    tt = np.arange(n) / SR
    beat[s:s + n] += .32 * np.sin(2 * np.pi * (50 + 90 * np.exp(-tt * 30)) * tt) * np.exp(-tt * 14)
    h = int(s + .25 * SR)
    if h + int(.05 * SR) < len(t):
        hn = int(.05 * SR); beat[h:h + hn] += .05 * rng.standard_normal(hn) * np.exp(-np.arange(hn) / SR * 90)
beat *= np.clip((t - 3.5) / 1.5, 0, 1)  # nhịp vào sau cảnh mở đầu

music = (pad + beat) * env(t)
voice_files = [(i, f'{HERE}/vo/{i + 1}.mp3') for i in range(6) if os.path.exists(f'{HERE}/vo/{i + 1}.mp3')]
tmp = f'{HERE}/out/music.wav'; os.makedirs(f'{HERE}/out', exist_ok=True)
data = (np.clip(music / max(1e-6, np.abs(music).max()) * .8, -1, 1) * 32767).astype('<i2')
with wave.open(tmp, 'wb') as w: w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())

src = f'{HERE}/out/bosskin-quang-cao.mp4'; dst = f'{HERE}/bosskin-quang-cao.mp4'
cmd = ['ffmpeg', '-v', 'error', '-y', '-i', src, '-i', tmp]
filt = ''
if voice_files:
    for _, p in voice_files: cmd += ['-i', p]
    parts = [f'[{k + 2}:a]adelay={int(SCENE_START[i] * 1000 + 250)}:all=1,volume=1.6[v{k}]' for k, (i, _) in enumerate(voice_files)]
    mix = ''.join(f'[v{k}]' for k in range(len(voice_files)))
    filt = ';'.join(parts) + f';{mix}amix=inputs={len(voice_files)}:normalize=0[vo];[vo]asplit[vo1][vo2];' \
        f'[1:a][vo1]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=300[duck];[duck][vo2]amix=inputs=2:normalize=0[a]'
else:
    filt = '[1:a]volume=0.9[a]'
cmd += ['-filter_complex', filt, '-map', '0:v', '-map', '[a]', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-shortest', dst + '.tmp.mp4']
subprocess.run(cmd, check=True); os.replace(dst + '.tmp.mp4', dst)
print('ok', dst, 'giọng đọc:', len(voice_files), 'file')
