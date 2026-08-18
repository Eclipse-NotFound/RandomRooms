#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
RRSeed 对照验证：python 复刻 xorshift32 与 fork，与 AS3 实现序列比对。

用法: python build/seed-check.py
输出前 20 个 next() 值 + 3 个 fork 派生的序列，供 AS3 端 preview 对照。
（AS3 实机侧在 RRDiag 日志打印 preview(20)，两边数值一致即验证通过。）
"""
import sys

MASK32 = 0xFFFFFFFF

def xorshift32(s):
    x = s if s != 0 else 1
    while True:
        x ^= (x << 13) & MASK32
        x ^= x >> 17
        x ^= (x << 5) & MASK32
        x &= MASK32
        yield x / 4294967296.0

def fork(seed, label):
    h = (seed ^ 0x9E3779B9) & MASK32
    for ch in label:
        h ^= ord(ch)
        h ^= (h << 13) & MASK32
        h ^= h >> 17
        h ^= (h << 5) & MASK32
        h &= MASK32
    return h

if __name__ == "__main__":
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 123456789
    print(f"seed={seed}")
    g = xorshift32(seed)
    vals = [next(g) for _ in range(20)]
    print("next x20:", ",".join(f"{v:.9f}" for v in vals))
    for label in ("cook", "layout", "rr_test"):
        f = fork(seed, label)
        g2 = xorshift32(f)
        v2 = [next(g2) for _ in range(5)]
        print(f"fork({label}) seed={f} next x5:", ",".join(f"{x:.9f}" for x in v2))
