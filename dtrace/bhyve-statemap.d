#pragma D option quiet
#pragma D option destructive

#define T_WAKEABLE	0x0002

typedef enum {
	STATE_ON_CPU = 0,
	STATE_OFF_CPU_WAITING,
	STATE_OFF_CPU_BLOCKED,
	STATE_MAX
} state_t;

#define STATE_METADATA(_state, _str, _color) \
	printf("\t\t\"%s\": {\"value\": %d, \"color\": \"%s\" }%s\n", \
	    _str, _state, _color, _state < STATE_MAX - 1 ? "," : "");

BEGIN
{
	desc = $$1;
	wall = walltimestamp;

	printf("{\n\t\"start\": [ %d, %d ],\n",
	    wall / 1000000000, wall % 1000000000);
	printf("\t\"title\": \"Bhyve\",\n");
	printf("\t\"host\": \"%s\",\n", `utsname.nodename);
	printf("\t\"desc\": \"%s\",\n", desc);
	printf("\t\"entityKind\": \"Process\",\n");
	printf("\t\"states\": {\n");

	STATE_METADATA(STATE_ON_CPU, "on-cpu", "#9BC362")
	STATE_METADATA(STATE_OFF_CPU_WAITING, "off-cpu-waiting", "#E0E0E0")
	STATE_METADATA(STATE_OFF_CPU_BLOCKED, "off-cpu-blocked", "#C70039")

	printf("\t}\n}\n");
	start = timestamp;
}

sched:::off-cpu
/execname == "bhyve"/
{
	printf("{ \"time\": \"%d\", \"entity\": \"pid=%d tid=%d [%s]\", ",
	    timestamp - start, pid, tid, curpsinfo->pr_psargs);

	printf("\"state\": %d }\n", self->state != STATE_ON_CPU ?
	    self->state : curthread->t_flag & T_WAKEABLE ?
	    STATE_OFF_CPU_WAITING : STATE_OFF_CPU_BLOCKED);
}

sched:::on-cpu
/execname == "bhyve"/
{
	self->state = STATE_ON_CPU;
	printf("{ \"time\": \"%d\", \"entity\": \"pid=%d tid=%d [%s]\", ",
	    timestamp - start, pid, tid, curpsinfo->pr_psargs);
	printf("\"state\": %d }\n", self->state);
}

tick-1sec
/timestamp - start > 3 * 1000000000/
{
	exit(0);
}
