#! /bin/sh

unicode_unification () {
	local COMBINING_DIAERESIS="̈" # U+0308
	
	sed \
		-e "s/a$COMBINING_DIAERESIS/ä/g" \
		-e "s/o$COMBINING_DIAERESIS/ö/g" \
		-e "s/u$COMBINING_DIAERESIS/ü/g" \
		-e "s/A$COMBINING_DIAERESIS/Ä/g" \
		-e "s/O$COMBINING_DIAERESIS/Ö/g" \
		-e "s/U$COMBINING_DIAERESIS/Ü/g" \
	
}
