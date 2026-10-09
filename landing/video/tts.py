#!/usr/bin/env python3
"""Lồng tiếng tiếng Việt cho video (edge-tts, cần mạng tới dịch vụ giọng đọc Microsoft).
  pip install edge-tts ; python3 tts.py script.json <thư mục ra>   → <id>.mp3 + <id>.srt cho từng cảnh"""
import asyncio, json, os, sys, edge_tts
cfg = json.load(open(sys.argv[1], encoding='utf-8')); out = sys.argv[2]
os.makedirs(out, exist_ok=True)
async def one(s):
    c = edge_tts.Communicate(s['vo'], cfg['voice'], rate=cfg['rate'])
    sub = edge_tts.SubMaker()
    with open(f"{out}/{s['id']}.mp3", 'wb') as f:
        async for ch in c.stream():
            if ch['type'] == 'audio': f.write(ch['data'])
            elif ch['type'] in ('WordBoundary', 'SentenceBoundary'):
                sub.feed(ch)
    open(f"{out}/{s['id']}.srt", 'w', encoding='utf-8').write(sub.get_srt())
async def main():
    for s in cfg['scenes']: await one(s); print('ok', s['id'])
asyncio.run(main())
