#!/bin/bash

# set -uex
set -ue

MIDI_DEV=/dev/snd/midiC1D0

access_width=$1
addr=$2

apps/peek_${access_width}.sh $addr >apps/peek_${access_width}.exe
../tools/dump_data_packets apps/peek_${access_width}.{exe,pkt}
dd if=apps/peek_${access_width}.pkt of=$MIDI_DEV status=none
