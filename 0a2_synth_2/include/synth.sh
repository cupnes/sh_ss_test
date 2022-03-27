if [ "${INCLUDE_SYNTH_SH+is_defined}" ]; then
	return
fi
INCLUDE_SYNTH_SH=true

NOTE_PITCH_CSV=src/note_pitch.csv

PCM_DATA_BASE=25A01000
SQUARE_WAVE_LOW=80
SQUARE_WAVE_HIGH=7f
SQUARE_WAVE_PERIOD=A8
SQUARE_WAVE_PERIOD_DEC=$(echo "ibase=16;$SQUARE_WAVE_PERIOD" | bc)
SLOT_NOT_FOUND=7f
SYNTH_MIDIMSG_QUEUE_BASE=25A70000