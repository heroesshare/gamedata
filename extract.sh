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

talentsDir="/Library/Git/heroes-talents"
if [ ! -d "$talentsDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing GitHub repo '$talentsDir'"
	echo "[`date`] Please clone from: https://github.com/tattersoftware/heroes-talents.git"
	exit 1
fi

parserDir="$HOME/Library/HeroesDataParser"
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

# programs for image conversion
magickPath=`which magick`
if [ ! "$magickPath" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing dependency 'magick'"
	echo "[`date`] Recommend 'brew install ImageMagick'"
	exit 1
fi

renamePath=`which rename`
if [ ! "$renamePath" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing dependency 'rename'"
	echo "[`date`] Recommend 'brew install rename'"
	exit 1
fi


### REPO UPDATES ###

echo "[`date`] Checking for self updates..."
cd "$selfDir"
git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	git pull
	echo "[`date`] Self out of date! Updated - please rerun. "
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
	git pull
	
	echo "[`date`] HeroesDataParser updated. Please download the corresponding release into ~/Library:"
	echo "[`date`] https://github.com/koliva8245/HeroesDataParser/releases"
	exit 0
else
	echo "[`date`] HeroesDataParser is current, proceeding."
fi

echo "[`date`] Checking for heroes-talents updates..."
cd "$talentsDir"

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
chmod +x "$parserDir/heroesdata"
"$parserDir/heroesdata" "$hotsDir" --output-directory "$tmpDir" --description 3 --extract-data all --extract-images all --localization all --json --warnings

# verify status
if [ $? -ne 0 ]; then
	echo "[`date`] Extraction seems to have failed! Check log at /tmp/debug.log or Library/HeroesDataParser/debug.log"
	read -p "[`date`] Press enter to continue, Ctrl+C to abort"
fi

# show diff of extracted JSON data
diff "$talentsDir"/raw/json/herodata_*_enus.json "$tmpDir"/json/herodata_*_enus.json | less

# wait for approval
echo "[`date`] Ready to copy extracted data to $tmpDir/extracted"
read -p "[`date`] Press enter to continue, Ctrl+C to abort"

# copy to upload directory
mkdir -p "$tmpDir"/extracted-talents/raw
cp -R "$tmpDir"/* "$tmpDir"/extracted-talents/raw

# verify move
if [ $? -ne 0 ]; then
	echo "[`date`] Copy seems to have failed!"
	read -p "[`date`] Press enter to continue, Ctrl+C to abort"
fi


### IMAGE RESIZE

echo "[`date`] Resizing talent icons to 64x64"
cd "$tmpDir/images/abilitytalents"
"$magickPath" mogrify -resize 64x64 -strip -depth 8 *.png

# verify status
if [ $? -ne 0 ]; then
	echo "[`date`] Image resize seems to have failed!"
	read -p "[`date`] Press enter to continue, Ctrl+C to abort"
fi

# remove apostrophes from filenames (mostly Kel'Thuzad)
"$renamePath" "s/'//" *.png

# copy to upload directory
mkdir -p "$tmpDir"/extracted-talents/talents
cp "$tmpDir"/images/abilitytalents/*.png "$tmpDir"/extracted-talents/talents/

### COPY TO SERVER
echo "[`date`] Copying extracted data to server for import"
read -p "[`date`] Press enter to continue, Ctrl+C to abort"

scp -r "$tmpDir"/extracted-talents ec2-user@tat.red:/tmp/

### CLEAN UP ###

rm -rf $tmpDir
echo "[`date`] Game data updated: $extractDir/raw"

exit 0
