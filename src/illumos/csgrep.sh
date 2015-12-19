#!/bin/sh
#
# Stolen from Rich Lowe. Modified to work with vanilla cscope and
# illumos cscope.

MODE=0                          # Symbol search
CSCOPE=$(which cscope-fast)
[[ -x $CSCOPE ]] || CSCOPE="cscope"

if [ "SunOS" == "$(uname -s)" ]; then
	SUNOS=1
else
	SUNOS=0
fi

modes[0]="symbol"
modes[1]="definition of"
modes[2]="functions called by"
modes[3]="functions calling"
modes[4]="the text string"
modes[6]="egrep pattern"
modes[7]="file"
modes[8]="files including"
modes[9]="assignments to"

while getopts "dCtcaefi" opt; do
    case $opt in
        d) MODE=1;;               # definition
        c) MODE=2;;               # called by
        C) MODE=3;;               # calling
	t) MODE=4;;		  # text string
	e) MODE=6;;		  # egrep
        f) MODE=7;;               # File
        i) MODE=8;;               # Including
        a) MODE=9;;               # Assignment
    esac
done

# This script is normalized for vanilla cscope. Switch numbers if
# running illumos cscope.
if [ $SUNOS -eq 1 ]; then
	if [ $MODE -eq 9 ]; then
		MODE=4
	fi
fi

shift $(($OPTIND - 1))

echo "Searching for ${modes[MODE]} $1"
$CSCOPE -qd -L${MODE} "$1" | nawk '
{   m=$0;
    sub("[^ ]+ [^ ]+ [^ ]+ ", "", m);
    printf("%s:%d: (%s) %s\n", $1, $3, $2, m);
}'
