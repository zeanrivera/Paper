#!/usr/bin/env bash

(
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
echo "Building Spigot"

cd "$workdir/Spigot"

sed -i.bak '/<relocations>/,/<\/relocations>/d' Spigot-Server/pom.xml
mvn clean install
rm Spigot-Server/pom.xml
mv Spigot-Server/pom.xml.bak Spigot-Server/pom.xml
)
