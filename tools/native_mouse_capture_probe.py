"""Read-only Win32 evidence for a caller-owned test window. No OS input injection."""
import ctypes
from ctypes import wintypes as w
import json
import sys


class GUIThreadInfo(ctypes.Structure):
    _fields_ = [
        ('cbSize', w.DWORD), ('flags', w.DWORD),
        ('hwndActive', w.HWND), ('hwndFocus', w.HWND),
        ('hwndCapture', w.HWND), ('hwndMenuOwner', w.HWND),
        ('hwndMoveSize', w.HWND), ('hwndCaret', w.HWND),
        ('rcCaret', w.RECT),
    ]


def main():
    hwnd, expected_pid = map(int, sys.argv[1:3])
    user = ctypes.WinDLL('user32', use_last_error=True)
    # Match Godot's physical pixels under display scaling. Only this probe
    # thread's DPI context changes; no window or cursor is modified.
    user.SetThreadDpiAwarenessContext.argtypes = [ctypes.c_void_p]
    user.SetThreadDpiAwarenessContext.restype = ctypes.c_void_p
    user.SetThreadDpiAwarenessContext(ctypes.c_void_p(-4))
    user.GetWindowThreadProcessId.argtypes = [w.HWND, ctypes.POINTER(w.DWORD)]
    user.GetWindowThreadProcessId.restype = w.DWORD
    user.GetForegroundWindow.restype = w.HWND
    user.GetClientRect.argtypes = [w.HWND, ctypes.POINTER(w.RECT)]
    user.ClientToScreen.argtypes = [w.HWND, ctypes.POINTER(w.POINT)]
    user.GetClipCursor.argtypes = [ctypes.POINTER(w.RECT)]
    user.GetCursorPos.argtypes = [ctypes.POINTER(w.POINT)]
    user.GetGUIThreadInfo.argtypes = [w.DWORD, ctypes.POINTER(GUIThreadInfo)]
    user.GetGUIThreadInfo.restype = w.BOOL
    pid = w.DWORD()
    thread = user.GetWindowThreadProcessId(hwnd, ctypes.byref(pid))
    if pid.value != expected_pid or not thread:
        raise SystemExit('Refusing to probe a window outside the temporary test process')
    client, clip, cursor = w.RECT(), w.RECT(), w.POINT()
    assert user.GetClientRect(hwnd, ctypes.byref(client))
    origin = w.POINT(client.left, client.top)
    corner = w.POINT(client.right, client.bottom)
    assert user.ClientToScreen(hwnd, ctypes.byref(origin))
    assert user.ClientToScreen(hwnd, ctypes.byref(corner))
    assert user.GetClipCursor(ctypes.byref(clip))
    assert user.GetCursorPos(ctypes.byref(cursor))
    gui = GUIThreadInfo()
    gui.cbSize = ctypes.sizeof(gui)
    assert user.GetGUIThreadInfo(thread, ctypes.byref(gui))
    client_rect = [origin.x, origin.y, corner.x, corner.y]
    clip_rect = [clip.left, clip.top, clip.right, clip.bottom]
    desktop_x = user.GetSystemMetrics(76)  # SM_XVIRTUALSCREEN
    desktop_y = user.GetSystemMetrics(77)  # SM_YVIRTUALSCREEN
    desktop_rect = [desktop_x, desktop_y,
                    desktop_x + user.GetSystemMetrics(78),
                    desktop_y + user.GetSystemMetrics(79)]
    print(json.dumps({
        'owned_window': True, 'pid': pid.value, 'window': hwnd,
        'foreground': user.GetForegroundWindow() == hwnd,
        'client_rect': client_rect, 'clip_rect': clip_rect,
        'clip_matches_client': all(abs(a-b) <= 2 for a, b in zip(client_rect, clip_rect)),
        'desktop_rect': desktop_rect,
        'clip_matches_desktop': clip_rect == desktop_rect,
        'cursor': [cursor.x, cursor.y],
        'cursor_in_client': origin.x <= cursor.x < corner.x and origin.y <= cursor.y < corner.y,
        'capture_window': int(gui.hwndCapture or 0),
    }))


if __name__ == '__main__':
    main()
