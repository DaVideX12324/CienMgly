"""Liczy komunikaty WM_INPUT (raw input) od myszy i innych HID na sekundę, z podziałem na urządzenia.

Okno ukryte z RIDEV_INPUTSINK — odbiera wejście także bez fokusu. Użycie: python rawinput_count.py <sekundy>
"""
import collections
import ctypes
import ctypes.wintypes as wt
import sys
import time

u = ctypes.WinDLL("user32", use_last_error=True)
k = ctypes.WinDLL("kernel32", use_last_error=True)

WM_INPUT = 0x00FF
RIDEV_INPUTSINK = 0x00000100
RID_HEADER = 0x10000005
RIDI_DEVICENAME = 0x20000007
LRESULT = ctypes.c_ssize_t
WNDPROC = ctypes.WINFUNCTYPE(LRESULT, wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM)


class RAWINPUTDEVICE(ctypes.Structure):
    _fields_ = [("usUsagePage", wt.USHORT), ("usUsage", wt.USHORT), ("dwFlags", wt.DWORD), ("hwndTarget", wt.HWND)]


class RAWINPUTHEADER(ctypes.Structure):
    _fields_ = [("dwType", wt.DWORD), ("dwSize", wt.DWORD), ("hDevice", wt.HANDLE), ("wParam", wt.WPARAM)]


class WNDCLASSW(ctypes.Structure):
    _fields_ = [("style", wt.UINT), ("lpfnWndProc", WNDPROC), ("cbClsExtra", ctypes.c_int), ("cbWndExtra", ctypes.c_int),
                ("hInstance", wt.HINSTANCE), ("hIcon", wt.HICON), ("hCursor", wt.HANDLE), ("hbrBackground", wt.HBRUSH),
                ("lpszMenuName", wt.LPCWSTR), ("lpszClassName", wt.LPCWSTR)]


u.DefWindowProcW.argtypes = [wt.HWND, wt.UINT, wt.WPARAM, wt.LPARAM]
u.DefWindowProcW.restype = LRESULT
u.GetRawInputData.argtypes = [wt.HANDLE, wt.UINT, ctypes.c_void_p, ctypes.POINTER(wt.UINT), wt.UINT]
u.GetRawInputDeviceInfoW.argtypes = [wt.HANDLE, wt.UINT, ctypes.c_void_p, ctypes.POINTER(wt.UINT)]
u.CreateWindowExW.restype = wt.HWND
u.CreateWindowExW.argtypes = [wt.DWORD, wt.LPCWSTR, wt.LPCWSTR, wt.DWORD, ctypes.c_int, ctypes.c_int, ctypes.c_int,
                              ctypes.c_int, wt.HWND, wt.HMENU, wt.HINSTANCE, wt.LPVOID]

counts = collections.Counter()
per_sec = collections.defaultdict(collections.Counter)
t0 = time.time()
TYPES = {0: "mysz", 1: "klawiatura", 2: "HID"}


def dev_name(h):
    n = wt.UINT(0)
    u.GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, None, ctypes.byref(n))
    buf = ctypes.create_unicode_buffer(n.value + 1)
    u.GetRawInputDeviceInfoW(h, RIDI_DEVICENAME, buf, ctypes.byref(n))
    return buf.value


@WNDPROC
def proc(hwnd, msg, wp, lp):
    if msg == WM_INPUT:
        hdr = RAWINPUTHEADER()
        sz = wt.UINT(ctypes.sizeof(hdr))
        u.GetRawInputData(lp, RID_HEADER, ctypes.byref(hdr), ctypes.byref(sz), ctypes.sizeof(RAWINPUTHEADER))
        key = (TYPES.get(hdr.dwType, str(hdr.dwType)), hdr.hDevice or 0)
        counts[key] += 1
        per_sec[int(time.time() - t0)][key] += 1
    return u.DefWindowProcW(hwnd, msg, wp, lp)


def main():
    secs = float(sys.argv[1]) if len(sys.argv) > 1 else 15
    hinst = k.GetModuleHandleW(None)
    wc = WNDCLASSW()
    wc.lpfnWndProc = proc
    wc.hInstance = hinst
    wc.lpszClassName = "RawCounter"
    u.RegisterClassW(ctypes.byref(wc))
    hwnd = u.CreateWindowExW(0, "RawCounter", "RawCounter", 0, 0, 0, 0, 0, None, None, hinst, None)
    devs = (RAWINPUTDEVICE * 3)(
        RAWINPUTDEVICE(0x01, 0x02, RIDEV_INPUTSINK, hwnd),  # mysz
        RAWINPUTDEVICE(0x01, 0x06, RIDEV_INPUTSINK, hwnd),  # klawiatura
        RAWINPUTDEVICE(0x01, 0x04, RIDEV_INPUTSINK, hwnd),  # joystick
    )
    if not u.RegisterRawInputDevices(devs, 3, ctypes.sizeof(RAWINPUTDEVICE)):
        print("RegisterRawInputDevices nie powiodło się", ctypes.get_last_error())
        return
    msg = wt.MSG()
    end = time.time() + secs
    while time.time() < end:
        while u.PeekMessageW(ctypes.byref(msg), None, 0, 0, 1):
            u.TranslateMessage(ctypes.byref(msg))
            u.DispatchMessageW(ctypes.byref(msg))
        time.sleep(0.001)
    total = sum(counts.values())
    print(f"razem {total} komunikatów WM_INPUT w {secs:.0f} s")
    for (typ, h), c in counts.most_common():
        print(f"  {typ:10s} {c:7d}  ({c / secs:6.0f}/s, maks. w 1 s: {max(per_sec[s][(typ, h)] for s in per_sec):5d})  {dev_name(h) if h else '(brak uchwytu: wirtualne / SendInput)'}")
    print("na sekundę (wszystkie):", [sum(per_sec[s].values()) for s in sorted(per_sec)])


if __name__ == "__main__":
    main()
