/**
 * # Artifact effect
 *
 * What an artifact does. A rollable effect is any subtype that sets label_name and tier;
 * parents that only share code leave label_name null and never roll.
 */
/datum/artifact_effect
	/// The plain words a labeler offers for it, such as "Heals". Null on abstract parents.
	var/label_name
	/// Name for logs and admins
	var/log_name = "unknown"
	/// ARTIFACT_TIER_*
	var/tier = ARTIFACT_TIER_COMMON
	/// A harvester can drain it into a battery
	var/harvestable = TRUE
	/// Can roll as an artifact's second effect (common and uncommon effects only)
	var/minor = FALSE
	/// The trigger that wakes it (one ARTIFACT_TRIGGER_* flag)
	var/trigger = ARTIFACT_TRIGGER_TOUCH
	/// ARTIFACT_RELEASE_*
	var/release_method = ARTIFACT_RELEASE_TOUCH
	/// ARTIFACT_ENERGY_*: what the analyser reads off it
	var/energy_kind = ARTIFACT_ENERGY_CONCENTRATED
	/// Whatever holds it: an artifact, or a battery once harvested
	var/atom/holder
