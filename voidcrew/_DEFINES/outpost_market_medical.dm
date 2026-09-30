// Outpost medical lab (outpost_medical_lab.dm, outpost_autosurgeon.dm, outpost_medical_lab_machines.dm)

#define OUTPOST_MEDICAL_LAB_COST 2000
#define OUTPOST_MEDLAB_PASS_DEFAULT 300
#define OUTPOST_MEDLAB_PASS_MAX 2000
/// How long a bought lab pass lasts
#define OUTPOST_MEDLAB_PASS_TIME (30 MINUTES)
/// A pass with less than this left can be renewed at the terminal
#define OUTPOST_MEDLAB_PASS_RENEW_WINDOW (5 MINUTES)
/// The room's upgrade id
#define OUTPOST_MEDICAL_LAB_ID "medical_lab"
/// Auto-surgeon cycles per run, by procedure kind
#define AUTOSURGEON_TEND_CYCLES 60
#define AUTOSURGEON_FILTER_CYCLES 20
#define AUTOSURGEON_BRAIN_CYCLES 4
/// An idle occupant this long on the slab may be taken off it by anyone
#define AUTOSURGEON_IDLE_EVICT (60 SECONDS)
/// The lab cryo cell ejects its occupant after this long
#define OUTPOST_LAB_CRYO_MAX_STAY (10 MINUTES)
/// How long a conscious patient takes to climb into a lab cryo cell
#define OUTPOST_LAB_CRYO_ENTRY_TIME (2 SECONDS)
