#!/bin/bash

# UNTESTED EXAMPLE

../bin/remid.bash "$PWD" "$@" \
 -c "~/Library/Application Support/minecraft/saves/copyNpaste/datapacks/" \
 -s "$PWD/success.bash" \
 -f "$PWD/failure.bash"
