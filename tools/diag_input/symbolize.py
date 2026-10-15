"""Symbolizacja próbek ze stack_sampler.py offline (moduły z dysku, nazwy z eksportów / PDB z serwera MS).

Użycie: python symbolize.py <stacks.json> [hitch_log] [--ms]
--ms: pobiera symbole Microsoftu (srv*cache*https://msdl.microsoft.com/download/symbols) dla bibliotek systemowych.
hitch_log: log pustego projektu (linie "<unix> zacięcie N ms") — dzieli próbki na „w zacięciu” i „normalne”.
"""
import collections
import ctypes
import ctypes.wintypes as wt
import json
import os
import re
import sys

dbghelp = ctypes.WinDLL(os.environ.get("DBGHELP", "dbghelp"))


class SYMBOL_INFOW(ctypes.Structure):
    _fields_ = [("SizeOfStruct", wt.ULONG), ("TypeIndex", wt.ULONG), ("Reserved", ctypes.c_uint64 * 2),
                ("Index", wt.ULONG), ("Size", wt.ULONG), ("ModBase", ctypes.c_uint64), ("Flags", wt.ULONG),
                ("Value", ctypes.c_uint64), ("Address", ctypes.c_uint64), ("Register", wt.ULONG),
                ("Scope", wt.ULONG), ("Tag", wt.ULONG), ("NameLen", wt.ULONG), ("MaxNameLen", wt.ULONG),
                ("Name", ctypes.c_wchar * 512)]


dbghelp.SymInitializeW.argtypes = [wt.HANDLE, wt.LPCWSTR, wt.BOOL]
dbghelp.SymLoadModuleExW.argtypes = [wt.HANDLE, wt.HANDLE, wt.LPCWSTR, wt.LPCWSTR, ctypes.c_uint64, wt.DWORD,
                                     ctypes.c_void_p, wt.DWORD]
dbghelp.SymLoadModuleExW.restype = ctypes.c_uint64
dbghelp.SymFromAddrW.argtypes = [wt.HANDLE, ctypes.c_uint64, ctypes.POINTER(ctypes.c_uint64), ctypes.POINTER(SYMBOL_INFOW)]


def main():
    d = json.load(open(sys.argv[1]))
    hitch_log = next((a for a in sys.argv[2:] if not a.startswith("--")), None)
    use_ms = "--ms" in sys.argv
    h = wt.HANDLE(0x1234)
    sympath = "srv*%s*https://msdl.microsoft.com/download/symbols" % os.path.join(os.path.dirname(sys.argv[1]), "symcache") if use_ms else ""
    dbghelp.SymSetOptions(0x2 | 0x4)
    dbghelp.SymInitializeW(h, sympath, False)
    mods = sorted(d["modules"], key=lambda m: m["base"])
    for m in mods:
        dbghelp.SymLoadModuleExW(h, None, m["path"], None, m["base"], m["size"], None, 0)
    cache = {}

    def name(a):
        if a in cache:
            return cache[a]
        mod = next((m["path"].split("\\")[-1] for m in mods if m["base"] <= a < m["base"] + m["size"]), "?")
        si = SYMBOL_INFOW()
        si.SizeOfStruct = 88  # sizeof(SYMBOL_INFOW) w C (Name[1] + wyrównanie)
        si.MaxNameLen = 511
        disp = ctypes.c_uint64()
        if dbghelp.SymFromAddrW(h, a, ctypes.byref(disp), ctypes.byref(si)):
            s = "%s!%s+0x%x" % (mod, si.Name, disp.value)
        else:
            base = next((m["base"] for m in mods if m["base"] <= a < m["base"] + m["size"]), 0)
            s = "%s+0x%x" % (mod, a - base)
        cache[a] = s
        return s

    hitches = []
    if hitch_log:
        for line in open(hitch_log, encoding="utf-8", errors="replace"):
            mm = re.match(r"([\d.]+) .*?(\d+) ms", line)
            if mm and "zaci" in line:
                t, ms = float(mm.group(1)), float(mm.group(2))
                hitches.append((t - ms / 1000.0, t))
    groups = {"ZACIĘCIA": [], "NORMALNE": []}
    for t, frames in d["samples"]:
        inside = any(a <= t <= b for a, b in hitches)
        groups["ZACIĘCIA" if inside else "NORMALNE"].append(frames)
    for g, samples in groups.items():
        print("=" * 30, g, "próbek:", len(samples))
        if not samples:
            continue
        top = collections.Counter(name(f[0]) for f in samples if f)
        print("-- góra stosu:")
        for n, c in top.most_common(12):
            print("  %5.1f%%  %s" % (100.0 * c / len(samples), n))
        incl = collections.Counter()
        for f in samples:
            for n in set(name(a) for a in f[:20]):
                incl[n] += 1
        print("-- obecne w stosie (inclusive, top 25):")
        for n, c in incl.most_common(25):
            print("  %5.1f%%  %s" % (100.0 * c / len(samples), n))
        stacks = collections.Counter(" <- ".join(name(a) for a in f[:10]) for f in samples if f)
        print("-- najczęstsze stosy:")
        for s, c in stacks.most_common(5):
            print("  %4d  %s" % (c, s))


if __name__ == "__main__":
    main()
