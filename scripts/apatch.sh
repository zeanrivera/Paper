#!/bin/bash
applied=$(echo $1 | sed 's/.patch$/-applied\.patch/g')
if [ ! -f "$1" ]; then
    echo "No patch found $1";
    exit 1;
fi
git am -3 $1 || (
    echo "Failures - Wiggling"
    errors=$(git apply --rej $1 2>&1)
    echo "$errors"
    missingfiles=""
    (for i in $(find . -name \*.rej); do
        base=$(echo "$i" | sed 's/.rej//g')
        if [ -f "$i" ]; then
		    sed -i -e 's/^diff a\/\(.*\) b\/\(.*\)[[:space:]].*rejected.*$/--- \1\n+++ \2/' $i && wiggle -v --replace "$base" "$i"
		    rm "$base.porig" "$i"
	    else
            echo "No such file: $base"
            missingfiles="$missingfiles\n$base"
        fi
    done)

    if [[ "$errors" == *"No such file"* ]]; then
        echo "===========================";
        echo " "
        echo " MISSING FILES"
        echo $(echo "$errors" | grep "No such file")
        echo -e "$missingfiles"
        echo " "
        echo "===========================";
    fi
)
if [[ "$1" != *-applied.patch ]]; then
    mv "$1" "$applied"
fi
