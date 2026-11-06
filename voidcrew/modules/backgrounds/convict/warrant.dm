/// Backgrounds: owned by P2. See data/backgrounds/spec.md.

/// Every warrant this round. Never in GLOB.criminal_bounties.
GLOBAL_LIST_EMPTY(background_warrants)

/// Opens a warrant on this mind (BACKGROUND_CONVICT or BACKGROUND_PIRATE). Returns it, or null.
/proc/background_mint_warrant(datum/mind/target, kind)
	return null

/// Closes this mind's open warrant
/proc/background_close_warrant(datum/mind/target, reason)
	return

/// This mind's open warrant, or null
/proc/background_warrant_for_mind(datum/mind/target)
	return null

/// The open warrant whose target's current body is this one, or null
/proc/background_warrant_for_body(mob/living/carbon/human/body)
	return null
