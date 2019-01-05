@echo off
echo ***** Removing old versions... *****

@echo on
rmdir /S /Q C:\Users\Administrator\Desktop\heroesshare-tmp

@echo off
echo ***** Updating repos... *****

@echo on
cd C:\Git\heroesshare-gamedata
git pull

cd C:\Git\heroesshare-live-win
git pull
git submodule update --recursive --remote

@echo off
echo ***** Ready to compare protocol versions. Next: Listing latest version. *****
pause

@echo on
dir /OD C:\Git\heroesshare-live-win\heroprotocol

@echo off
echo ***** Current version: *****
type C:\Git\heroesshare-live-win\version.txt
echo. 

echo ***** Update repo version.txt to build.protocol. Next: Generating workspace in Desktop\heroesshare-tmp... *****
pause

@echo on
mkdir C:\Users\Administrator\Desktop\heroesshare-tmp
xcopy /S /Q /Y C:\Git\heroesshare-live-win\heroprotocol C:\Users\Administrator\Desktop\heroesshare-tmp\heroprotocol\
copy C:\Git\heroesshare-live-win\rejoinprotocol.py C:\Users\Administrator\Desktop\heroesshare-tmp\heroprotocol\
copy C:\Git\heroesshare-live-win\logo.ico C:\Users\Administrator\Desktop\heroesshare-tmp\

@echo off
echo ***** Check if heroprotocol.py updated (if so make new rejoinprotocol.py) *****
echo ***** Change latest protocol, line 90 'm_hero' 19 to 6 *****
pause

echo ***** Creating parser *****
cd C:\Users\Administrator\Desktop\heroesshare-tmp\heroprotocol
@echo on
pyinstaller -i ../logo.ico --onefile --add-data "protocol*.py;." rejoinprotocol.py

@echo off
echo ***** Testing parser *****
@echo on
C:\Users\Administrator\Desktop\heroesshare-tmp\heroprotocol\dist\rejoinprotocol.exe

@echo off
pause

echo ***** Updating repo rejoinprotocol.exe - supply Blizzard's comment for automated upload *****
@echo on

copy /Y C:\Users\Administrator\Desktop\heroesshare-tmp\heroprotocol\dist\rejoinprotocol.exe C:\Git\heroesshare-live-win\
cd C:\Git\heroesshare-live-win\
git add .
git commit
git push
rmdir /S /Q C:\Users\Administrator\Desktop\heroesshare-tmp

@echo off
echo ***** Creating installer ZIP *****
pause

@echo on
rmdir /S /Q C:\Users\Administrator\Desktop\heroesshare-tmp
mkdir C:\Users\Administrator\Desktop\heroesshare-tmp

copy C:\Git\heroesshare-live-win\rejoinprotocol.exe C:\Users\Administrator\Desktop\heroesshare-tmp\
copy C:\Git\heroesshare-live-win\Setup.bat C:\Users\Administrator\Desktop\heroesshare-tmp\
copy C:\Git\heroesshare-live-win\version.txt C:\Users\Administrator\Desktop\heroesshare-tmp\
copy C:\Git\heroesshare-live-win\*.xml C:\Users\Administrator\Desktop\heroesshare-tmp\
copy C:\Git\heroesshare-live-win\*.ps1 C:\Users\Administrator\Desktop\heroesshare-tmp\

@echo off
echo ***** Compress files in C:\Users\Administrator\Desktop\heroesshare-tmp and copy to assets/clients *****
pause

echo ***** All done! Cleaning up. Remember to update "Client version win" setting in DB (#35) and shut down the VM *****
@echo on

rmdir /S /Q C:\Users\Administrator\Desktop\heroesshare-tmp
