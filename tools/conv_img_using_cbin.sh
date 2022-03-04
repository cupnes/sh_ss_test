#!/bin/bash

# set -uex
set -ue

SRC=$1
DST=$2
CONV_IMG=$(dirname $0)/conv_img

name=$(echo $SRC | rev | cut -d'.' -f2- | rev)
page="-page $(identify $SRC | cut -d ' ' -f 3)+0+0"
convert $SRC -strip ${page} -resize 320x224! -depth 5 ${name}.ppm
tail -n +4 ${name}.ppm >${name}.dat
cat ${name}.dat | $CONV_IMG >$DST
rm ${name}.ppm ${name}.dat
