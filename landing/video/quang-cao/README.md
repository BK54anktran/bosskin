# Video quảng cáo BossKin (9:16, 25 giây)
Remotion (React) → `bosskin-quang-cao.mp4` (1080×1920, 30 fps, không có tiếng). Cảnh: mở đầu → chấm công → xếp ca → tổng quan → lương → giá từ 5.000đ/NV/tháng + dùng thử 1 tháng + hỗ trợ 24/24 + QR.
Âm thanh: `python3 make_audio.py` (nhạc nền tự tạo; giọng đọc tuỳ chọn — xem `vo/loi-doc.txt`).
Nội dung giá khớp mục Bảng giá trên landing và poster (`docs/thiet-ke/bang-gia-landing.md`) — đổi giá thì sửa `src/Quangcao.tsx` (cảnh cuối) rồi dựng lại.

```
./prep.sh                      # chép ảnh / font / QR vào public/ (không commit)
# cần gói remotion (xem tools/cloud/setup-tools-40.sh, đặt node_modules → /root/tools4/node_modules)
npm run render                 # → out/bosskin-quang-cao.mp4  (dùng chromium headless-shell có sẵn)
npm run studio                 # xem / chỉnh trực tiếp
```

## Bản "Cãi vã chuyện thiếu lương → BossKin" (`bosskin-cai-va.mp4`, ~31 giây)
Hoạt hình tự vẽ (nhân viên và sếp cãi nhau vì thiếu công, không dùng clip có bản quyền) rồi vào phần giải pháp BossKin + giá + dùng thử + 24/24.
```
python3 make_cave_voice.py     # lời thoại → vo-cave/*.mp3 (gTTS, mỗi vai một tông) + src/cave-timings.json
npx remotion render src/index.ts Cave out/bosskin-cai-va.mp4 --browser-executable=<headless_shell>
python3 make_cave_audio.py     # ghép giọng + nhạc → bosskin-cai-va.mp4
```
Đổi lời thoại → sửa `LINES` trong `make_cave_voice.py` rồi chạy lại 3 lệnh (độ dài từng cảnh tự co giãn theo giọng).

Giọng thần kinh offline (Piper, tự nhiên hơn gTTS): `pip install piper-tts`, tải `vi_VN-vais1000-medium.onnx` (+ `.json`) từ huggingface.co/rhasspy/piper-voices (vi/vi_VN/vais1000/medium), rồi
`ENGINE=piper PIPER_MODEL=<file.onnx> python3 make_cave_voice.py` → `vo-cave-piper/`; dựng hình lại rồi `VO_DIR=vo-cave-piper OUT_NAME=bosskin-cai-va-piper.mp4 python3 make_cave_audio.py`.
(`make_cave_voice.py` ghi đè `src/cave-timings.json` — chạy lại engine nào thì dựng hình bằng engine đó.)
