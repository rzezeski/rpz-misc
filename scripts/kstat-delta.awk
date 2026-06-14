# Report kstats that have changed between two invocations. Input can
# either be a single file with the output of two kstat invocations
# appended to it or it could be two files concatenated together. Must
# be parsable output format (kstat -p). Exit with error if the input
# contains more than two snapshots.
BEGIN {
    # Split by tab to break apart stat and value.
    FS="[\t]+"
}

# Ignore snapshot time and creation time.
/snaptime|crtime/ {
    next;
}

{
    stat = $1
    val = $2;

    if (seen[stat] > 2) {
	printf("ERROR - saw '%s' more than twice", stat);
	exit(1);
    } else if (seen[stat] == 1) {
	delta[stat] = val - before[stat];
	seen[stat] += 1;

	if (delta[stat] > 0) {
	    printf("%-48s %-16u\n", stat, delta[stat]);
	}
    } else {
	before[stat] = val;
	seen[stat] += 1;
    }
}
