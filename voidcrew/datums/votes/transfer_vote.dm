#define CHOICE_TRANSFER "Initiate Crew Transfer"
#define CHOICE_CONTINUE "Continue Playing"

/datum/vote/transfer_vote
	name = "Transfer"
	default_choices = list(
		CHOICE_TRANSFER,
		CHOICE_CONTINUE,
	)
	default_message = "Vote for crew transfer."

// Upstream's toggle_votable() takes no arguments and SSvote already gates the "toggleVote"
// ui_act on check_rights_for(R_ADMIN), so the old (mob/toggler) override received null and
// CRASHed on every admin toggle. Siblings (map_vote) just flip the config.
/datum/vote/transfer_vote/toggle_votable()
	CONFIG_SET(flag/allow_vote_transfer, !CONFIG_GET(flag/allow_vote_transfer))

/datum/vote/transfer_vote/is_config_enabled()
	return CONFIG_GET(flag/allow_vote_transfer)

/**
 * Upstream's can_be_initiated takes only (forced) and returns VOTE_AVAILABLE or a *string*
 * explaining the refusal - SSvote shows that string in the vote panel. The old override took
 * a leading (mob/by_who), so `forced` was always null and it returned TRUE/FALSE, neither of
 * which is VOTE_AVAILABLE: the transfer vote could never be initiated at all.
 *
 * The parent already refuses on !is_config_enabled() with a generic message. This checks the
 * same condition first only to name the config, then defers everything else to the parent.
 */
/datum/vote/transfer_vote/can_be_initiated(forced)
	if(!forced && !CONFIG_GET(flag/allow_vote_transfer))
		return "Transfer voting is disabled by server configuration settings."

	return ..()

/datum/vote/transfer_vote/get_vote_result(list/non_voters)
	if(!CONFIG_GET(flag/default_no_vote))
		// Default no votes will add non-voters to "Continue Playing"
		choices[CHOICE_CONTINUE] += length(non_voters)

	return ..()

/datum/vote/transfer_vote/finalize_vote(winning_option)
	if(winning_option == CHOICE_CONTINUE)
		return

	if(winning_option == CHOICE_TRANSFER)
		SSovermap.request_jump()
		return

	CRASH("[type] wasn't passed a valid winning choice. (Got: [winning_option || "null"])")

#undef CHOICE_TRANSFER
#undef CHOICE_CONTINUE
