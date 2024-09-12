# scan_apk_for_debuggable
A script to scan apk files for the debuggable flag and order them by their shared uid if there is

How to use this script:

1 Install apktool (not needed for the aapt only version)

2 Install aapt

3 You can use the script, but how does it work? It has three modes:

1. ./script folder_with_apks [enter]

this is the simple scan, and the end you will get a summary on the terminal only

2. ./script folder_with_apks text_file.txt [enter]

this type of scan is like the simple scan but will generate a report of the scan, think of it like doing >> file.txt at the end of a command

3. ./script folder_with_apks --report-debuggable-only text_file.txt [enter]

this type of scan will generate a report with only the debuggable apps ordered by their shared uid, useful if you don't want the full output of the command but only the informations of the apps

Added a version that doesn't decompile and instead parses the manifest with aapt, it should in theory never fail at checking apks, you can try it in case apktool one fails for you
