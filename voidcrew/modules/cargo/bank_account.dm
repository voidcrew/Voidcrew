//PARENT TYPE
/datum/bank_account
	///List of all shipping containers we have connected to us.
	var/list/obj/structure/shipping_container/shipping_containers = list()
	/// world.time up to which this account is frozen because something is actively
	/// draining it. Refreshed on every siphon tick rather than released when the
	/// siphon stops, so a pirate that explodes mid-run can't strand the account.
	var/siphon_lock_until = 0

/**
 * Freezes outgoing transactions on this account for the next few seconds.
 *
 * Called every tick by whatever is draining the account. Without it the crew's
 * answer to being robbed is to empty the account faster than the thief can - into
 * a holochip, a cargo order, a bounty escrow - and hand them a zero balance.
 */
/datum/bank_account/proc/mark_siphoned()
	siphon_lock_until = world.time + SIPHON_ACCOUNT_LOCK_GRACE

/// TRUE while something is actively siphoning this account.
/datum/bank_account/proc/is_siphon_locked()
	return siphon_lock_until > world.time

/**
 * Takes credits out of the account ignoring the siphon freeze.
 *
 * For the two things that have to go through while the account is frozen: the
 * siphon doing the draining, and paying off the pirate holding the tap. Skips the
 * debt bookkeeping in adjust_money(), which only ever applies to deposits.
 *
 * Returns the amount actually taken, which is capped at the balance.
 */
/datum/bank_account/proc/forced_withdraw(amount, reason)
	amount = min(amount, account_balance)
	if(amount <= 0)
		return 0
	account_balance -= amount
	if(reason)
		add_log_to_history(-amount, reason)
	return amount

/**
 * Every spend in the codebase either asks this first or goes through adjust_money(),
 * which asks it for us on negative amounts - so failing it here freezes the account
 * against consoles we've never heard of instead of only the ones we remembered to
 * patch. Deposits are unaffected: they don't consult has_money().
 */
/datum/bank_account/has_money(amount)
	if(is_siphon_locked())
		return FALSE
	return ..()

//SHIP SUBTYPE
/datum/bank_account/ship/New(newname, job, modifier, player_account, obj/structure/overmap/ship/ship)
	. = ..()
	SSeconomy.department_accounts += list("[newname]" = "[newname] Budget")

/datum/bank_account/ship/Destroy()
	. = ..()
	SSeconomy.department_accounts -= list("[account_holder]" = "[account_holder] Budget")
