"""Okno Win32 bez Godota: pętla PeekMessage jak w silniku gry (bez czekania), mierzy przerwy > 50 ms przy ruchu myszy.

Użycie: python win32_loop_test.py <sekundy> [busy|sleep]
busy  — pętla kręci się bez przerwy (jak Godot przy VSync wątku głównego 100% CPU),
sleep — po każdym obiegu Sleep(5).
Okno trzeba kliknąć (fokus) i ruszać nad nim myszą.
"""
import collections
import ctypes
import ctypes.wintypes as wt
import sys
import time

u = ctypes.WinDLL("user32", use_last_error=True)
k = ctypes.WinDLL("kernel32", use_last_error=True)
LRESULT = ctypes.c_ssize_t
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM)


class WNDCLASSW(ctypes.Structure):
    _fields_ = [("style", wt.UINT), ("lpfnWndProc", WNDPROC), ("cbClsExtra", ctypes.c_int), ("cbWndExtra", ctypes.c_int),
                ("hInstance", wt.HINSTANCE), ("hIcon", wt.HICON), ("hCursor", wt.HANDLE), ("hbrBackground", wt.HBRUSH),
                ("lpszMenuName", wt.LPCWSTR), ("lpszClassName", wt.LPCWSTR)]


u.DefWindowProcW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
u.DefWindowProcW.restype = LRESULT
u.CreateWindowExW.restype = wt.HWND
u.CreateWindowExW.argtypes = [wt.DWORD, wt.LPCWSTR, wt.LPCWSTR, wt.DWORD, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                              ctypes.c_int, wt.HWND, wt.HMENU, wt.HINSTANCE, wt.LPVOID]
u.LoadCursorW.restype = wt.HANDLE
u.LoadCursorW.argtypes = [wt.HINSTANCE, ctypes.c_void_p]
u.GetForegroundWindow.restype = wt.HWND

msgs = collections.Counter()
NAMES = {0x0200: "WM_MOUSEMOVE", 0x0084: "WM_NCHITTEST", 0x0020: "WM_SETCURSOR", 0x00FF: "WM_INPUT", 0x02A1: "WM_MOUSEHOVER",
         0x000F: "WM_PAINT", 0x0113: "WM_TIMER", 0x0021: "WM_MOUSEACTIVATE", 0x00A0: "WM_NCMOUSEMOVE"}


@WNDPROC
def proc(hwnd, msg, wp, lp):
    msgs[NAMES.get(msg, hex(msg))] += 1
    if msg == 0x0002:
        u.PostQuitMessage(0)
    return u.DefWindowProcW(hwnd, msg, wp, lp)


def main():
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 30
    mode = sys.argv[2] if len(sys.argv) > 2 else "busy"
    hinst = k.GetModuleHandleW(None)
    wc = WNDCLASSW()
    wc.lpfnWndProc = proc
    wc.hInstance = hinst
    wc.hCursor = u.LoadCursorW(None, ctypes.c_void_p(32512))
    wc.hbrBackground = wt.HBRUSH(6)
    wc.lpszClassName = "LoopTest"
    u.RegisterClassW(ctypes.byref(wc))
    hwnd = u.CreateWindowExW(0, "LoopTest", "TEST PETLI - kliknij i ruszaj mysza (%s)" % mode, 0x10CF0000,
                             300, 200, 1600, 900, None, None, hinst, None)
    u.SetForegroundWindow(hwnd)
    msg = wt.MSG()
    stalls = []
    focused_iters = 0
    t_end = time.perf_counter() + secs
    last = time.perf_counter()
    while time.perf_counter() < t_end:
        while u.PeekMessageW(ctypes.byref(msg), None, 0, 0, 1):
            u.TranslateMessage(ctypes.byref(msg))
            u.DispatchMessageW(ctypes.byref(msg))
        now = time.perf_counter()
        if (now - last) * 1000 > 50:
            stalls.append(round((now - last) * 1000))
        last = now
        if u.GetForegroundWindow() == hwnd:
            focused_iters += 1
        if mode == "sleep":
            time.sleep(0.005)
    u.DestroyWindow(hwnd)
    print(f"tryb {mode}: przerw > 50 ms: {len(stalls)}, suma {sum(stalls)} ms, najgorsza {max(stalls) if stalls else 0} ms")
    print("obiegów z fokusem:", focused_iters)
    print("komunikaty:", dict(msgs.most_common(8)))


if __name__ == "__main__":
    main()
