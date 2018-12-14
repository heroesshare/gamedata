#!/bin/sh

### REQUIREMENTS ###

echo "[`date`] Checking requirements..."

selfDir="/Library/Git/heroesshare-gamedata"
if [ ! -d "$selfDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing own directory '$selfDir'"
	exit 1
fi

liveMacDir="/Library/Git/heroesshare-live-mac"
if [ ! -d "$liveMacDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing GitHub repo '$liveMacDir'"
	exit 1
fi

composerDir="/Library/Application Support/JAMF/Composer/Sources"
if [ ! -d "$composerDir" ]; then
	echo "[`date`] ERROR: Unmet requirement: missing Composer sources directory '$composerDir'"
	exit 1
fi

# get current macOS version from website
liveMacCurrent=`/usr/bin/curl --silent https://heroesshare.net/clients/check/mac`
if [ -z "$liveMacCurrent" -o "$liveMacCurrent" = "error" ]; then
	echo "[`date`] ERROR: Unmet requirement: unable to load version from website"
	exit 2
fi

buildCurrent=`echo $liveMacCurrent | /usr/bin/cut -d . -f 1,2`
protocolCurrent=`echo $liveMacCurrent | /usr/bin/cut -d . -f 3`
echo "[`date`] Current version: $liveMacCurrent (build $buildCurrent, protocol $protocolCurrent)"


### REPO UPDATES ###

echo "[`date`] Checking for self updates..."
cd "$selfDir"
git remote update
repoStatus=`git status -uno | grep behind`
if [ "$repoStatus" ]; then
	echo "[`date`] Self out of date! Updating and quitting..."
	git pull
	exit 0
else
	echo "[`date`] Self is current, proceeding."
fi

echo "[`date`] Checking for heroesshare-live-mac updates..."
cd "$liveMacDir"
git pull


### HEROPROTOCOL ###

echo "[`date`] Checking for heroprotocol updates..."

# make a backup of heroprotocol.py to see if it changed
heroprotocolBackup=`mktemp`
cp "$liveMacDir/heroprotocol/heroprotocol.py" "$heroprotocolBackup"

# update submodule
git submodule update --recursive --remote

# get latest protocol file
filename=`/usr/bin/find "$liveMacDir/heroprotocol" -name protocol*.py 2> /dev/null | sort -n | tail -n 1`
if [ -z "$filename" ]; then
	echo "[`date`] ERROR: unable to locate latest protocol file from heroprotocol"
	exit 3
fi

# extract protocol number
protocolLatest=`echo "$filename" | sed -e 's/[^0-9]//g'`
case $protocolLatest in
    ''|*[!0-9]*) echo "[`date`] ERROR: invalid protocol returned from heroprotocol: $protocolLatest"; exit 4 ;;
    *) echo "[`date`] Most recent protocol version on GitHub: $protocolLatest" ;;
esac

# check if current version is latest
if [ "$protocolCurrent" = "$protocolLatest" ]; then
	if [ "$1" = "-force" ]; then
		echo "[`date`] Already current, but force mode detected. Proceeding..."
	else
		echo "[`date`] Already current! Quitting. (Use -force [version] to override)"
		exit 0
	fi
fi

# check if heroprotocol.py changed (requires intervention)
heroprotocolDiff=`diff "$liveMacDir/heroprotocol/heroprotocol.py" "$heroprotocolBackup"`
rm -f "$heroprotocolBackup"
if [ "$heroprotocolDiff" ]; then
	echo "[`date`] Updated heroprotocol.py detected! Intervention required:"
	echo "[`date`] 1. Navigate to repo: '$liveMacDir'"
	echo "[`date`] 2. Copy heroprotocol/heroprotocol.py to ./rejoinprotocol.py"
	echo "[`date`] 3. Edit rejoinprotocol.py (replay.details > save.details, replay.initData > save.initData)"
	read -p "Press enter to continue, Ctrl+C to abort"
fi


### UPDATE ###

if [ "$1" = "-force" ]; then
	versionLatest="$buildCurrent.$2"
else
	versionLatest="$buildCurrent.$protocolLatest"
fi
echo "[`date`] Beginning update to $versionLatest"
read -p "Press enter to continue, Ctrl+C to abort"

# update version.txt - no newline
printf $versionLatest > "$liveMacDir/version.txt"

# get latest comment from heroprotocol - e.g. "Automated upload of generated Heroes Replay Protocol. (2.38.3.69264)"
cd "$liveMacDir/heroprotocol"
commentLatest=`git log -1 --pretty=%B | xargs`


### PUSH ###

# push updated heroesshare-live-mac
echo "[`date`] Pushing to GitHub..."
cd "$liveMacDir"
git add .
git commit -m "$commentLatest"
git push


### ASSET DOWNLOAD ###

echo "[`date`] Fetching Composer source from tat.red..."
scp ec2-user@tat.red:vhosts/heroesshare.net/assets/clients/HeroesShareLive.tar.gz "$composerDir/"
if [ ! -f "$composerDir/HeroesShareLive.tar.gz" ]; then
	echo "[`date`] ERROR: unable to fetch source file from tat.red"
	exit 5
fi


### INJECTION ###

cd "$composerDir"

# remove previous versions
echo "[`date`] Removing old files... Please supply sudo password for next few commands:"
sudo rm -rf "$composerDir/HeroesShareLive"

# extract source files
echo "[`date`] Extracting source..."
sudo tar -xzf HeroesShareLive.tar.gz
if [ ! -d "$composerDir/HeroesShareLive" ]; then
	echo "[`date`] ERROR: unable to extract source file '$composerDir/HeroesShareLive.tar.gz'"
	exit 6
fi
sudo rm -f "$composerDir/HeroesShareLive.tar.gz"

echo "[`date`] Replacing heroprotocol/ and version.txt"
sourceAppDir="$composerDir/HeroesShareLive/ROOT/Library/Application Support/Heroes Share"

# remove current files
sudo rm -rf "$sourceAppDir/heroprotocol"
sudo rm -f "$sourceAppDir/version.txt"

# copy in new files
sudo cp -R "$liveMacDir/heroprotocol" "$sourceAppDir/"
sudo cp -R "$liveMacDir/version.txt" "$sourceAppDir/"
sudo cp -R "$liveMacDir/rejoinprotocol.py" "$sourceAppDir/heroprotocol/"

# set ownership
sudo chown -R root:admin "$sourceAppDir"
# set permission
sudo chmod -R 775 "$sourceAppDir"

# open for verification
echo "[`date`] Opening source ROOT for verification:"
echo "[`date`] 1. Verify heroprotocol/rejoinprotocol.py exists"
echo "[`date`] 2. Verify heroprotocol/protocol${protocolLatest}.py exists"
echo "[`date`] 3. Verify version.txt reads '${versionLatest}' (no newline)"

open "$sourceAppDir"
read -p "Press enter to continue, Ctrl+C to abort"


### COMPOSER ###

echo "[`date`] Launching Composer:"
echo "[`date`] 1. Verify permissions"
echo "[`date`] 2. Build package to ~/Desktop"

open -a "Composer"
read -p "Quit Composer, then press enter to continue, Ctrl+C to abort"


### ASSET UPLOAD ###

if [ ! -f "$HOME/Desktop/HeroesShareLive.pkg" ]; then
	echo "[`date`] ERROR: unable to locate installer package: $HOME/Desktop/HeroesShareLive.pkg"
	exit 7
fi

echo "[`date`] Uploading package..."
scp "$HOME/Desktop/HeroesShareLive.pkg" ec2-user@tat.red:"~/vhosts/heroesshare.net/assets/clients/"

echo "[`date`] Compressing source..."
cd "$composerDir"
sudo tar -czf HeroesShareLive.tar.gz HeroesShareLive
if [ ! -f "$composerDir/HeroesShareLive.tar.gz" ]; then
	echo "[`date`] ERROR: unable to locate source archive: $composerDir/HeroesShareLive.tar.gz"
	exit 8
fi

echo "[`date`] Uploading source..."
scp "$composerDir/HeroesShareLive.tar.gz" ec2-user@tat.red:"~/vhosts/heroesshare.net/assets/clients/"


### CLEANUP ###
rm -f "$HOME/Desktop/HeroesShareLive.pkg"
rm -f "$composerDir/HeroesShareLive.tar.gz"
sudo rm -rf "$composerDir/HeroesShareLive"


### FOLLOWUP ###

echo "[`date`] Update complete! Recommended follow up:"
echo "[`date`] 1. Complete Windows client update"
echo "[`date`] 2. ssh ec2-user@tat.red"
echo "[`date`] 3. cd vhosts/heroesshare.net"
echo "[`date`] 4. git add .; git commit -m '$commentLatest'; git push"
echo "[`date`] 5. eb deploy"
echo "[`date`] 6. ./db.sh"
echo "[`date`] 7m. UPDATE settings SET content='$versionLatest' WHERE id=36 LIMIT 1;"
echo "[`date`] 7w. UPDATE settings SET content='$versionLatest' WHERE id=35 LIMIT 1;"

read -p "Press enter to SSH to tat.red, Ctrl+C to abort"
ssh ec2-user@tat.red

exit 0
