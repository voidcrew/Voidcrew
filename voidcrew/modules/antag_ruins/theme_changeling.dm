/**
 * # The Chrysalis: changeling vestige
 *
 * A medical frigate the hive ate from the inside; what's left of the hive
 * still wants to hear new life. Trials raise a feeder and borrow adaptive flesh;
 * boons are hive-flesh tricks reimplemented without the changeling datum
 * (cooldowns instead of a chem pool).
 */

// ===== PATRON =====

/mob/living/basic/vestige_patron/chrysalis
	name = "the Vestige of Hive Wren"
	desc = "Something wearing a ship doctor's uniform and most of a face. The parts that fit together fit too well. The rest never settled on a shape."
	gender = NEUTER
	outfit_path = /datum/outfit/job/doctor
	appearance_tint = "#d8cfe0"
	trial_types = list(
		/datum/vestige_trial/birth,
		/datum/vestige_trial/faces,
	)
	boon_types = list(
		/datum/vestige_boon/spell/armblade,
		/datum/vestige_boon/spell/armblade/perfected,
		/datum/vestige_boon/spell/fleshmend,
		/datum/vestige_boon/spell/fleshmend/deep,
	)
	idle_lines = list(
		"We were a crew of thirty. Then a crew of one. The arithmetic of it still delights us.",
		"You wear one face your whole life and call US the horror.",
		"The hive is quiet now. Help us remember the noise.",
		"Flesh remembers everything. Yours could too, if you let it.",
	)
	accept_line = "Yes. Yes-yes-yes. Go."
	busy_line = "One hunger at a time."
	fulfilled_line = "We've already sung together. Let the others have their turn."
	renounce_line = "The flesh forgets you. It won't offer so kindly next time."
	claim_line = "Take-take-take. THEN we talk about more."
	exhausted_line = "We've folded everything we remember into you. There's nothing left."
	remember_line = "New skin! Same song. We remember every note we taught you."

// Both trials use fauna tissue, not a DNA datum that basic animals do not have.
/proc/vestige_chrysalis_fauna(mob/living/beast, mob/living/keeper)
	if(!isbasicmob(beast) || QDELETED(beast) || beast.mind || beast.client || beast.mob_size < MOB_SIZE_SMALL || beast.maxHealth < 25)
		return FALSE
	if(!(beast.mob_biotypes & MOB_ORGANIC) || HAS_TRAIT(beast, TRAIT_GODMODE) || HAS_TRAIT(beast, TRAIT_PACIFISM) || (keeper && beast.faction_check_atom(keeper)))
		return FALSE
	var/mob/living/basic/animal = beast
	return animal.melee_damage_upper >= 10

/proc/vestige_chrysalis_raw_tissue(obj/item/tissue)
	return istype(tissue, /obj/item/food/meat/slab) || istype(tissue, /obj/item/food/fishmeat)

/// Return one still-harvestable raw meat type. Empty butcher lists mean an exhausted corpse.
/proc/vestige_chrysalis_meat(mob/living/beast)
	for(var/result in beast.butcher_results)
		if(beast.butcher_results[result] > 0 && (ispath(result, /obj/item/food/meat/slab) || ispath(result, /obj/item/food/fishmeat)))
			return result
	return null

/proc/vestige_chrysalis_active(datum/vestige_trial/trial, mob/living/keeper)
	return !QDELETED(trial) && !trial.fulfilled && !QDELETED(keeper) && keeper.stat == CONSCIOUS && trial.owner?.current == keeper && keeper.mind == trial.owner && keeper.mind.active_vestige_trial == trial

// ===== TRIAL OF BIRTH =====

/datum/vestige_trial/birth
	name = "Trial of Birth"
	desc = "Plant the egg in a dead wild beast, at least carp-sized, with raw meat still in it. Raise the child by commanding it to bite dangerous living fauna: it needs forty points of real feeding damage. Recall it before it is overwhelmed; raw meat or fish heals it but does not make it grow. Bring the grown child beside you and use the egg to send it home."
	var/obj/item/vestige_egg/egg
	var/mob/living/basic/headslug/vestige_child/child

/datum/vestige_trial/birth/on_accepted(mob/living/user)
	egg = hand_over(user, new /obj/item/vestige_egg(get_turf(user)))
	egg.trial_ref = WEAKREF(src)
	hand_over(user, new /obj/item/knife/kitchen(get_turf(user)))
	RegisterSignal(owner, COMSIG_MIND_TRANSFERRED, PROC_REF(on_body_changed))

/datum/vestige_trial/birth/Destroy()
	UnregisterSignal(owner, COMSIG_MIND_TRANSFERRED)
	return ..()

/datum/vestige_trial/birth/proc/on_body_changed(datum/mind/source)
	SIGNAL_HANDLER
	if(!QDELETED(child))
		child.prey_ref = null
		child.ai_controller.CancelActions()

/datum/vestige_trial/birth/get_progress_text()
	if(QDELETED(child) || child.stat == DEAD)
		return "Plant the egg in a dead, dangerous NPC beast with unharvested raw meat. A lost kit can be restarted from this pact."
	return "Child: [child.growth]/40 growth; [round(child.health)]/45 health. Egg on prey: attack. Use egg: recall, or send home when grown and beside you. Raw meat heals 25."

/obj/item/vestige_egg
	name = "chrysalis egg"
	desc = "A glistening ovoid of meat. Its empty shell becomes a voice the child obeys."
	icon = 'icons/obj/medical/organs/organs.dmi'
	icon_state = "innards"
	inhand_icon_state = "egg"
	lefthand_file = 'icons/mob/inhands/items/food_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/items/food_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	var/datum/weakref/trial_ref

/obj/item/vestige_egg/proc/get_trial(mob/living/user)
	var/datum/vestige_trial/birth/trial = trial_ref?.resolve()
	return vestige_chrysalis_active(trial, user) && trial.egg == src && user.is_holding(src) ? trial : null

/obj/item/vestige_egg/examine(mob/user)
	. = ..()
	. += span_notice("On an unbutchered wild carcass: hatch a child in five seconds, consuming one raw meat yield. On living prey within seven tiles: command an attack. Use in hand: recall; when fully grown and beside you, send it home. The child is fragile: 45 health, five damage per bite. It must deal forty real damage itself. Feed it raw meat or fish to heal 25; food grants no growth. The loaned knife can butcher carcasses in combat mode.")

/obj/item/vestige_egg/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	var/datum/vestige_trial/birth/trial = get_trial(user)
	if(!trial)
		return
	if(!QDELETED(trial.child) && trial.child.stat != DEAD)
		command_child(target, user)
		return
	if(target.stat != DEAD || !vestige_chrysalis_fauna(target, user) || !vestige_chrysalis_meat(target))
		balloon_alert(user, "needs a wild carcass with raw meat!")
		return
	balloon_alert(user, "planting the egg...")
	if(!do_after(user, 5 SECONDS, target = target) || get_trial(user) != trial)
		return
	sow(target, user)

/obj/item/vestige_egg/proc/sow(mob/living/target, mob/living/user)
	var/datum/vestige_trial/birth/trial = get_trial(user)
	if(!trial || (!QDELETED(trial.child) && trial.child.stat != DEAD) || !user.Adjacent(target) || target.stat != DEAD || !isturf(target.loc) || !vestige_chrysalis_fauna(target, user))
		return FALSE
	var/meat_type = vestige_chrysalis_meat(target)
	if(!meat_type)
		return FALSE
	// Consume actual harvestable tissue, leaving the corpse and its other property intact.
	target.butcher_results[meat_type]--
	if(target.butcher_results[meat_type] <= 0)
		target.butcher_results -= meat_type
	// Previous dead children remain registered loans until the pact ends.
	trial.child = trial.register_loan(new /mob/living/basic/headslug/vestige_child(get_turf(target)))
	trial.child.trial_ref = WEAKREF(trial)
	trial.child.faction |= REF(user)
	target.visible_message(span_boldwarning("A hungry child tears free of [target]! The emptied egg squeals in [user]'s hand."))
	playsound(target, 'sound/effects/magic/demon_consume.ogg', 40, TRUE)
	trial.refresh_tracker()
	return TRUE

/obj/item/vestige_egg/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	command_child(interacting_with, user)
	return ITEM_INTERACT_BLOCKING

/obj/item/vestige_egg/proc/command_child(mob/living/prey, mob/living/user)
	var/datum/vestige_trial/birth/trial = get_trial(user)
	var/mob/living/basic/headslug/vestige_child/child = trial?.child
	if(QDELETED(child) || child.stat != CONSCIOUS || child.get_trial() != trial)
		return FALSE
	if(prey.stat != CONSCIOUS || !vestige_chrysalis_fauna(prey, user) || !(prey in view(7, user)) || !(child in view(7, user)))
		balloon_alert(user, "child and wild prey must be in sight!")
		return FALSE
	child.prey_ref = WEAKREF(prey)
	child.ai_controller.CancelActions()
	balloon_alert(user, "child: hunt [prey]")
	return TRUE

/obj/item/vestige_egg/attack_self(mob/living/user)
	var/datum/vestige_trial/birth/trial = get_trial(user)
	var/mob/living/basic/headslug/vestige_child/child = trial?.child
	if(QDELETED(child) || child.stat != CONSCIOUS || child.get_trial() != trial)
		balloon_alert(user, "plant in a wild carcass")
		return
	child.prey_ref = null
	child.ai_controller.CancelActions()
	if(child.growth >= 40 && user.Adjacent(child))
		child.visible_message(span_boldnotice("[child] unfolds its new limbs, then slips away into a seam in the flesh of the world."))
		trial.complete()
		return
	balloon_alert(user, "child: return ([round(child.health)] health)")

/mob/living/basic/headslug/vestige_child
	name = "hungry chrysalis child"
	desc = "An unfinished creature learning how to feed. Its keeper's egg directs it."
	health = 45
	maxHealth = 45
	melee_damage_lower = 5
	melee_damage_upper = 5
	melee_attack_cooldown = 1.5 SECONDS
	egg_lain = TRUE
	sentience_type = NONE
	butcher_results = null
	guaranteed_butcher_results = null
	habitable_atmos = null
	minimum_survivable_temperature = 0
	maximum_survivable_temperature = 500
	faction = list("vestige_chrysalis_child")
	ai_controller = /datum/ai_controller/basic_controller/vestige_child
	var/datum/weakref/trial_ref
	var/datum/weakref/prey_ref
	var/growth = 0

/mob/living/basic/headslug/vestige_child/should_inherit_planetary_faction()
	return FALSE

/mob/living/basic/headslug/vestige_child/Initialize(mapload)
	. = ..()
	ADD_TRAIT(src, TRAIT_SPACEWALK, INNATE_TRAIT)
	REMOVE_TRAIT(src, TRAIT_VENTCRAWLER_ALWAYS, INNATE_TRAIT)
	UnregisterSignal(src, COMSIG_HOSTILE_POST_ATTACKINGTARGET)

/mob/living/basic/headslug/vestige_child/proc/get_trial()
	var/datum/vestige_trial/birth/trial = trial_ref?.resolve()
	return !mind && !client && !QDELETED(trial) && trial.child == src && vestige_chrysalis_active(trial, trial.owner?.current) ? trial : null

/mob/living/basic/headslug/vestige_child/examine(mob/user)
	. = ..()
	. += span_notice("[growth]/40 growth; [round(health)]/45 health. Feed raw meat or fish to heal; use the egg to attack or recall.")

/mob/living/basic/headslug/vestige_child/early_melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(!isliving(target))
		return FALSE
	var/mob/living/beast = target
	var/datum/vestige_trial/birth/trial = get_trial()
	var/mob/living/keeper = trial?.owner?.current
	if(!trial || stat != CONSCIOUS || growth >= 40 || target != prey_ref?.resolve() || beast.stat != CONSCIOUS || !Adjacent(target) || !(src in view(7, keeper)) || !vestige_chrysalis_fauna(target, keeper))
		return FALSE
	return ..()

/mob/living/basic/headslug/vestige_child/melee_attack(atom/target, list/modifiers, ignore_cooldown = FALSE)
	if(!isliving(target))
		return FALSE
	var/mob/living/beast = target
	var/before = beast.health
	. = ..()
	var/datum/vestige_trial/birth/trial = get_trial()
	// A lethal hit may delete basic fauna immediately; its health still records
	// the damage in this synchronous attack, and early_melee_attack qualified it.
	if(!. || !trial)
		return .
	var/consumed = min(5, max(0, before), max(0, before - beast.health))
	growth = min(40, growth + consumed)
	if(consumed)
		trial.refresh_tracker()
	if(growth >= 40)
		prey_ref = null
		balloon_alert(trial.owner.current, "child grown: recall it")

/mob/living/basic/headslug/vestige_child/attackby(obj/item/food, mob/living/user, list/modifiers, list/attack_modifiers)
	if(!vestige_chrysalis_raw_tissue(food))
		return ..()
	var/datum/vestige_trial/birth/trial = get_trial()
	if(!trial || user != trial.owner.current || stat != CONSCIOUS || health >= maxHealth)
		return
	if(!do_after(user, 2 SECONDS, target = src) || get_trial() != trial || !user.is_holding(food) || QDELETED(food) || stat != CONSCIOUS)
		return
	nourish(food, user)

/mob/living/basic/headslug/vestige_child/proc/nourish(obj/item/food, mob/living/user)
	var/datum/vestige_trial/birth/trial = get_trial()
	if(!trial || user != trial.owner.current || stat != CONSCIOUS || health >= maxHealth || !user.Adjacent(src) || !user.is_holding(food) || !vestige_chrysalis_raw_tissue(food))
		return FALSE
	qdel(food)
	adjust_health(-25)
	trial.refresh_tracker()
	balloon_alert(user, "fed: [round(health)] health")
	return TRUE

/datum/ai_controller/basic_controller/vestige_child
	blackboard = list(BB_TARGETING_STRATEGY = /datum/targeting_strategy/basic, BB_TARGET_MINIMUM_STAT = CONSCIOUS)
	ai_movement = /datum/ai_movement/basic_avoidance
	planning_subtrees = list(/datum/ai_planning_subtree/vestige_child)

/datum/ai_planning_subtree/vestige_child/SelectBehaviors(datum/ai_controller/controller, seconds_per_tick)
	var/mob/living/basic/headslug/vestige_child/child = controller.pawn
	var/datum/vestige_trial/birth/trial = child.get_trial()
	if(!trial)
		controller.CancelActions()
		return SUBTREE_RETURN_FINISH_PLANNING
	var/mob/living/keeper = trial.owner.current
	var/mob/living/prey = child.prey_ref?.resolve()
	if(prey && prey.stat == CONSCIOUS && child.growth < 40 && (child in view(7, keeper)) && (prey in view(7, keeper)) && vestige_chrysalis_fauna(prey, keeper))
		controller.set_blackboard_key(BB_BASIC_MOB_CURRENT_TARGET, prey)
		controller.queue_behavior(/datum/ai_behavior/basic_melee_attack, BB_BASIC_MOB_CURRENT_TARGET, BB_TARGETING_STRATEGY)
	else
		child.prey_ref = null
		controller.set_blackboard_key(BB_CURRENT_PET_TARGET, keeper)
		controller.queue_behavior(/datum/ai_behavior/pet_follow_friend, BB_CURRENT_PET_TARGET)
	return SUBTREE_RETURN_FINISH_PLANNING

// ===== TRIAL OF FACES =====

/datum/vestige_trial/faces
	name = "Trial of Faces"
	desc = "Taste the tissue of one dead wild beast with raw meat still in it. Borrow its carapace: use the proboscis to brace for one real bite, then move at least two tiles from where you caught it and lash that same living attacker within eight seconds. Assimilate forty points of living tissue this way. The two-second brace roots you and blocks only one basic-fauna melee strike; other attacks still hurt."
	var/obj/item/vestige_proboscis/proboscis
	var/sampled = FALSE
	var/assimilated = 0

/datum/vestige_trial/faces/on_accepted(mob/living/user)
	proboscis = hand_over(user, new /obj/item/vestige_proboscis(get_turf(user)))
	proboscis.trial_ref = WEAKREF(src)
	RegisterSignal(owner, COMSIG_MIND_TRANSFERRED, PROC_REF(on_body_changed))

/datum/vestige_trial/faces/Destroy()
	UnregisterSignal(owner, COMSIG_MIND_TRANSFERRED)
	proboscis?.clear_adaptation()
	return ..()

/datum/vestige_trial/faces/proc/on_body_changed(datum/mind/source)
	SIGNAL_HANDLER
	proboscis?.clear_adaptation()

/datum/vestige_trial/faces/get_progress_text()
	return sampled ? "[assimilated]/40 tissue assimilated. Brace for one bite, move two tiles away from the impact, then lash that attacker within eight seconds. Examine the proboscis for readiness." : "Sample an unbutchered dead wild beast, at least carp-sized. No human DNA is required."

/obj/item/vestige_proboscis
	name = "borrowed proboscis"
	desc = "A coil of flesh that can unfold as a shell or a hungry tendon."
	icon = 'icons/obj/weapons/changeling_items.dmi'
	icon_state = "tentacle"
	inhand_icon_state = "tentacle"
	lefthand_file = 'icons/mob/inhands/antag/changeling_lefthand.dmi'
	righthand_file = 'icons/mob/inhands/antag/changeling_righthand.dmi'
	w_class = WEIGHT_CLASS_SMALL
	force = 0
	var/datum/weakref/trial_ref
	var/datum/weakref/attacker_ref
	var/datum/weakref/body_ref
	var/obj/effect/vestige_trial_marker/impact_point
	var/counter_until = 0
	var/brace_ready_at = 0
	var/datum/status_effect/vestige_chrysalis_brace/brace

/obj/item/vestige_proboscis/Destroy()
	clear_adaptation()
	return ..()

/obj/item/vestige_proboscis/dropped(mob/user, silent = FALSE)
	clear_adaptation()
	return ..()

/obj/item/vestige_proboscis/proc/get_trial(mob/living/user)
	var/datum/vestige_trial/faces/trial = trial_ref?.resolve()
	return vestige_chrysalis_active(trial, user) && trial.proboscis == src && user.is_holding(src) ? trial : null

/obj/item/vestige_proboscis/proc/clear_adaptation()
	var/mob/living/body = body_ref?.resolve()
	if(body)
		UnregisterSignal(body, COMSIG_LIVING_DEATH)
	QDEL_NULL(brace)
	attacker_ref = null
	body_ref = null
	QDEL_NULL(impact_point)
	counter_until = 0

/obj/item/vestige_proboscis/examine(mob/user)
	. = ..()
	. += span_notice("Sample a dead wild animal with raw meat. Use in hand to brace for two seconds (rooted, one bite blocked, five-second cooldown). After a block, move at least two tiles from the impact and lash the same live attacker within eight seconds, from one to four tiles away. Each lash deals up to twenty brute; only actual living tissue lost counts. Dropping this organ or changing bodies sheds the adaptation.")
	if(brace)
		. += span_notice("Carapace braced: waiting for one real fauna bite.")
	else if(world.time < counter_until)
		. += span_notice("Tendon ready for [attacker_ref?.resolve()]: [DisplayTimeText(counter_until - world.time)] remains. Move two tiles from the impact before lashing.")
	else
		. += span_notice(world.time < brace_ready_at ? "Carapace regrowing: [DisplayTimeText(brace_ready_at - world.time)]." : "Carapace ready.")

/obj/item/vestige_proboscis/attack(mob/living/target, mob/living/user, list/modifiers, list/attack_modifiers)
	var/datum/vestige_trial/faces/trial = get_trial(user)
	if(!trial)
		return
	if(trial.sampled)
		counter_lash(target, user)
		return
	if(target.stat != DEAD || !vestige_chrysalis_fauna(target, user) || !vestige_chrysalis_meat(target))
		balloon_alert(user, "needs wild corpse tissue!")
		return
	if(!do_after(user, 3 SECONDS, target = target) || get_trial(user) != trial || !vestige_chrysalis_fauna(target, user) || target.stat != DEAD || !vestige_chrysalis_meat(target))
		return
	trial.sampled = TRUE
	trial.refresh_tracker()
	balloon_alert(user, "tissue learned: brace in hand")

/obj/item/vestige_proboscis/ranged_interact_with_atom(atom/interacting_with, mob/living/user, list/modifiers)
	if(!isliving(interacting_with))
		return NONE
	counter_lash(interacting_with, user)
	return ITEM_INTERACT_BLOCKING

/obj/item/vestige_proboscis/attack_self(mob/living/user)
	begin_brace(user)

/obj/item/vestige_proboscis/proc/begin_brace(mob/living/user)
	var/datum/vestige_trial/faces/trial = get_trial(user)
	if(!trial?.sampled || world.time < brace_ready_at || brace)
		balloon_alert(user, "sample tissue; examine for readiness")
		return FALSE
	clear_adaptation()
	body_ref = WEAKREF(user)
	RegisterSignal(user, COMSIG_LIVING_DEATH, PROC_REF(on_wearer_death))
	brace_ready_at = world.time + 5 SECONDS
	brace = user.apply_status_effect(/datum/status_effect/vestige_chrysalis_brace, src)
	balloon_alert(user, "carapace braced for two seconds")
	return !!brace

/obj/item/vestige_proboscis/proc/on_wearer_death(mob/living/source)
	SIGNAL_HANDLER
	clear_adaptation()

/obj/item/vestige_proboscis/proc/catch_bite(mob/living/user, mob/living/basic/attacker)
	var/datum/vestige_trial/faces/trial = get_trial(user)
	if(!trial || body_ref?.resolve() != user || !brace || !user.Adjacent(attacker) || attacker.stat != CONSCIOUS || !vestige_chrysalis_fauna(attacker, user))
		return FALSE
	attacker_ref = WEAKREF(attacker)
	impact_point = trial.mark_turf(get_turf(user))
	counter_until = world.time + 8 SECONDS
	QDEL_NULL(brace)
	user.visible_message(span_warning("[user]'s borrowed shell catches [attacker]'s bite and splits into a whipping tendon!"))
	balloon_alert(user, "move two tiles, then lash [attacker]!")
	return TRUE

/obj/item/vestige_proboscis/proc/counter_lash(mob/living/target, mob/living/user)
	var/datum/vestige_trial/faces/trial = get_trial(user)
	if(!trial || body_ref?.resolve() != user || target != attacker_ref?.resolve() || world.time >= counter_until)
		balloon_alert(user, "catch a bite from this beast first!")
		return FALSE
	var/turf/impact_turf = get_turf(impact_point)
	if(target.stat != CONSCIOUS || !vestige_chrysalis_fauna(target, user) || !isturf(user.loc) || !impact_turf || user.z != impact_turf.z || get_dist(user, impact_turf) < 2 || get_dist(user, target) > 4 || !(target in view(4, user)))
		balloon_alert(user, "move two tiles; keep live prey in reach!")
		return FALSE
	var/before = target.health
	clear_adaptation()
	user.do_attack_animation(target, ATTACK_EFFECT_BITE)
	target.apply_damage(20, BRUTE)
	// Self-deleting fauna still contributed their remaining living tissue.
	if(get_trial(user) != trial)
		return FALSE
	var/tissue = min(20, max(0, before), max(0, before - target.health))
	trial.assimilated += tissue
	balloon_alert(user, "[tissue] tissue assimilated")
	trial.refresh_tracker()
	if(trial.assimilated >= 40)
		trial.complete()
	return tissue > 0

/datum/status_effect/vestige_chrysalis_brace
	id = "vestige_chrysalis_brace"
	duration = 2 SECONDS
	tick_interval = 0.2 SECONDS
	alert_type = null
	var/datum/weakref/organ_ref

/datum/status_effect/vestige_chrysalis_brace/on_creation(mob/living/new_owner, obj/item/vestige_proboscis/organ)
	organ_ref = WEAKREF(organ)
	return ..()

/datum/status_effect/vestige_chrysalis_brace/on_apply()
	ADD_TRAIT(owner, TRAIT_IMMOBILIZED, TRAIT_STATUS_EFFECT(id))
	RegisterSignal(owner, COMSIG_ATOM_ATTACK_BASIC_MOB, PROC_REF(on_bite))
	return TRUE

/datum/status_effect/vestige_chrysalis_brace/tick(seconds_between_ticks)
	var/obj/item/vestige_proboscis/organ = organ_ref?.resolve()
	if(!organ?.get_trial(owner))
		qdel(src)

/datum/status_effect/vestige_chrysalis_brace/proc/on_bite(mob/living/source, mob/living/basic/attacker)
	SIGNAL_HANDLER
	var/obj/item/vestige_proboscis/organ = organ_ref?.resolve()
	if(organ?.catch_bite(source, attacker))
		return COMSIG_BASIC_ATTACK_CANCEL_CHAIN

/datum/status_effect/vestige_chrysalis_brace/on_remove()
	REMOVE_TRAIT(owner, TRAIT_IMMOBILIZED, TRAIT_STATUS_EFFECT(id))
	UnregisterSignal(owner, COMSIG_ATOM_ATTACK_BASIC_MOB)
	var/obj/item/vestige_proboscis/organ = organ_ref?.resolve()
	if(organ?.brace == src)
		organ.brace = null

// ===== BOONS =====

/datum/vestige_boon/spell/armblade
	name = "Armblade"
	desc = "Reshape your arm into a blade of bone and flesh, and fold it away when you are done with it."
	grant_text = "Your right arm itches, deep in the bone. There's something new folded in there."
	spell_type = /datum/action/cooldown/spell/vestige_armblade

/datum/vestige_boon/spell/armblade/perfected
	name = "Perfected Armblade"
	desc = "A longer, denser blade that cuts through armor, and it forms a lot faster than the first one."
	grant_text = "The thing folded into your arm reshapes itself one final time. This time it gets it right."
	upgrades_from = /datum/vestige_boon/spell/armblade
	spell_type = /datum/action/cooldown/spell/vestige_armblade/perfected

/datum/vestige_boon/spell/fleshmend
	name = "Fleshmend"
	desc = "Knit your wounds closed. Useless while you are on fire."
	grant_text = "Your flesh learns the old hive trick of forgetting its injuries."
	spell_type = /datum/action/cooldown/spell/vestige_fleshmend

/datum/vestige_boon/spell/fleshmend/deep
	name = "Deep Fleshmend"
	desc = "The same mending, ready twice as often. Still useless while you are on fire."
	grant_text = "The hive's trick sinks deeper, past flesh and into the bone."
	upgrades_from = /datum/vestige_boon/spell/fleshmend
	spell_type = /datum/action/cooldown/spell/vestige_fleshmend/deep

/datum/action/cooldown/spell/vestige_armblade
	name = "Form Armblade"
	desc = "Turn your arm into a blade of bone and flesh. Use again to put it away."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "armblade"
	school = SCHOOL_TRANSMUTATION
	cooldown_time = 10 SECONDS
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE
	/// The blade this spell forms
	var/blade_type = /obj/item/melee/arm_blade
	/// Only this action's growth is reclaimed when its mind leaves the body.
	var/datum/weakref/grown_blade_ref

/datum/action/cooldown/spell/vestige_armblade/Remove(mob/remove_from)
	var/obj/item/melee/arm_blade/grown_blade = grown_blade_ref?.resolve()
	grown_blade_ref = null
	if(grown_blade)
		qdel(grown_blade)
	return ..()

/datum/action/cooldown/spell/vestige_armblade/perfected
	name = "Form Perfected Armblade"
	desc = "Turn your arm into a stronger blade of bone and flesh. Use again to put it away."
	cooldown_time = 6 SECONDS
	blade_type = /obj/item/melee/arm_blade/vestige_perfected

/obj/item/melee/arm_blade/vestige_perfected
	name = "perfected arm blade"
	desc = "A grotesque blade of bone and flesh, refined by a dead hive into something better than the living ones ever managed."
	force = 30

/datum/action/cooldown/spell/vestige_armblade/is_valid_target(atom/cast_on)
	return iscarbon(cast_on)

// The cancel lives here: no blade to fold and no hand to grow one in means the
// cast never happens and the cooldown is never paid, this fork's Activate()
// ignores cast()'s return value, so an in-cast reset_spell_cooldown() is dead code
/datum/action/cooldown/spell/vestige_armblade/before_cast(atom/cast_on)
	. = ..()
	if(. & SPELL_CANCEL_CAST)
		return
	var/mob/living/carbon/carbon_cast_on = cast_on
	if(locate(/obj/item/melee/arm_blade) in carbon_cast_on.held_items)
		return
	if(!length(carbon_cast_on.get_empty_held_indexes()))
		carbon_cast_on.balloon_alert(carbon_cast_on, "no free hand!")
		return . | SPELL_CANCEL_CAST

/datum/action/cooldown/spell/vestige_armblade/cast(mob/living/carbon/cast_on)
	. = ..()
	var/obj/item/melee/arm_blade/held = locate(/obj/item/melee/arm_blade) in cast_on.held_items
	if(held)
		var/outdated = held.type != blade_type
		qdel(held)
		if(!outdated)
			cast_on.visible_message(
				span_warning("[cast_on]'s blade melts back into [cast_on.p_their()] arm!"),
				span_notice("You fold the blade away."),
			)
			playsound(cast_on, 'sound/effects/splat.ogg', 50, TRUE)
			return
		// An old model from before the upgrade: the blade is NODROP, so an
		// upgrade claimed mid-form must reshape it in place or strand it forever
	// The blade announces its own arrival (arm_blade's Initialize prints the
	// visible message), but it does it silently. The noise is ours to make
	playsound(cast_on, 'sound/effects/blob/blobattack.ogg', 60, TRUE)
	var/obj/item/new_blade = new blade_type(cast_on)
	grown_blade_ref = WEAKREF(new_blade)
	if(!cast_on.put_in_hands(new_blade))
		if(!QDELETED(new_blade)) // DROPDEL usually beat us to it
			qdel(new_blade)
		cast_on.balloon_alert(cast_on, "no free hand!")

/datum/action/cooldown/spell/vestige_fleshmend
	name = "Fleshmend"
	desc = "Heal your wounds. Won't work while you're on fire."
	button_icon = 'icons/mob/actions/actions_changeling.dmi'
	button_icon_state = "fleshmend"
	school = SCHOOL_TRANSMUTATION
	cooldown_time = 2 MINUTES
	invocation_type = INVOCATION_NONE
	spell_requirements = NONE

/datum/action/cooldown/spell/vestige_fleshmend/deep
	name = "Deep Fleshmend"
	cooldown_time = 1 MINUTES

/datum/action/cooldown/spell/vestige_fleshmend/can_cast_spell(feedback = TRUE)
	. = ..()
	if(!.)
		return FALSE
	var/mob/living/living_owner = owner
	if(istype(living_owner) && living_owner.on_fire)
		if(feedback)
			living_owner.balloon_alert(living_owner, "not while burning!")
		return FALSE
	return TRUE

/datum/action/cooldown/spell/vestige_fleshmend/cast(mob/living/cast_on)
	. = ..()
	cast_on.apply_status_effect(/datum/status_effect/fleshmend)
	cast_on.visible_message(
		span_warning("[cast_on]'s wounds begin to close with a wet, roiling sound!"),
		span_notice("Your flesh remembers being whole."),
	)
