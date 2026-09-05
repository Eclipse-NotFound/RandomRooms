# -*- coding: utf-8 -*-
"""渲染 RandomRooms 日志 DUMP 的合成房：网格热图 + 物件标注。
用法: python build/render_dump.py <日志路径> [输出png]"""
import re, sys, zlib, struct

log = sys.argv[1] if len(sys.argv) > 1 else r'C:\Users\hello\AppData\Roaming\pferrtest\Local Store\RandomRooms_diag.log'
out = sys.argv[2] if len(sys.argv) > 2 else 'build/dump_render.png'
S = 16  # cell px

txt = open(log, encoding='utf-8', errors='replace').read().replace('[RR:0.0.1-M0] ', '')
# 取最后一个 DUMP 块
blocks = re.findall(r'DUMP-BEGIN (\S+)\n((?:DUMP-ROW [^\n]*\n)+)((?:DUMP-OBJ [^\n]*\n)*)((?:DUMP-BACK [^\n]*\n)*)DUMP-END', txt)
if not blocks:
    print('日志中无 DUMP 块'); sys.exit(1)
name, rows_s, objs_s, backs_s = blocks[-1]
grid = [r[9:].split('.') for r in rows_s.strip('\n').split('\n')]
H, W = len(grid), len(grid[0])
objs = [(m[0], int(m[1]), int(m[2])) for m in re.findall(r'DUMP-OBJ (\S+) (\d+) (\d+)', objs_s)]
backs = [(m[0], int(m[1]), int(m[2])) for m in re.findall(r'DUMP-BACK (\S+) (\d+) (\d+)', backs_s)]
print(f'渲染 {name}: {W}x{H}  obj {len(objs)}  back {len(backs)}')

WALL = set('ABCDEFGHIJKLMNOPQRST')
# 颜色: 墙=深灰(按字符灰阶) 开放=白 水=蓝 纹理=浅灰
def cellcol(c):
    if c == '_' or c == '': return (245, 245, 245)
    if c[0] == '_':
        if len(c) > 1 and c[1] == '*': return (140, 190, 255)
        if len(c) > 1: return (215, 215, 205)   # 纹理
        return (245, 245, 245)
    if c[0] in WALL:
        g = 40 + (ord(c[0]) - 65) * 4
        return (g, g, g + 12)
    return (255, 160, 160)  # 未知=红

img = [[cellcol(grid[y][x]) for x in range(W)] for y in range(H)]
# 物件红框（foot 近似 2x1）
for (oid, x, y) in objs:
    for dy in range(1):
        for dx in range(2):
            if 0 <= y+dy < H and 0 <= x+dx < W:
                img[y+dy][x+dx] = (255, 40, 40)
# back 黄点
for (oid, x, y) in backs:
    if 0 <= y < H and 0 <= x < W:
        img[y][x] = (255, 220, 0)

# 写 PNG (RGB)
raw = b''.join(b'\x00' + b''.join(bytes(img[y][x]) for x in range(W)) for y in range(H))
def chunk(t, d):
    c = t + d
    return struct.pack('>I', len(d)) + c + struct.pack('>I', zlib.crc32(c) & 0xffffffff)
png = b'\x89PNG\r\n\x1a\n'
png += chunk(b'IHDR', struct.pack('>IIBBBBB', W, H, 8, 2, 0, 0, 0))
png += chunk(b'IDAT', zlib.compress(raw, 6))
png += chunk(b'IEND', b'')
open(out, 'wb').write(png)
print('PNG 写出:', out)

# 悬空分析：obj 脚下格字符
from collections import Counter
foot = Counter()
for (oid, x, y) in objs:
    if 0 <= y < H and 0 <= x < W: foot[grid[y][x]] += 1
print('obj 脚下格分布:', dict(foot.most_common(12)))
# 通道洞宽（每行开放段）
print('行开放段（宽度>=2 的段数/行）样例:')
for y in range(H):
    row = grid[y]
    runs, run = [], 0
    for x in range(W):
        if row[x][0] == '_': run += 1
        else:
            if run: runs.append(run); run = 0
    if run: runs.append(run)
    wide = [r for r in runs if r >= 2]
    if y in (8, 11, 12, 16) or 0 < y < 24 and len(wide) > 0 and y % 4 == 0:
        print(f'  行{y:2d} 开放率{sum(runs)/W:.0%} 段{runs[:8]}')
