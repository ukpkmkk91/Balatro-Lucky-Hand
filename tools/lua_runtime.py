"""Minimal Lua 5.1 test bridge. No DLLs or game code are distributed here."""
import ctypes
from pathlib import Path


class LuaRuntime:
    def __init__(self, dll):
        self.path = Path(dll).resolve(strict=True)
        if self.path.name.lower() != 'lua51.dll':
            raise ValueError('Use the pinned game Lua 5.1 DLL')
        self.lib = ctypes.CDLL(str(self.path))
        self.lib.luaL_newstate.restype = ctypes.c_void_p
        self.lib.luaL_openlibs.argtypes = [ctypes.c_void_p]
        self.lib.luaL_loadbuffer.argtypes = [ctypes.c_void_p, ctypes.c_char_p, ctypes.c_size_t, ctypes.c_char_p]
        self.lib.lua_pcall.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_int, ctypes.c_int]
        self.lib.lua_tolstring.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p]
        self.lib.lua_tolstring.restype = ctypes.c_char_p
        self.lib.lua_close.argtypes = [ctypes.c_void_p]

    def check(self, source, name, execute=False):
        state = self.lib.luaL_newstate()
        if not state:
            raise RuntimeError('Could not allocate Lua state')
        try:
            self.lib.luaL_openlibs(state)
            code = self.lib.luaL_loadbuffer(state, source, len(source), name.encode('utf-8'))
            if not code and execute:
                code = self.lib.lua_pcall(state, 0, 0, 0)
            if code:
                message = self.lib.lua_tolstring(state, -1, None)
                raise RuntimeError(message.decode('utf-8', errors='replace') if message else name)
        finally:
            self.lib.lua_close(state)

    def flush(self):
        # Flush only the same CRT used by this pinned Lua runtime, if present.
        crt = self.path.with_name('msvcr120.dll')
        if crt.is_file():
            ctypes.CDLL(str(crt)).fflush(None)
