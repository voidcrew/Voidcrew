///
/// Crew roster, command and join access.
///
/// Manifest injection, crew registration, the captain chain of command (role,
/// claim, acting), ship renaming, the join password and the crew-only airlock
/// lock. Hull teardown paths (abandon, claim, despawn) live in lifecycle.dm.


/// How long crews must wait between ship renames
#define SHIP_RENAME_COOLDOWN (5 MINUTES)

/obj/structure/overmap/ship
	///Boolean on whether players are allowed to latejoin into this ship, toggled by the job managing console.
	var/joining_allowed = TRUE
	///Password required to latejoin this ship, set by the captain. Null = open to everyone.
	///Only player-created hulls (purchased, requisitioned, commissioned) may carry one;
	///the roundstart fleet stays public - see can_have_join_password().
	var/join_password
	///Assoc list of ckeys (ckey = TRUE) cleared to join: the buyer, past crew, invitees,
	///approved applicants, and anyone who entered the password. Survives respawning,
	///but is cleared when the password changes or the captain resets join access.
	var/list/password_cleared_ckeys = list()
	///Whether this ship's airlocks refuse anyone who is not crew. Off by default, and
	///only settable on hulls that may carry a join password - the roundstart fleet stays
	///public either way (see can_have_join_password()). Maintained together with
	///GLOB.crew_locked_ships by set_crew_only_airlocks(); never write it directly.
	var/crew_only_airlocks = FALSE

/obj/structure/overmap/ship
	///Whether the crew has already picked a custom name. The first rename is quiet; later ones are broadcast galaxy-wide.
	var/renamed_once = FALSE

/obj/structure/overmap/ship
	///Cooldown until the ship can be renamed again
	COOLDOWN_DECLARE(rename_cooldown)
	///Cooldown between sending crew invites
	COOLDOWN_DECLARE(invite_cooldown)
	///Cooldown between lobby requests to open a job slot, shared by all requesters.
	COOLDOWN_DECLARE(join_ping_cooldown)
	///List of pending crew invites: ckey -> invite_time
	var/list/pending_invites = list()
	///Open /datum/ship_application requests to join this ship from the lobby. Only a
	///password-locked hull ever collects any - see voidcrew/modules/captain_management.
	var/list/crew_applications = list()
	/// Mind of whoever claimed this ship (for NPC ships without job_slots)
	var/datum/mind/claimed_captain
	/// Mind of the crew member holding acting command: the first joiner on a ship with
	/// no captain. Revoked the moment a real captain (officer job spawn or claim) arrives.
	var/datum/mind/acting_captain
	/// TRUE while an offer of command is waiting on an answer. One at a time per ship.
	var/command_offer_pending = FALSE
	/// TRUE while a command election is running. One at a time per ship.
	var/election_in_progress = FALSE
	///Cooldown after a failed command election, before another may be called
	COOLDOWN_DECLARE(election_cooldown)

/**
  * Bastardized version of GLOB.manifest.manifest_inject, but used per ship
  */
/obj/structure/overmap/ship/proc/manifest_inject(mob/living/carbon/human/H, datum/job/human_job)
	set waitfor = FALSE
	if(H.mind && !length(H.mind.special_roles)) // Check if not an antag
		manifest[H.real_name] = human_job
	register_crewmember(H)

/obj/structure/overmap/ship/proc/register_crewmember(mob/living/carbon/human/crewmate)
	ship_team.add_member(crewmate.mind)
	// Remember crew across respawns until the password changes or join access is reset.
	if(crewmate.ckey)
		password_cleared_ckeys[crewmate.ckey] = TRUE

	//set their ID to use our bank account
	var/obj/item/card/id/card = crewmate.wear_id
	if(!istype(card))
		return
	var/datum/bank_account/account = SSeconomy.bank_accounts_by_id["[crewmate.account_id]"]
	if(account)
		qdel(account) //delete the individual account.
		card.registered_account = ship_account
		ship_account.bank_cards += card

	crewmate.mind.wipe_memory() //clears ALL memories, but currently all they have is their old bank account.
	crewmate.mind.assigned_role.paycheck_department = ship_team.name

/**
 * Puts an already-spawned player on this ship's crew roster, the same way accepting a
 * captain's invite does: team membership, manifest entry, and a saved password
 * clearance for their ckey (every crew-adding path must grant that - see the join
 * password rules above).
 *
 * NOT register_crewmember(): that is for fresh spawns only - it wipes the mind's
 * memory and folds their bank account into ours, which would trash the character of
 * anyone who already has a life on another ship. This also deliberately leaves their
 * other crew memberships alone: founding or being handed a second hull should not
 * strip a player off their first one.
 *
 * Returns TRUE if they ended up on the roster.
 */
/obj/structure/overmap/ship/proc/enlist_crewmember(mob/living/crewmate)
	if(!crewmate?.mind || !ship_team)
		return FALSE
	ship_team.add_member(crewmate.mind) // no-op if they are already aboard
	if(!(crewmate.real_name in manifest))
		manifest += crewmate.real_name
	if(crewmate.ckey)
		password_cleared_ckeys[crewmate.ckey] = TRUE
	return TRUE

// ===== CAPTAIN MANAGEMENT =====

/**
 * Check if a mob is the captain of this ship.
 * Returns TRUE if the mob holds the officer role for this ship,
 * or if they are the claimed_captain (for NPC ships without job_slots).
 */
/obj/structure/overmap/ship/proc/is_ship_captain(mob/living/check_mob)
	return is_ship_captain_mind(check_mob?.mind)

/// Mind-based command check, also used by the admin roster for offline crew.
/obj/structure/overmap/ship/proc/is_ship_captain_mind(datum/mind/check_mind)
	if(!check_mind)
		return FALSE
	if(!(check_mind in ship_team?.members))
		return FALSE

	// An explicit claim is authoritative AND exclusive. Claiming a derelict lands
	// here, and so does every command transfer and election, so on a ship where
	// command has been handed over exactly one person answers TRUE - the officer job
	// stops conferring it, and a revived former captain does not get it back unless
	// command is transferred to them again. A claimed captain who leaves the roster
	// clears the var (see /datum/team/voidcrew/remove_member), so this can never lock
	// a crew out of their own bridge.
	if(claimed_captain)
		return check_mind == claimed_captain

	// Acting captain: first joiner on a captainless ship. Holds command only while
	// no real captain exists - their authority ends the moment one arrives.
	if(acting_captain && check_mind == acting_captain && !has_real_captain())
		return TRUE

	var/datum/job/captain_job = get_captain_job()
	if(!captain_job)
		return FALSE

	// Ship slots are distinct datums even when their outfits use the same job type:
	// the Pill's Head Prisoner and Prisoner are both /datum/job/prisoner.
	return check_mind.assigned_role == captain_job

/**
 * Get the captain job datum for this ship.
 * Returns the first job with officer = TRUE, or the first job as fallback.
 */
/obj/structure/overmap/ship/proc/get_captain_job()
	for(var/datum/job/job in job_slots)
		if(job.officer)
			return job
	// Fallback to first job if no officer defined
	if(length(job_slots))
		for(var/datum/job/job in job_slots)
			return job
	return null

/**
 * Get the current captain mob if they are online.
 */
/obj/structure/overmap/ship/proc/get_captain()
	for(var/datum/mind/member in ship_team?.members)
		if(member.current?.client && is_ship_captain_mind(member))
			return member.current
	return null

/**
 * Whether the ship has a real captain: a crew member holding the officer job,
 * or a claimed captain (NPC/abandoned hulls). While FALSE, an acting captain
 * holds command authority.
 */
/obj/structure/overmap/ship/proc/has_real_captain()
	if(claimed_captain && (claimed_captain in ship_team?.members))
		return TRUE
	var/datum/job/captain_job = get_captain_job()
	if(!captain_job)
		return FALSE
	for(var/datum/mind/member in ship_team?.members)
		if(member.assigned_role == captain_job)
			return TRUE
	return FALSE

/**
 * Hands acting command of a captainless ship to a crew member: they get the Ship
 * Management button and captain-level checks until a real captain arrives.
 * Returns TRUE if they were given acting command.
 */
/obj/structure/overmap/ship/proc/make_acting_captain(mob/living/holder)
	if(!holder?.mind)
		return FALSE
	if(has_real_captain())
		return FALSE
	if(acting_captain && (acting_captain in ship_team?.members))
		return FALSE // someone already holds acting command
	acting_captain = holder.mind
	grant_captain_management(holder, src)
	to_chat(holder, span_boldnotice("No captain is registered aboard [name]. Command authority falls to you until a [get_captain_job()?.title || "captain"] joins."))
	ship_notify("[holder.real_name] has assumed acting command of the vessel.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(holder)] assumed acting command of [name] (no captain aboard)")
	return TRUE

/**
 * Revokes acting command, because a real captain has arrived. The former acting
 * captain loses the Ship Management button; a real captain who already held acting
 * command over their own ship keeps theirs.
 */
/obj/structure/overmap/ship/proc/clear_acting_captain(mob/living/real_captain)
	if(!acting_captain)
		return
	var/mob/living/former_holder = acting_captain.current
	acting_captain = null
	if(!former_holder || former_holder == real_captain)
		return
	remove_captain_management(former_holder, src)
	to_chat(former_holder, span_boldwarning("[real_captain.real_name] has taken command of [name] - your acting command is over."))
	ship_notify("Command authority transferred to [real_captain.real_name]. [former_holder.real_name] stands down from acting command.", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	log_game("[key_name(former_holder)] lost acting command of [name]: [key_name(real_captain)] took command")

/**
 * Whether this mob may rename the ship: the captain always can; if no captain is
 * available to object (dead, offline, or none assigned), any crew member can.
 */
/obj/structure/overmap/ship/proc/can_rename_ship(mob/living/user)
	if(!user?.mind || !(user.mind in ship_team?.members))
		return FALSE
	if(is_ship_captain(user))
		return TRUE
	// A claimed captain who is alive and connected keeps rename authority to themselves
	var/mob/living/claimed = claimed_captain?.current
	if(claimed?.client && claimed.stat != DEAD)
		return FALSE
	// Same for an acting captain
	var/mob/living/acting = acting_captain?.current
	if(acting?.client && acting.stat != DEAD)
		return FALSE
	// Same for a role-assigned captain
	var/mob/living/captain_mob = get_captain()
	if(captain_mob && captain_mob.stat != DEAD)
		return FALSE
	return TRUE

// ===== JOIN PASSWORD =====

/**
 * Whether this hull may carry a join password at all. The roundstart fleet is the public
 * fleet - locking one would let a crew privatize a hull the round spawned for everyone -
 * so only player-created ships (purchased, requisitioned, commissioned) qualify.
 */
/obj/structure/overmap/ship/proc/can_have_join_password()
	return !(src in SSovermap.initial_ships)

/// Whether a ckey may board without being asked for the password.
/obj/structure/overmap/ship/proc/is_password_cleared(ckey)
	if(!join_password)
		return TRUE
	if(!ckey)
		return FALSE
	return (ckey in password_cleared_ckeys)

/**
 * Whether an attempt matches the join password. Case-insensitive and trimmed - the
 * password travels by being typed into another chat window, so exact casing is the
 * kind of thing that locks friends out over nothing.
 */
/obj/structure/overmap/ship/proc/check_join_password(attempt)
	if(!join_password)
		return TRUE
	return lowertext(trim("[attempt || ""]")) == lowertext(join_password)

/**
 * Sets (or clears, on null/empty) the join password. Changing it also revokes saved
 * join access, including approved applications. Returns TRUE on success.
 * The caller is responsible for authorization; this only enforces which hulls
 * may carry a password at all.
 */
/obj/structure/overmap/ship/proc/set_join_password(new_password, mob/user)
	if(!can_have_join_password())
		if(user)
			to_chat(user, span_warning("[name] is a fleet-issued vessel - joining stays public."))
		return FALSE
	new_password = trim("[new_password || ""]", SHIP_JOIN_PASSWORD_MAX_LEN + 1)
	if(!length(new_password))
		if(!join_password)
			return TRUE
		join_password = null
		reset_join_access()
		if(user)
			to_chat(user, span_notice("Join password cleared - anyone may join [name] again."))
		log_game("[key_name(user)] cleared the join password of ship [name]")
		return TRUE
	if(join_password && check_join_password(new_password))
		return TRUE
	join_password = new_password
	reset_join_access()
	if(user)
		to_chat(user, span_notice("Join password set and saved join access cleared. Players joining [name] from the lobby must enter the new password or receive a new approval or invitation."))
	log_game("[key_name(user)] set a join password on ship [name]")
	return TRUE

/**
 * Revokes remembered passwords, invitations, and application approvals without
 * removing anyone from the crew roster. Authorization is the caller's responsibility.
 */
/obj/structure/overmap/ship/proc/reset_join_access(mob/user)
	password_cleared_ckeys.Cut()
	if(user)
		to_chat(user, span_notice("Saved join access and application approvals for [name] have been cleared. Players must enter the current password or receive a new approval or invitation to rejoin. Crew already aboard remain on the roster."))
		log_game("[key_name(user)] reset saved join access and application approvals for ship [name]")
	return TRUE

// ===== CREW-ONLY AIRLOCKS =====

/**
 * Whether a mob counts as this ship's crew.
 *
 * Two things make you crew and either one is enough: your mind is on the ship's team
 * (you serve aboard right now), or your ckey is cleared past the join password - you
 * bought the hull, you were invited, you typed the password, or you served aboard
 * earlier this round, since the last password change or join access reset. The ckey
 * clause is what keeps a crewman who died and came back
 * through the lobby from being locked out of their own airlocks while the new body's
 * mind is still being put on the roster.
 *
 * Deliberately takes a plain /mob: ghosts and non-human crew ask this too.
 */
/obj/structure/overmap/ship/proc/is_ship_crew(mob/checking)
	if(!checking)
		return FALSE
	if(checking.mind && (checking.mind in ship_team?.members))
		return TRUE
	var/checking_ckey = checking.ckey
	if(!checking_ckey)
		return FALSE
	return (checking_ckey in password_cleared_ckeys)

/**
 * Turns the crew-only airlock lock on or off. Returns TRUE if the state changed.
 *
 * Same hull rule as the join password: the roundstart fleet is the public fleet and
 * cannot be locked, so a crew cannot privatize a hull the round spawned for everyone.
 * Authorization (captain, alive, aboard) is the caller's job; this only enforces which
 * hulls may carry the lock at all, and keeps GLOB.crew_locked_ships in step so the
 * door hot path can skip the whole feature while no ship is using it.
 */
/obj/structure/overmap/ship/proc/set_crew_only_airlocks(new_state, mob/user)
	new_state = !!new_state
	if(new_state && !can_have_join_password())
		if(user)
			to_chat(user, span_warning("[name] is a fleet-issued vessel - its airlocks stay open to everyone."))
		return FALSE
	if(crew_only_airlocks == new_state)
		return FALSE
	crew_only_airlocks = new_state
	if(new_state)
		GLOB.crew_locked_ships |= src
	else
		GLOB.crew_locked_ships -= src
	if(user)
		log_game("[key_name(user)] turned crew-only airlocks [new_state ? "on" : "off"] aboard ship [name]")
	var/lock_message = new_state \
		? "Airlock control is now keyed to the crew roster. Anyone not on it will be refused at the doors." \
		: "Airlock control is no longer keyed to the crew roster. The doors open for anyone again."
	ship_notify(lock_message, "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 30)
	return TRUE

/**
 * Renames the ship, propagating the new name to everything that stores a copy of it:
 * the overmap token, the nav/combat display name, the shuttle docking port, the crew
 * team, the ship bank account, and crew paycheck departments. Everything else
 * (comms tags, hails, sensors, dock listings) reads `name`/`display_name` live.
 *
 * Input is trimmed and validated here so every caller gets the same rules.
 * Returns TRUE on success, FALSE otherwise (bad name, same name, or on cooldown).
 *
 * Arguments:
 * * new_name - The requested name. Trimmed, and rejected if empty/too long/bad characters.
 * * user - The mob performing the rename, for feedback and logging. May be null for code/admin calls.
 * * ignore_cooldown - Skips the cooldown check and does not start a new cooldown (code/admin use).
 */
/obj/structure/overmap/ship/proc/set_ship_name(new_name, mob/user, ignore_cooldown = FALSE)
	if(!new_name)
		return FALSE
	new_name = reject_bad_text(trim(new_name), MAX_NAME_LEN)
	if(!new_name)
		if(user)
			to_chat(user, span_warning("Invalid ship name."))
		return FALSE
	if(new_name == name)
		return FALSE
	if(!ignore_cooldown && !COOLDOWN_FINISHED(src, rename_cooldown))
		if(user)
			to_chat(user, span_warning("The registry was updated too recently. [DisplayTimeText(COOLDOWN_TIMELEFT(src, rename_cooldown))] until this ship can be renamed again."))
		return FALSE

	var/old_name = name
	var/old_team_name = ship_team?.name
	name = new_name
	display_name = new_name
	if(shuttle)
		shuttle.name = new_name
	if(ship_team)
		ship_team.name = new_name
		// Keep crew paychecks pointed at the renamed ship budget
		for(var/datum/mind/crewmate as anything in ship_team.members)
			if(crewmate.assigned_role?.paycheck_department == old_team_name)
				crewmate.assigned_role.paycheck_department = new_name
	if(ship_account)
		SSeconomy.department_accounts -= list("[ship_account.account_holder]" = "[ship_account.account_holder] Budget")
		ship_account.account_holder = new_name
		SSeconomy.department_accounts += list("[new_name]" = "[new_name] Budget")

	if(!ignore_cooldown)
		COOLDOWN_START(src, rename_cooldown, SHIP_RENAME_COOLDOWN)

	// The first custom name is free and quiet; changing an established identity is
	// broadcast galaxy-wide so a rename can't quietly shed a reputation.
	if(renamed_once)
		priority_announce("The vessel formerly registered as [old_name] has been renamed to [new_name].", "Galactic Registry")
	renamed_once = TRUE

	ship_notify("Vessel registry updated: [old_name] is now registered as [new_name].", "SHIP SYSTEMS", SHIP_NOTIFY_NOTICE, 'voidcrew/sound/notify.ogg', 50)
	if(user)
		message_admins("[key_name_admin(user)] renamed vessel '[old_name]' to '[new_name]'")
		log_shuttle("[key_name(user)] renamed ship [old_name] to [new_name]")
	return TRUE

#undef SHIP_RENAME_COOLDOWN
