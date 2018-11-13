#!/bin/sh

### PARAMETERS ###
if [ "$1" = "-live" ]; then
	ptr=0
elif [ "$1" = "-ptr" ]; then
	ptr=1
else
	echo "Usage: ./extract [ -live | -ptr ]"
	exit 2
fi

### REQUIREMENTS ###

echo "[`date`] Checking requirements..."

selfDir="/Library/Git/heroesshare-gamedata"
if [ ! -d "$selfDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing own directory '$selfDir'"
	exit 1
fi

repoDir="/Library/Git/HeroesDataParser"
if [ ! -d "$repoDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing GitHub repo '$repoDir'"
	echo "[`date`] Please clone from: https://github.com/koliva8245/HeroesDataParser.git"
	exit 1
fi

extractDir="/Library/Git/heroes-talents"
if [ ! -d "$repoDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing GitHub repo '$extractDir'"
	echo "[`date`] Please clone from: https://github.com/tattersoftware/heroes-talents.git"
	exit 1
fi

parserDir="$HOME/Library/HeroesDataParser-scd-osx-x64"
if [ ! -d "$parserDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing parser directory '$parserDir'"
	echo "[`date`] Download from https://github.com/koliva8245/HeroesDataParser/releases"
	exit 1
fi

if [ $ptr -eq 0 ]; then
	hotsDir="/Applications/Heroes of the Storm"
else
	hotsDir="/Applications/Heroes of the Storm Public Test"
fi
if [ ! -d "$hotsDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing game directory '$hotsDir'"
	exit 1
fi


### REPO UPDATES ###

echo "[`date`] Checking for self updates..."
cd "$selfDir"
git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	echo "[`date`] Self out of date! Updating and quitting... "
	git pull
	exit 0
else
	echo "[`date`] Self is current, proceeding."
fi

echo "[`date`] Checking for HeroesDataParser updates..."
cd "$repoDir"
git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	echo "[`date`] HeroesDataParser out of date! Updating... "
	echo "[`date`] Please download the corresponding release into ~/Library:"
	echo "[`date`] https://github.com/koliva8245/HeroesDataParser/releases"

	git pull
	exit 0
else
	echo "[`date`] HeroesDataParser is current, proceeding."
fi

echo "[`date`] Checking for heroes-talents updates..."
cd "$extractDir"

# make sure to use correct branch
if [ $ptr -eq 1 ]; then
	git checkout ptr
else
	git checkout master
fi

git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	echo "[`date`] heroes-talents not in sync! Please resolve and re-run... "
	exit 0
else
	echo "[`date`] heroes-talents is in sync, proceeding."
fi


### EXTRACTION ###

cd /tmp/
tmpDir=`mktemp -d`
echo "[`date`] Extracting to $tmpDir"
"$parserDir/HeroesData" --description 3 --storagePath "$hotsDir" --extract all --json --outputDirectory "$extractDir/raw" --heroWarnings --localization all

# verify status
if [ $? -ne 0 ]; then
	echo "[`date`] Extraction seems to have failed! Check log at /tmp/debug.log"
	read -p "[`date`] Press enter to continue, Ctrl+C to abort"
fi

# remove old versions
rm -rf "$extractDir/raw"
mkdir "$extractDir/raw"

echo "[`date`] Moving extracted data to $extractDir/raw"
mv $tmpDir/* "$extractDir/raw/"

### REPO COMMIT ###

echo "[`date`] Committing extracted game data"
read -p "[`date`] Press enter to continue, Ctrl+C to abort"

cd "$extractDir"
git add .
git commit -m "Automated update of gamedata extracted by HeroesDataParser"
git push


### CLEAN UP ###

rm -rf $tmpDir
echo "[`date`] Game data updated: $extractDir/raw"

exit 0
