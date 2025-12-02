@echo off
REM Copy tsfhl.hdll to Export\hl\bin after HL build
setlocal
set SRC=MidiSynth\hl\tsfhl.hdll
set DEST=Export\hl\bin\tsfhl.hdll

if exist "%SRC%" (
    copy /Y "%SRC%" "%DEST%"
    echo Copied %SRC% to %DEST%
) else (
    echo ERROR: %SRC% not found!
    exit /b 1
)
endlocal
