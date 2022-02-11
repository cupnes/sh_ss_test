#!/bin/bash

# set -uex
set -ue

MIDI_DEV=/dev/snd/midiC1D0

addr=$1

apps/dump_addr_long.sh $addr >dump_addr_long.exe
../tools/dump_data_packets apps/dump_addr_long.{exe,pkt}
dd if=apps/dump_addr_long.pkt of=$MIDI_DEV status=none
