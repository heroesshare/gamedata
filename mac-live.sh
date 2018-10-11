#!/bin/sh

### REQUIREMENTS ###
echo "[`date`] Checking requirements..."

selfDir="/Library/Git/heroesshare-gamedata"
if [ ! -d "$selfRepo" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing own directory '$selfDir'"
	exit 1
fi

liveMacDir="/Library/Git/heroesshare-live-mac"
if [ ! -d "$liveMacDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing GitHub repo '$liveMacDir'"
	exit 1
fi

# get current macOS version from website
liveMacCurrent=`/usr/bin/curl --silent https://heroesshare.net/clients/check/mac`
if [ -z "$liveMacCurrent" -o "$liveMacCurrent" = "error" ]; then
	echo "[`date`] ERROR: Unmet requirement: unable to load version from website"
	exit 2
fi


### REPO UPDATES ###
echo "[`date`] Checking for self updates..."
cd "$selfDir"
git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	echo "[`date`] Self out of date! Updating and quitting..."
	git pull
	exit 0
fi

echo "[`date`] Checking for heroesshare-live-mac updates..."
cd "$liveMacDir"
git pull


### HEROPROTOCOL ###

echo "[`date`] Checking for heroprotocol updates..."

# make a backup of heroprotocol.py to see if it changed
currentHeroProtocol=`mktemp`
cp "$liveMacDir/heroprotocol/heroprotocol.py" "$currentHeroProtocol"

# update submodule
git submodule update --recursive --remote

# get latest protocol file
filename=`/usr/bin/find "$liveMacDir/heroprotocol" -name protocol*.py 2> /dev/null | sort -n | tail -n 1`

if [ -z "$filename" ]; then
	echo "[`date`] ERROR: unable to locate latest protocol file from heroprotocol"
	exit 3
fi

