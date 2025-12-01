# Downloading HashLink

To use these native bindings, you need HashLink installed on your system. Download the latest release for your platform from:

https://github.com/HaxeFoundation/hashlink/releases

Extract the archive and set the `HASHLINK_PATH` environment variable to the extracted directory (see below).

---

# HashLink Native Build Instructions

This directory contains the HashLink native bindings for TinySoundFont used by `MidiSynth`.

Current naming:
- Native library output: `tsfhl.hdll`
- Build script: `build_hdll.bat` (Windows convenience wrapper)
- Haxe bindings module name: `tsfhl` (see `MidiSynth/haxe/MidiSynth.hx`)

## Setting up HASHLINK_PATH Environment Variable
5. Variable name: `HASHLINK_PATH`
6. Variable value: Your HashLink path (e.g., `C:\HaxeToolkit\hl` or `C:\Program Files\HashLink`)
7. Click OK and restart your terminal

**Method 2: PowerShell Command (Permanent)**
```powershell
# Set for current user (recommended)
[System.Environment]::SetEnvironmentVariable("HASHLINK_PATH", "C:\Users\Clay\Downloads\hashlink-1.15.0-win", "User")

# Then refresh current session
$env:HASHLINK_PATH = "C:\Users\Clay\Downloads\hashlink-1.15.0-win"
```

**Method 3: PowerShell Session (Temporary)**
```powershell
$env:HASHLINK_PATH = "C:\HaxeToolkit\hl"  # Adjust to your path
```

**Method 4: Let the build script find it automatically**
The `build_hdll.bat` script will attempt to locate HashLink by searching for `hl.exe` in common locations:
- `C:\HaxeToolkit\hl`
- `C:\Program Files\HashLink`
- Your PATH environment variable

### Linux / macOS

Add to your `~/.bashrc`, `~/.zshrc`, or `~/.profile`:
```bash
export HASHLINK_PATH="/usr/local/lib/hashlink"  # or /usr/lib/hashlink
```

Then reload: `source ~/.bashrc` (or restart terminal)

To find your HashLink installation:
```bash
which hl  # Shows hl binary location
# If hl is at /usr/local/bin/hl, headers are likely in /usr/local/lib/hashlink or /usr/local/include
```

### Verifying HASHLINK_PATH

```powershell
# Windows (PowerShell)
echo $env:HASHLINK_PATH
dir $env:HASHLINK_PATH\include\hl.h  # Should show the header file

# Linux/macOS
echo $HASHLINK_PATH
ls $HASHLINK_PATH/include/hl.h  # Should show the header file
```

## Fast Build (Windows)

From a regular PowerShell terminal (no need to manually open the VS Developer Prompt):
```powershell
cd MidiSynth/hl
./build_hdll.bat   # answer 'y' if you want to copy into HASHLINK_PATH
```
This script will:
1. Locate `hl.exe` or use `%HASHLINK_PATH%`
2. Run `vcvars64.bat` to set up MSVC environment
3. Compile `tsf_bridge.cpp` and `tsf_hl.c`
4. Link `tsfhl.hdll`
5. Optionally copy to your HashLink installation directory

After building, copy `tsfhl.hdll` into your output folder if not already:
```powershell
Copy-Item MidiSynth\hl\tsfhl.hdll Export\hl\bin\tsfhl.hdll -Force
```

Then run:
```powershell
lime build hl
lime test hl
```

## Manual Build (Windows MSVC)

If you prefer manual steps:
```powershell
call "C:\Program Files\Microsoft Visual Studio\2022\Community\VC\Auxiliary\Build\vcvars64.bat"
cl /c /EHsc /O2 /MD /I..\cpp ..\cpp\tsf_bridge.cpp /Fo:tsf_bridge.obj
cl /c /O2 /MD /I"%HASHLINK_PATH%\include" /I..\cpp tsf_hl.c /Fo:tsf_hl.obj
link /DLL /NOLOGO /OUT:tsfhl.hdll tsf_hl.obj tsf_bridge.obj libhl.lib /LIBPATH:"%HASHLINK_PATH%"
```

## Linux / macOS (GCC / Clang)

1. Compile the C++ bridge:
```bash
g++ -c -fPIC -O2 -I../cpp ../cpp/tsf_bridge.cpp -o tsf_bridge.o
```

2. Compile the HashLink wrapper:
```bash
gcc -c -fPIC -O2 -I$HASHLINK_PATH/include -I../cpp tsf_hl.c -o tsf_hl.o
```

3. Link into a native .hdll:
```bash
# Linux
gcc -shared -o tsfhl.hdll tsf_hl.o tsf_bridge.o -L$HASHLINK_PATH -lhl

# macOS
gcc -shared -o tsfhl.hdll tsf_hl.o tsf_bridge.o -L$HASHLINK_PATH -lhl -undefined dynamic_lookup
```

## Installation / Placement

Place `tsfhl.hdll` in one of:
- `Export/hl/bin/` (Lime output bin directory) – recommended
- Same directory as `MidiFeedi.hl` if running raw hl executable
- `%HASHLINK_PATH%` for global availability

For Lime, copying into `Export/hl/bin` after each rebuild ensures runtime discovery.

## Usage from Haxe

You do not need a separate native class; `MidiSynth.hx` provides HL bindings:
```haxe
#if hl
@:hlNative("tsfhl", "init_memory") private static function tsf_init_memory(buf:hl.Bytes, size:Int):Dynamic;
@:hlNative("tsfhl", "note_on") private static function tsf_note_on(h:Dynamic, ch:Int, note:Int, vel:Int):Void;
// ... see file for full list
#end
```
Initialization (HL) loads the SoundFont into memory:
```haxe
var bytes = sys.io.File.getBytes("Assets/soundfonts/GM.sf2");
handle = tsf_init_memory(bytes, bytes.length);
```

## Notes

- The native library must be compiled with the same compiler and settings as HashLink
- Ensure `libhl` is available during linking
- The .hdll file must match your platform (Windows .dll, Linux .so, macOS .dylib conventions apply)
- Test with `hl --version` to verify HashLink installation

## Troubleshooting

**Error: Cannot load library tsfhl.hdll**
Check that the .hdll is in `Export/hl/bin` or `%HASHLINK_PATH%`.
- Verify the file has proper permissions
- On Linux/macOS, check with `ldd tsf.hdll` (Linux) or `otool -L tsf.hdll` (macOS)

**Linking errors**
Ensure matching HashLink version (header vs runtime).
If primitives fail to load, confirm the module name `tsfhl` matches `@:hlNative` annotations and no stale `tsf.hdll` is shadowing the new file.

**Audio but silence:** Ensure `onSampleData` for HL path reads from `audioQueue` (`#if (cpp || hl)` branch) and that `renderTimer` is ticking.

**Underruns (clicks/gaps):** Increase `MAX_QUEUE_SIZE` or reduce `BUFFER_SIZE` cautiously.
- Match compiler flags with HashLink build configuration
- On Windows, verify libhl.lib is in the LIBPATH
