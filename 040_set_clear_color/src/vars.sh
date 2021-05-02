#!/bin/bash

# set -uex
set -ue

vars() {
	map_file=src/vars_map.sh
	rm -f $map_file

	touch $map_file
}
