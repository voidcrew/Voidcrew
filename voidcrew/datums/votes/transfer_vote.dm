#define CHOICE_TRANSFER "Initiate Crew Transfer"
#define CHOICE_CONTINUE "Continue Playing"

/datum/vote/transfer_vote
	name = "Transfer"
	default_choices = list(
		CHOICE_TRANSFER,
		CHOICE_CONTINUE,
	)
	default_message = "Vote for crew transfer."

/datum/vote/transfer_vote/toggle_votable(mob/toggler)
	if(!toggler)
		CRASH("[type] wasn't passed a \"toggler\" mob to toggle_votable.")

	if(!check_rights_for(toggler.client, R_ADMIN))
		return FALSE

	CONFIG_SET(flag/allow_vote_transfer, !CONFIG_GET(flag/allow_vote_transfer))
	return TRUE

/// Include the lobby so a pending vote cannot launch the fleet before the timer is armed.
/datum/vote/transfer_vote/proc/departure_scheduled()
	return SSovermap.round_end_time || (!SSticker.HasRoundStarted() && CONFIG_GET(number/round_time_limit))

/datum/vote/transfer_vote/is_config_enabled()
	return CONFIG_GET(flag/allow_vote_transfer) && !departure_scheduled()

/datum/vote/transfer_vote/can_be_initiated(forced = FALSE)
	. = ..()
	if(. != VOTE_AVAILABLE)
		return .

	if(departure_scheduled())
		return "Fleet departure is already scheduled."

	return VOTE_AVAILABLE

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
