#!/bin/bash

# set -uex
set -ue

. include/common.sh
. include/sh2.sh

main() {
	sh2_rel_jump_after_next_inst $(two_comp_d 2)
	sh2_nop
}

main
