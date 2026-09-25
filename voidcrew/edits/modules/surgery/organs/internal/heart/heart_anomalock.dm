// Voidcrew extensions to code/modules/surgery/organs/internal/heart/heart_anomalock.dm.

/// Signal proc for [COMSIG_ATOM_PRE_EMP_ACT] on the bearer: while the flux
/// capacitors hold charge, eat the whole pulse (self and contents, exactly
/// what the old permanent element granted) and start the recharge clock.
/// While drained this returns nothing and the EMP lands normally, which is
/// what makes EMP a live counter to a chromed-out bearer again.
/obj/item/organ/heart/cybernetic/anomalock/proc/absorb_emp(datum/source, severity)
	SIGNAL_HANDLER
	if(!core || !owner)
		return NONE
	if(!COOLDOWN_FINISHED(src, emp_absorb_cooldown))
		return NONE
	COOLDOWN_START(src, emp_absorb_cooldown, emp_absorb_cooldown_time)
	addtimer(CALLBACK(src, PROC_REF(notify_absorb_recharged)), emp_absorb_cooldown_time)
	add_lightning_overlay(10 SECONDS)
	playsound(owner, 'sound/items/eshield_recharge.ogg', 60)
	owner.balloon_alert(owner, "pulse absorbed!")
	to_chat(owner, span_boldwarning("Your cyberheart shunts the pulse into its flux core. The capacitors are drained; the next one will get through."))
	return EMP_PROTECT_SELF|EMP_PROTECT_CONTENTS

/// Tells the bearer the capacitors are ready to eat another pulse.
/obj/item/organ/heart/cybernetic/anomalock/proc/notify_absorb_recharged()
	if(!owner || !core)
		return
	balloon_alert(owner, "flux capacitors recharged")
	playsound(owner, 'sound/items/eshield_recharge.ogg', 40)

// BAL-4: one teardown for the arc effect, used by the
// expiry timer and by removal (which has to pass the old bearer by hand,
// `owner` is already null there). The pending timer is deliberately left to
// run rather than deltimer'd, these are not TIMER_STOPPABLE so their id is
// TIMER_ID_NULL and deltimer() would CRASH; a late fire finds no overlay left
// to cut and does nothing.
/obj/item/organ/heart/cybernetic/anomalock/proc/drop_lightning_overlay(mob/living/carbon/bearer)
	if(!lightning_overlay)
		return
	bearer?.cut_overlay(lightning_overlay)
	lightning_overlay = null

/obj/item/organ/heart/cybernetic/anomalock
	/// How long the flux capacitors take to recharge after eating a pulse.
	/// Invented, unplaytested number: long enough that a follow-up EMP inside
	/// the same fight lands, short enough that the heart matters every fight.
	var/emp_absorb_cooldown_time = 1 MINUTES
