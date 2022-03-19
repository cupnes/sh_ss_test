#!/bin/bash

# set -uex
set -ue

MIDI_DEV=/dev/snd/midiC1D0

access_width=$1
addr=$2

apps/dump_addr_${access_width}.sh $addr >apps/dump_addr_${access_width}.exe
../tools/dump_data_packets apps/dump_addr_${access_width}.{exe,pkt}
dd if=apps/dump_addr_${access_width}.pkt of=$MIDI_DEV status=none
