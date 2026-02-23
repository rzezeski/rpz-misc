# Assumes input from:
#
#    kstat -p -p cxgbe<N>::mac_rx_hwlane*:
#
# Assumes data from 10 second iperf run.

BEGIN {
    # Split by space, tab, or colon.
    FS="[ \t:]+"
}

/snaptime|fanout|crtime/ {
    next;
}

{
    srs = $1 ":" $3;
    stat = $1 ":" $3 ":" $4;
    val = $5;

    if (seen[stat] > 2) {
	printf("ERROR - saw '%s' more than twice", stat);
	exit(1);
    } else if (seen[stat] == 1) {
	delta[stat] = val - before[stat];
	seen[stat] += 1;
	if (delta[stat] > 0) {
	    printf("%-48s %-16u\n", stat, delta[stat]);

	    if (unique_srs[srs] == 0) {
		unique_srs[srs] = 1;
	    }

	    if ($4 == "rbytes") {
		rbytes[srs] = delta[stat];
	    }

	    if ($4 == "polls") {
		polls[srs] = delta[stat];
	    }

	    if ($4 == "pollbytes") {
		pollbytes[srs] = delta[stat];
	    }

	    if ($4 == "intrs") {
		intrs[srs] = delta[stat];
	    }

	    if ($4 == "intrbytes") {
		intrbytes[srs] = delta[stat];
	    }
	}
    } else {
	before[stat] = val;
	seen[stat] += 1;
    }
}

END {
    printf("\n");
    printf("--- UNIQUE SRSes ---\n");
    for (srs in unique_srs) {
	printf("%s\n", srs);
	if (rbytes[srs] > 0) {
	    printf("%-18s %-24u (%.2f Gbps)\n", "TOTAL BYTES", rbytes[srs],
		   ((rbytes[srs] * 8) / 10) / (1000 * 1000 * 1000));
	    printf("%-18s %-24u %u%%\n", "POLL BYTES", pollbytes[srs],
		   (pollbytes[srs] / rbytes[srs]) * 100);
	    printf("%-18s %-24u %u%%\n", "INTR BYTES", intrbytes[srs],
		   (intrbytes[srs] / rbytes[srs]) * 100);
	    poi = polls[srs] "/" intrs[srs];
	    printf("%-18s %-24s %.2fx\n", "POLLS/INTRS", poi,
		   (polls[srs] / intrs[srs]));
	}
    }
}
