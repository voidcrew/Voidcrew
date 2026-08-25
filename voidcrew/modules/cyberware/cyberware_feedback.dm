/**
 * Dead Channel's reach into upstream mob procs.
 *
 * The editor itself (ware_pro_combat.dm) does everything it can from signals and
 * traits: it pins the health bar and doll with tg's own `fake_healthy`, kills the
 * brute and crit vignettes by trait, and strips the wound lines off a self-examine.
 * Three readouts are built without a hook to hang off, so they are chained here
 * instead, one file, so the next person looking for "why can't I see my own
 * damage" finds all of it in one place.
 *
 * Everything below no-ops unless the bearer actually has a Dead Channel that is
 * currently cutting. A browned-out or EMP'd editor hands every readout back.
 */

/// Returns the bearer's Dead Channel editor only while it is actively cutting
/// their damage feedback. Null for everyone else, which is the common path.
/proc/cutting_dead_channel(mob/living/carbon/bearer)
	if(!istype(bearer))
		return null
	var/obj/item/organ/cyberimp/cyberware/dead_channel/editor = bearer.get_organ_slot(ORGAN_SLOT_CYBERWARE_NERVOUS)
	if(!istype(editor) || !editor.feedback_cut)
		return null
	return editor

/**
 * The self-injury check reports limb damage through a signal the editor already
 * answers, but appends its wound lines, organ lines and the "you feel sick"
 * tox/oxy/stamina block afterwards, where nothing can reach them. Replace the
 * whole pass while cut.
 *
 * Missing limbs still report. The editor sits on the pain nerves, not the eyes.
 * An arm that isn't there is not something you have to feel to notice.
 */
/mob/living/carbon/human/check_self_for_injuries()
	if(!cutting_dead_channel(src))
		return ..()
	// Upstream folded the old UNCONSCIOUS stat into the TRAIT_KNOCKEDOUT trait, so
	// the old `stat >= UNCONSCIOUS` is now two tests. Soft crit still reports, same
	// as before.
	if(IS_UNCONSCIOUS(src) || stat >= HARD_CRIT)
		return

	visible_message(span_notice("[src] examines [p_them()]self."))

	var/list/combined_msg = list(span_notice("<b>You check yourself for injuries.</b>"))
	for(var/missing_zone in get_missing_limbs())
		combined_msg += span_boldannounce("&rdsh; Your [parse_zone(missing_zone)] is missing!")
	combined_msg += span_notice("Nothing else reports back.")

	to_chat(src, boxed_message(combined_msg.Join("<br>")))

/**
 * The oxygen vignette is the one damage overlay upstream applies with no trait
 * gate. The editor clears it from its health-update handler, which covers every
 * path that runs through updatehealth(), but a client view or zoom change calls
 * update_damage_hud() on its own, and that one would re-paint it until the next
 * Life tick. Catch it at the source instead.
 */
/mob/living/carbon/update_damage_hud()
	. = ..()
	if(cutting_dead_channel(src))
		clear_fullscreen("oxy", 0)

/**
 * `fake_healthy` zeroes the doll's per-limb damage keys, but the red wound
 * outline is drawn off the wound list itself and pulses straight through it, a
 * bearer with a cut arm still watches that limb throb. Drop the filters after
 * the parent has laid them down.
 *
 * Clearing the sync list is deliberate: upstream only re-adds outlines when the
 * wounded-zone set CHANGES, so leaving it populated would keep the outlines gone
 * after the editor browns out, until the bearer happened to gain or lose a wound.
 * Nulling it costs an add/remove per health update and gets the outlines back the
 * instant the editor stops cutting.
 *
 * Scoped to Dead Channel rather than to `fake_healthy` itself, so the Numb quirk
 * keeps the behaviour it has always had.
 */
/atom/movable/screen/healthdoll/human/update_icon_state()
	. = ..()
	if(!cutting_dead_channel(hud?.mymob))
		return
	for(var/wounded_zone in animated_zones)
		var/atom/movable/screen/limb_icon = limbs[wounded_zone]
		limb_icon?.remove_filter("wound_outline")
	LAZYNULL(animated_zones)
