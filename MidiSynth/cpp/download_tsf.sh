#!/bin/bash
# Download the full TinySoundFont header from GitHub

echo "Downloading TinySoundFont..."

curl -L https://raw.githubusercontent.com/schellingb/TinySoundFont/master/tsf.h -o tsf/tsf.h

if [ $? -eq 0 ]; then
    echo "✓ TinySoundFont downloaded successfully to tsf/tsf.h"
    echo "File size: $(wc -c < tsf/tsf.h) bytes"
else
    echo "✗ Failed to download TinySoundFont"
    echo "Please download manually from:"
    echo "https://github.com/schellingb/TinySoundFont/blob/master/tsf.h"
    exit 1
fi
