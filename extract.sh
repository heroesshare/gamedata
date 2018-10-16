#!/bin/sh

# download latest version of HeroesDataParser
url=`curl -s https://api.github.com/repos/koliva8245/HeroesDataParser/releases/latest | ./jq --raw-output '.assets[].browser_download_url' | grep osx`
echo $url
#curl $url -s -l -o "HeroesDataParser.zip"

rm -rf ./extracted
./HeroesDataParser-scd-osx-x64/HeroesData --description 3 --storagePath "/Applications/Heroes of the Storm Public Test" --extract all --json --outputDirectory ./extracted --heroWarnings

