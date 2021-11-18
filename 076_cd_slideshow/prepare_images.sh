#!/bin/bash

# set -uex
set -ue

IMAGES_DIR=$1
IMAGE_LIST=$(ls $IMAGES_DIR)
CONV_IMG=../tools/conv_img

mkdir -p converted_images convert_tmp

n=0
for orig_img in $IMAGE_LIST; do
	name=$(printf '%02d' $n)
	page="-page $(identify ${IMAGES_DIR}/$orig_img | cut -d ' ' -f 3)+0+0"
	convert ${IMAGES_DIR}/$orig_img -strip ${page} -resize 320x224! -depth 5 convert_tmp/${name}.ppm
	tail -n +4 convert_tmp/${name}.ppm >convert_tmp/${name}.dat
	cat convert_tmp/${name}.dat | ${CONV_IMG} >converted_images/${name}
	n=$((n + 1))
done

sed -i "s/NUM_IMGS_DEC=.*/NUM_IMGS_DEC=$n/" src/main.sh
