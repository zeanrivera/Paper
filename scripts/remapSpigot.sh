#!/usr/bin/env bash

(
set -e
basedir="$(cd "$1" && pwd -P)"
workdir="$basedir/work"
mcpdir="$workdir/MCP"
minecraftversion=$(cat ${workdir}/BuildData/info.json | grep minecraftVersion | cut -d '"' -f 4)
spigotname="spigot-$minecraftversion-R0.1-SNAPSHOT"
spigotpath="$workdir/Spigot/Spigot-Server/target/$spigotname.jar"
mappingsdir="$mcpdir/mappings"

mappingschannel="$2"
mappingsid="$3"
zipname="mappings.zip"

echo "Copying Spigot jar"
if [[ ! -d ${mappingsdir} ]] ; then
    mkdir -p ${mappingsdir}
fi

rm -f "$mcpdir/$spigotname*"
cp "$spigotpath" "$mcpdir/$spigotname.jar"

)
