/**
 * # Vestige boon
 *
 * A ported antagonist ability, granted the moment its trial completes. Boon
 * datums are stateless granters: instantiated, grant() called, deleted.
 *
 * Every boon must work on a plain human with no antag datum attached — either
 * an ability that's already standalone (wizard spells, shadow walk) or a
 * standalone reimplementation (see the theme files).
 */

/datum/vestige_boon
	/// Display name (bookkeeping/logging)
	var/name = "Boon"
	/// Flavor line printed when granted
	var/grant_text

/// Manifests the boon on the supplicant. user is owner.current at grant time.
/datum/vestige_boon/proc/grant(mob/living/user, datum/mind/owner)
	if(grant_text)
		to_chat(user, span_boldnotice(grant_text))

/**
 * Grants an action (spell or otherwise). Mind-targeted, so it follows the
 * player across bodies — the same mechanism as learned wizard spells.
 */
/datum/vestige_boon/spell
	/// Typepath of the /datum/action to grant
	var/spell_type

/datum/vestige_boon/spell/grant(mob/living/user, datum/mind/owner)
	..()
	if(!spell_type)
		return
	var/datum/action/granted = new spell_type(owner || user)
	granted.Grant(user)

/// Conjures a physical item into the supplicant's hands
/datum/vestige_boon/item
	/// Typepath of the item to spawn
	var/item_type

/datum/vestige_boon/item/grant(mob/living/user, datum/mind/owner)
	..()
	if(!item_type)
		return
	var/obj/item/prize = new item_type(get_turf(user))
	user.put_in_hands(prize)
