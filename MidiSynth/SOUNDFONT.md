# Getting a SoundFont File

MidiSynth requires a SoundFont 2 (.sf2) file to generate audio. Here's where to get one:

## Quick Download (Recommended for Testing)

### Small SoundFonts (1-10 MB) - Good for Development

**GeneralUser GS v1.471** (29 MB)
- Download: http://www.schristiancollins.com/generaluser.php
- Quality: Excellent, widely used
- License: Free for any use

**FluidR3_GM** (141 MB compressed)
- Download: https://member.keymusician.com/Member/FluidR3_GM/index.html
- Quality: High quality, comprehensive
- License: MIT License

### Tiny SoundFonts (<5 MB) - For Quick Testing

**TimGM6mb** (5.5 MB)
- Download: https://sourceforge.net/projects/timmidity/files/TiMidity/sf2/
- File: `TimGM6mb.sf2`
- Quality: Decent for testing
- License: Public domain

**Unison.sf2** (1.3 MB)
- Very minimal but functional
- Search: "Unison.sf2 download"

## Installation

1. Download a .sf2 file
2. Place it in `Assets/soundfonts/` in your project
3. Rename to `GM.sf2` (or update the path in your code)

```
Assets/
└── soundfonts/
    └── GM.sf2
```

## Direct Download Commands

### Windows (PowerShell)
```powershell
# Create directory
New-Item -ItemType Directory -Force -Path "Assets\soundfonts"

# Download GeneralUser GS (if available via direct link)
# Note: Most require manual download from website
```

### Linux/macOS
```bash
# Create directory
mkdir -p Assets/soundfonts

# Download FluidR3_GM
cd Assets/soundfonts
wget https://keymusician01.s3.amazonaws.com/FluidR3_GM.zip
unzip FluidR3_GM.zip
mv "FluidR3_GM.sf2" GM.sf2
```

## Alternative: Create Minimal Test SoundFont

For initial testing without downloading large files, you can use this minimal Python script to generate a tiny test SoundFont:

```python
# Requires: pip install sf2utils
from sf2utils.generator import Sf2FileGenerator

gen = Sf2FileGenerator()
# Add a simple sine wave preset
gen.add_preset("Piano", bank=0, preset=0)
gen.save("Assets/soundfonts/test.sf2")
```

## SoundFont Collections

### Archive.org
- Search: "soundfont sf2"
- Many public domain SoundFonts available

### MuseScore
- https://musescore.org/en/handbook/soundfonts
- Links to various free SoundFonts

### GitHub
- Search: "sf2 soundfont"
- Several repositories with CC0/MIT licensed fonts

## License Considerations

Always check the license before using in commercial projects:
- ✅ **Public Domain**: Use freely
- ✅ **Creative Commons CC0**: Use freely
- ✅ **MIT/BSD**: Use freely (with attribution)
- ⚠️ **Creative Commons CC-BY**: Requires attribution
- ❌ **All Rights Reserved**: Contact author

## Recommended: GeneralUser GS

For most projects, GeneralUser GS is the best choice:
- Good quality
- Reasonable size (29 MB)
- Comprehensive instrument set
- Free for any use
- Actively maintained

Download from: http://www.schristiancollins.com/generaluser.php

## Testing Your SoundFont

Once downloaded, test with:

```haxe
var synth = new MidiSynth("assets/soundfonts/GM.sf2");
synth.noteOn(0, 60, 127);  // Should play middle C
```

If you hear sound, it's working! 🎵
