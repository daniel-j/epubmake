#!/usr/bin/env bash

cwd="$(pwd)/${0%/*}"

sigilcfg="""/usr/lib/sigil
$cwd
/usr/share/hunspell
en
en_US
"""

plugin="$(realpath $1)"
srcdir="$(realpath $2)"
outputfile="$(realpath $3)"

tmpdir="$(mktemp -d --suffix=-epubmake)"
echo "$sigilcfg" > "$tmpdir/sigil.cfg"

echooutput=true

PYTHONPATH=/usr/share/sigil/plugin_launchers/python OUTPUTFILE="$outputfile" python3 /usr/share/sigil/plugin_launchers/python/launcher.py "$srcdir" "$tmpdir" "output" "$plugin" | while read line
do
	[[ "$line" == "<?xml version=\"1.0\" encoding=\"UTF-8\"?>" ]] && echooutput=false
	[ "$echooutput" = true ] && echo "$line"
done

rm -rf "$tmpdir"
