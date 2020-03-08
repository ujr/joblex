#!/bin/sh
# Use GhostScript to count pages in PostScript file(s).
# Copyright (c) 2007 by Urs-Jakob Ruetschi

TEMPFILE=`mktemp` || exit 111
trap "rm -f $TEMPFILE" 0 1 2 3 15
(
cat $* # copy stdin to stdout
cat << EOT
%!
/ws { writestring } def
currentdevice /PageCount gsgetdeviceprop 20 string cvs
($TEMPFILE) (w) file dup dup 4 3 roll ws (\n) ws flushfile
EOT
) | gs -q -dNOPAUSE -sDEVICE=nullpage -sOutputFile=/dev/null -
cat $TEMPFILE
