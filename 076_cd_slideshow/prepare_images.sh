#!/bin/bash

# set -uex
set -ue

IMAGES_DIR=$1
IMAGE_LIST=$(ls $IMAGES_DIR)
CONV_IMG=../tools/conv_img

mkdir -p converted_images convert_tmp

n=0
for orig_img in $IMAGE_LIST; do
	name=$(printf '%02X' $n)
	convert ${IMAGES_DIR}/$orig_img -resize 320x224! -depth 5 convert_tmp/${name}.ppm
	tail -n +4 convert_tmp/${name}.ppm >convert_tmp/${name}.dat
	cat convert_tmp/${name}.dat | ${CONV_IMG} >converted_images/${name}.img
	n=$((n + 1))
done
