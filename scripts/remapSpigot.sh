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
decompiledir="$mcpdir/decompile"

# TODO: Move this to a properties file or something similar
mappingschannel="snapshot"
mappingsid="20161117"

spigotsrg="$mappingsdir/spigot2mcp.srg"
obfsrg="$mappingsdir/spigot2obf.srg"
zipname="mappings.zip"

echo "Copying Spigot jar"
if [[ ! -d ${mappingsdir} ]] ; then
    mkdir -p ${mappingsdir}
fi

rm -f "$mcpdir/$spigotname*"
cp "$spigotpath" "$mcpdir/$spigotname.jar"

(
    echo "Downloading MCP mappings"
    cd ${mappingsdir}
    wget -q "http://export.mcpbot.bspk.rs/mcp_$mappingschannel/$mappingsid-$minecraftversion/mcp_$mappingschannel-$mappingsid-$minecraftversion.zip" -O ${zipname}
    rm -f *.csv
    unzip ${zipname}

    # TODO Generate spigot2mcp.srg file
)

(
    cd ${mcpdir}
    echo "Remapping Spigot to MCP"
    java -jar "$workdir/BuildData/bin/SpecialSource.jar" map -i "$spigotname.jar" -m "$spigotsrg" -o "$spigotname-mapped.jar" 1>/dev/null
    if [[ "$?" != "0" ]] ; then
        echo "Failed remapping Spigot to MCP"
        exit 1
    fi
)

(
    echo "Decompiling MCP remapped Spigot jar"
    rm -rf ${decompiledir}
    ${basedir}/scripts/decompile.sh "$basedir" "$decompiledir" "$mcpdir/$spigotname-mapped.jar"
)

# TODO remap parameters & cleanup MCP code

)
