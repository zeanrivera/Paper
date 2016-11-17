#!/usr/bin/env bash

(
set -e
PS1="$"
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
echo "Building Spigot"

cd "$workdir/Spigot"

mvn clean package
)
