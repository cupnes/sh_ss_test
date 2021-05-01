#!/bin/bash

set -uex
# set -ue

ISO_FILE=$1

cat <<EOF
FILE "$ISO_FILE" BINARY
  TRACK 01 MODE1/2048
    INDEX 01 00:00:00
EOF
