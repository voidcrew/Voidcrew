// Job categories for ship role preferences
// Players select preferences for these categories, and get matched to ship jobs accordingly

#define JOB_CAT_COMMAND "Command"
#define JOB_CAT_SECURITY "Security"
#define JOB_CAT_ENGINEERING "Engineering"
#define JOB_CAT_MEDICAL "Medical"
#define JOB_CAT_SCIENCE "Science"
#define JOB_CAT_CARGO "Cargo"
#define JOB_CAT_SERVICE "Service"
#define JOB_CAT_ASSISTANT "Assistant"

/// List of all job categories in display order
GLOBAL_LIST_INIT(job_categories, list(
	JOB_CAT_COMMAND,
	JOB_CAT_SECURITY,
	JOB_CAT_ENGINEERING,
	JOB_CAT_MEDICAL,
	JOB_CAT_SCIENCE,
	JOB_CAT_CARGO,
	JOB_CAT_SERVICE,
	JOB_CAT_ASSISTANT,
))
