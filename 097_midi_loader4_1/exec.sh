#!/bin/bash

# set -uex
set -ue

MIDI_DEV=/dev/snd/midiC1D0

app=$1
shift

apps/${app}.sh $* >apps/${app}.exe
../tools/dump_data_packets apps/${app}.{exe,pkt}
dd if=apps/${app}.pkt of=$MIDI_DEV status=none
