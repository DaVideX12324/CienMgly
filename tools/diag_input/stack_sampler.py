"""Próbnik stosów wątku głównego innego procesu (Windows x64, bez uprawnień administratora).

Użycie: python stack_sampler.py <pid> <sekundy> <wyjście.json>
Co ~5 ms: SuspendThread -> GetThreadContext -> StackWalk64 (dbghelp, tylko tabele unwind z PE, bez pobierania
symboli) -> ResumeThread. Zapisuje próbki (czas unix, lista adresów) i listę modułów (ścieżka, baza, rozmiar).
Symbolizacja osobno (symbolize.py), żeby nie trzymać zatrzymanego wątku podczas wczytywania PDB.
"""
import ctypes
import ctypes.wintypes as wt
import json
import sys
import time

k32 = ctypes.WinDLL("kernel32", use_last_error=True)
psapi = ctypes.WinDLL("psapi", use_last_error=True)
dbghelp = ctypes.WinDLL("dbghelp", use_last_error=True)

PROCESS_ALL = 0x0400 | 0x0010  # QUERY_INFORMATION | VM_READ
THREAD_ACCESS = 0x0002 | 0x0008 | 0x0040  # SUSPEND_RESUME | GET_CONTEXT | QUERY_INFORMATION
TH32CS_SNAPTHREAD = 0x4
CONTEXT_FULL = 0x10000B
AddrModeFlat = 3


class THREADENTRY32(ctypes.Structure):
    _fields_ = [("dwSize", wt.DWORD), ("cntUsage", wt.DWORD), ("th32ThreadID", wt.DWORD),
                ("th32OwnerProcessID", wt.DWORD), ("tpBasePri", wt.LONG), ("tpDeltaPri", wt.LONG),
                ("dwFlags", wt.DWORD)]


class ADDRESS64(ctypes.Structure):
    _fields_ = [("Offset", ctypes.c_uint64), ("Segment", ctypes.c_uint16), ("Mode", ctypes.c_uint32)]


class STACKFRAME64(ctypes.Structure):
    _fields_ = [("AddrPC", ADDRESS64), ("AddrReturn", ADDRESS64), ("AddrFrame", ADDRESS64),
                ("AddrStack", ADDRESS64), ("AddrBStore", ADDRESS64), ("FuncTableEntry", ctypes.c_void_p),
                ("Params", ctypes.c_uint64 * 4), ("Far", wt.BOOL), ("Virtual", wt.BOOL),
                ("Reserved", ctypes.c_uint64 * 3), ("KdHelp", ctypes.c_ubyte * 512)]


class MODULEINFO(ctypes.Structure):
    _fields_ = [("lpBaseOfDll", ctypes.c_void_p), ("SizeOfImage", wt.DWORD), ("EntryPoint", ctypes.c_void_p)]


k32.OpenProcess.restype = wt.HANDLE
k32.OpenThread.restype = wt.HANDLE
k32.CreateToolhelp32Snapshot.restype = wt.HANDLE
k32.SuspendThread.argtypes = [wt.HANDLE]
k32.ResumeThread.argtypes = [wt.HANDLE]
k32.GetThreadContext.argtypes = [wt.HANDLE, ctypes.c_void_p]
dbghelp.SymInitializeW.argtypes = [wt.HANDLE, wt.LPCWSTR, wt.BOOL]
dbghelp.StackWalk64.argtypes = [wt.DWORD, wt.HANDLE, wt.HANDLE, ctypes.POINTER(STACKFRAME64), ctypes.c_void_p,
                                ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
dbghelp.SymSetOptions.argtypes = [wt.DWORD]
psapi.EnumProcessModulesEx.argtypes = [wt.HANDLE, ctypes.POINTER(wt.HMODULE), wt.DWORD, ctypes.POINTER(wt.DWORD), wt.DWORD]
psapi.GetModuleFileNameExW.argtypes = [wt.HANDLE, wt.HMODULE, wt.LPWSTR, wt.DWORD]
psapi.GetModuleInformation.argtypes = [wt.HANDLE, wt.HMODULE, ctypes.POINTER(MODULEINFO), wt.DWORD]


def first_thread(pid):
    snap = k32.CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD, 0)
    te = THREADENTRY32()
    te.dwSize = ctypes.sizeof(te)
    ok = k32.Thread32First(snap, ctypes.byref(te))
    while ok:
        if te.th32OwnerProcessID == pid:
            k32.CloseHandle(snap)
            return te.th32ThreadID
        ok = k32.Thread32Next(snap, ctypes.byref(te))
    k32.CloseHandle(snap)
    return None


def modules(hproc):
    arr = (wt.HMODULE * 1024)()
    needed = wt.DWORD()
    psapi.EnumProcessModulesEx(hproc, arr, ctypes.sizeof(arr), ctypes.byref(needed), 3)
    out = []
    for i in range(needed.value // ctypes.sizeof(wt.HMODULE)):
        name = ctypes.create_unicode_buffer(1024)
        psapi.GetModuleFileNameExW(hproc, arr[i], name, 1024)
        mi = MODULEINFO()
        psapi.GetModuleInformation(hproc, arr[i], ctypes.byref(mi), ctypes.sizeof(mi))
        out.append({"path": name.value, "base": mi.lpBaseOfDll or 0, "size": mi.SizeOfImage})
    return out


def main():
    pid, secs, out_path = int(sys.argv[1]), float(sys.argv[2]), sys.argv[3]
    tid = int(sys.argv[4]) if len(sys.argv) > 4 else first_thread(pid)
    hproc = k32.OpenProcess(PROCESS_ALL, False, pid)
    hthr = k32.OpenThread(THREAD_ACCESS, False, tid)
    if not hproc or not hthr:
        print("nie można otworzyć procesu/wątku", ctypes.get_last_error())
        return
    dbghelp.SymSetOptions(0x00000004 | 0x00000002)  # DEFERRED_LOADS | UNDNAME
    dbghelp.SymInitializeW(hproc, "", True)
    fta = ctypes.cast(dbghelp.SymFunctionTableAccess64, ctypes.c_void_p)
    gmb = ctypes.cast(dbghelp.SymGetModuleBase64, ctypes.c_void_p)
    raw = ctypes.create_string_buffer(1232 + 16)
    ctx_addr = (ctypes.addressof(raw) + 15) & ~15
    samples = []
    end = time.time() + secs
    while time.time() < end:
        ctypes.memset(ctx_addr, 0, 1232)
        ctypes.c_uint32.from_address(ctx_addr + 0x30).value = CONTEXT_FULL
        if k32.SuspendThread(hthr) == 0xFFFFFFFF:
            break
        t = time.time()
        frames = []
        try:
            if k32.GetThreadContext(hthr, ctx_addr):
                rip = ctypes.c_uint64.from_address(ctx_addr + 0xF8).value
                rsp = ctypes.c_uint64.from_address(ctx_addr + 0x98).value
                rbp = ctypes.c_uint64.from_address(ctx_addr + 0xA0).value
                sf = STACKFRAME64()
                sf.AddrPC.Offset, sf.AddrPC.Mode = rip, AddrModeFlat
                sf.AddrFrame.Offset, sf.AddrFrame.Mode = rbp, AddrModeFlat
                sf.AddrStack.Offset, sf.AddrStack.Mode = rsp, AddrModeFlat
                for _ in range(48):
                    if not dbghelp.StackWalk64(0x8664, hproc, hthr, ctypes.byref(sf), ctx_addr, None, fta, gmb, None):
                        break
                    if sf.AddrPC.Offset == 0:
                        break
                    frames.append(sf.AddrPC.Offset)
        finally:
            k32.ResumeThread(hthr)
        samples.append([t, frames])
        time.sleep(0.005)
    mods = modules(hproc)
    json.dump({"pid": pid, "tid": tid, "modules": mods, "samples": samples}, open(out_path, "w"))
    print(f"próbek: {len(samples)}, wątek {tid}, modułów {len(mods)}")


if __name__ == "__main__":
    main()
