if [ "${INCLUDE_MEMMAP_SH+is_defined}" ]; then
	return
fi
INCLUDE_MEMMAP_SH=true

VARS_BASE=06004024
FUNCS_BASE=060FA000
MAIN_BASE=060FF000