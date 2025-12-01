# HashLink Native Build Instructions

This directory contains the HashLink native bindings for TinySoundFont.

## Building for HashLink

### Windows (Visual Studio)

1. Compile the C++ bridge first:
```bash
cl /c /EHsc /I..\cpp ..\cpp\tsf_bridge.cpp /Fo:tsf_bridge.obj
```

2. Compile the HashLink wrapper:
```bash
cl /c /I"%HASHLINK_PATH%\include" tsf_hl.c /Fo:tsf_hl.obj
```

3. Link into a native .hdll:
```bash
link /DLL /OUT:tsf.hdll tsf_hl.obj tsf_bridge.obj libhl.lib /LIBPATH:"%HASHLINK_PATH%"
```

### Linux/macOS (GCC/Clang)

1. Compile the C++ bridge:
```bash
g++ -c -fPIC -I../cpp ../cpp/tsf_bridge.cpp -o tsf_bridge.o
```

2. Compile the HashLink wrapper:
```bash
gcc -c -fPIC -I$HASHLINK_PATH/include tsf_hl.c -o tsf_hl.o
```

3. Link into a native .hdll:
```bash
# Linux
gcc -shared -o tsf.hdll tsf_hl.o tsf_bridge.o -L$HASHLINK_PATH -lhl

# macOS
gcc -shared -o tsf.hdll tsf_hl.o tsf_bridge.o -L$HASHLINK_PATH -lhl -undefined dynamic_lookup
```

## Installation

Copy the compiled `tsf.hdll` to one of these locations:
- Same directory as your .hl executable
- `$HASHLINK_PATH/` (HashLink installation directory)
- Your project's output directory

## Usage from Haxe

```haxe
#if hl
@:hlNative("tsf")
class TSFNative {
    public static function init(path:hl.Bytes):Dynamic { return null; }
    public static function noteOn(handle:Dynamic, channel:Int, note:Int, velocity:Int):Void {}
    public static function render(handle:Dynamic, buffer:hl.Bytes, samples:Int):Int { return 0; }
    // ... other functions
}
#end
```

## Notes

- The native library must be compiled with the same compiler and settings as HashLink
- Ensure `libhl` is available during linking
- The .hdll file must match your platform (Windows .dll, Linux .so, macOS .dylib conventions apply)
- Test with `hl --version` to verify HashLink installation

## Troubleshooting

**Error: Cannot load library tsf.hdll**
- Check that the .hdll is in the correct path
- Verify the file has proper permissions
- On Linux/macOS, check with `ldd tsf.hdll` (Linux) or `otool -L tsf.hdll` (macOS)

**Linking errors**
- Ensure you're using the correct HashLink version headers
- Match compiler flags with HashLink build configuration
- On Windows, verify libhl.lib is in the LIBPATH
