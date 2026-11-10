// voidcrew/modules/nova_guns. Voidcrew defines are not visible here, so values are literals.

/// Every icon state these guns draw exists: a missing overlay or magazine state is invisible, and nothing reports it.
/datum/unit_test/voidcrew_nova_guns_icons
/datum/unit_test/voidcrew_nova_guns_icons/Run()
	var/list/gun_states = list(
		/obj/item/gun/ballistic/automatic/rapier = list("rapier", "rapier_mag", "rapier_bolt", "rapier_bolt_locked", "rapier_suppressor"),
		/obj/item/gun/ballistic/automatic/pistol/zashch = list("zashch", "zashch_mag", "zashch_bolt", "zashch_bolt_locked"),
		/obj/item/gun/ballistic/rifle/nt_m96 = list("mauser", "mauser_bolt", "mauser_bolt_locked"),
	)
	for(var/gun_path in gun_states)
		var/obj/item/gun/ballistic/gun = allocate(gun_path)
		var/list/known = icon_states(gun.icon)
		for(var/state in gun_states[gun_path])
			TEST_ASSERT(state in known, "[gun_path] has no icon state [state] in [gun.icon]")
	var/obj/item/gun/ballistic/automatic/pistol/zashch/zashch = allocate(/obj/item/gun/ballistic/automatic/pistol/zashch)
	TEST_ASSERT(zashch.inhand_icon_state in icon_states(zashch.lefthand_file), "The Zashch has no left hand sprite")
	TEST_ASSERT(zashch.inhand_icon_state in icon_states(zashch.righthand_file), "The Zashch has no right hand sprite")
	for(var/magazine_path in list(/obj/item/ammo_box/magazine/rapier, /obj/item/ammo_box/magazine/zashch))
		var/obj/item/ammo_box/magazine/magazine = allocate(magazine_path)
		var/list/known = icon_states(magazine.icon)
		var/base_state = initial(magazine.icon_state)
		TEST_ASSERT(base_state in known, "[magazine_path] has no icon state [base_state]")
		TEST_ASSERT("[base_state]-full" in known, "[magazine_path] has no full state")
		TEST_ASSERT("[base_state]-empty" in known, "[magazine_path] has no empty state")
		TEST_ASSERT_EQUAL(magazine.ammo_count(), magazine.max_ammo, "[magazine_path] does not start full")
		TEST_ASSERT_EQUAL(magazine.icon_state, "[base_state]-full", "A full [magazine_path] draws the wrong state")
		var/obj/item/ammo_box/magazine/spent = allocate(text2path("[magazine_path]/empty"))
		TEST_ASSERT_EQUAL(spent.ammo_count(), 0, "The empty [magazine_path] is not empty")
		TEST_ASSERT_EQUAL(spent.icon_state, "[base_state]-empty", "An empty [magazine_path] draws the wrong state")

/// Each gun is its own kind of gun for feel purposes, takes its own magazine and fires its own rounds.
/datum/unit_test/voidcrew_nova_guns_setup
/datum/unit_test/voidcrew_nova_guns_setup/Run()
	var/obj/item/gun/ballistic/automatic/rapier/rapier = allocate(/obj/item/gun/ballistic/automatic/rapier)
	rapier.gun_feel_resolve()
	TEST_ASSERT_EQUAL(rapier.gun_feel_class, "smg", "The Rapier should kick like an SMG")
	TEST_ASSERT_EQUAL(rapier.magazine.type, /obj/item/ammo_box/magazine/rapier, "The Rapier spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(rapier.magazine.max_ammo, 30, "The Rapier magazine is the wrong size")
	TEST_ASSERT_EQUAL(rapier.chambered?.type, /obj/item/ammo_casing/c46x30mm, "The Rapier fires the wrong round")
	TEST_ASSERT(rapier.can_suppress, "The Rapier should take a suppressor")
	TEST_ASSERT(!length(rapier.actions_types), "A one-shot SMG should have no fire selector")
	TEST_ASSERT_NOTNULL(rapier.GetComponent(/datum/component/automatic_fire), "The Rapier should fire automatically")
	TEST_ASSERT_EQUAL("[rapier.fire_sound]", "voidcrew/modules/nova_guns/sound/smg_light.ogg", "Gun feel swapped the Rapier's own shot")
	TEST_ASSERT_EQUAL("[rapier.load_sound]", "voidcrew/modules/gun_feel/sound/smg/smg_reload.ogg", "The Rapier lost the SMG reload sound")
	var/obj/item/suppressor/suppressor = allocate(/obj/item/suppressor)
	rapier.install_suppressor(suppressor)
	TEST_ASSERT_EQUAL(rapier.suppressed, suppressor, "The suppressor did not fit the Rapier")

	var/obj/item/gun/ballistic/automatic/pistol/zashch/zashch = allocate(/obj/item/gun/ballistic/automatic/pistol/zashch)
	zashch.gun_feel_resolve()
	TEST_ASSERT_EQUAL(zashch.gun_feel_class, "pistol", "The Zashch should kick like a pistol")
	TEST_ASSERT_EQUAL(zashch.magazine.type, /obj/item/ammo_box/magazine/zashch, "The Zashch spawned with the wrong magazine")
	TEST_ASSERT_EQUAL(zashch.chambered?.type, /obj/item/ammo_casing/c10mm, "The Zashch fires the wrong round")
	TEST_ASSERT(!zashch.can_suppress, "The Zashch has no threaded barrel")
	var/datum/component/seclite_attachable/mount = zashch.GetComponent(/datum/component/seclite_attachable)
	TEST_ASSERT_NOTNULL(mount, "The Zashch lost its seclite mount")
	TEST_ASSERT_NOTNULL(mount.light, "The Zashch has no seclite")
	TEST_ASSERT(!mount.is_light_removable, "The Zashch's seclite should not come off")

	var/obj/item/gun/ballistic/rifle/nt_m96/mauser = allocate(/obj/item/gun/ballistic/rifle/nt_m96)
	mauser.gun_feel_resolve()
	TEST_ASSERT_EQUAL(mauser.gun_feel_class, "pistol", "The M-96 should kick like a pistol, not a marksman rifle")
	TEST_ASSERT_EQUAL(mauser.magazine.max_ammo, 10, "The M-96 holds the wrong number of rounds")
	TEST_ASSERT_EQUAL(mauser.chambered?.type, /obj/item/ammo_casing/c9mm, "The M-96 fires the wrong round")
	TEST_ASSERT(mauser.semi_auto, "The M-96 should load itself")

/// The M-96 ejects each spent case and chambers the next round, then locks open on an empty gun.
/datum/unit_test/voidcrew_nova_guns_m96_cycle
/datum/unit_test/voidcrew_nova_guns_m96_cycle/Run()
	var/mob/living/carbon/human/consistent/shooter = allocate(/mob/living/carbon/human/consistent)
	var/obj/item/gun/ballistic/rifle/nt_m96/mauser = allocate(/obj/item/gun/ballistic/rifle/nt_m96)
	TEST_ASSERT(shooter.put_in_hands(mauser), "The shooter could not hold the M-96")
	var/obj/item/ammo_casing/first = mauser.chambered
	TEST_ASSERT_NOTNULL(first, "A new M-96 should start with a round chambered")
	for(var/shot in 1 to 10)
		TEST_ASSERT(!mauser.bolt_locked, "The M-96 locked open with rounds left, before shot [shot]")
		mauser.fire_cd = FALSE
		mauser.fire_gun(run_loc_floor_top_right, shooter, FALSE, null)
		TEST_ASSERT_EQUAL(mauser.get_ammo(TRUE), 10 - shot, "The M-96 did not fire shot [shot]")
		if(shot == 1)
			TEST_ASSERT(!(first in mauser.contents), "The first spent case stayed in the gun")
			TEST_ASSERT(!QDELETED(first), "The first spent case was deleted instead of ejected")
			TEST_ASSERT_NOTNULL(mauser.chambered, "The M-96 did not chamber its next round")
	TEST_ASSERT(mauser.bolt_locked, "The M-96 should lock open when it runs dry")
	TEST_ASSERT_NULL(mauser.chambered, "A dry M-96 still has a round chambered")
	TEST_ASSERT_EQUAL(mauser.get_ammo(TRUE), 0, "A dry M-96 still reports rounds")

/// The older guns that joined the shops and loot tables feel like what they are, and the type rules agree.
/datum/unit_test/voidcrew_old_guns_feel
/datum/unit_test/voidcrew_old_guns_feel/Run()
	var/list/classes = list(
		/obj/item/gun/ballistic/automatic/battle_rifle = "rifle",
		/obj/item/gun/ballistic/automatic/pistol/clandestine = "pistol",
		/obj/item/gun/ballistic/automatic/pistol/clandestine/fisher = "pistol",
		/obj/item/gun/ballistic/shotgun/automatic/dual_tube/deadly = "shotgun",
		/obj/item/gun/ballistic/rifle/boltaction/harpoon = "marksman",
		/obj/item/gun/ballistic/rocketlauncher/unrestricted = "launcher",
	)
	for(var/gun_path in classes)
		var/obj/item/gun/gun = allocate(gun_path)
		gun.gun_feel_resolve()
		TEST_ASSERT_EQUAL(gun.gun_feel_class, classes[gun_path], "[gun_path] has the wrong feel class")
