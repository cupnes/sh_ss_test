#!/bin/bash

# set -uex
set -ue

funcs() {
	map_file=src/funcs_map.sh
	rm -f $map_file

	touch $map_file
}

funcs
