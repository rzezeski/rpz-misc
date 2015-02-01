#!/bin/sh
#
# Stolen from Rich Lowe.

MODE=0                          # Symbol search
CSCOPE=$(which cscope-fast)
[[ -x $CSCOPE ]] || CSCOPE="cscope"

modes[0]="symbol"
modes[1]="definition of"
modes[2]="functions called by"
modes[3]="functions calling"
modes[4]="assignments to"
modes[7]="file"
modes[8]="files including"

while getopts "dCcafi" opt; do
    case $opt in
        d) MODE=1;;               # definition
        c) MODE=2;;               # called by
        C) MODE=3;;               # calling
        a) MODE=4;;               # Assignment
        f) MODE=7;;               # File
        i) MODE=8;;               # Including
    esac
done

shift $(($OPTIND - 1))

echo "Searching for ${modes[MODE]} $1"
$CSCOPE -qd -L${MODE} "$1" | nawk '
{   m=$0;
    sub("[^ ]+ [^ ]+ [^ ]+ ", "", m);
    printf("%s:%d: (%s) %s\n", $1, $3, $2, m);
}'
