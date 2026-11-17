// Tutorial checklist hooks: the Storage item (cargo shelves and smart lockers,
// voidcrew/modules/storage). Overrides chain with any others of the same proc.

/// Only a player assembling parts counts. Mapped and spawned shelves never pass through here.
/// The parts delete themselves only once the shelf is up.
/obj/item/rack_parts/cargo_shelf/attack_self(mob/user)
	. = ..()
	if(QDELETED(src) && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_STORAGE_SHELF)

/obj/structure/cargo_shelf/load_crate(obj/structure/closet/crate/crate, mob/living/user)
	. = ..()
	if(. && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_STORAGE_CRATE)

/// Called only when a machine frame is finished, never for mapped or spawned lockers.
/obj/machinery/smartfridge/storage/on_construction(mob/user)
	. = ..()
	if(ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_STORAGE_LOCKER)

/// One item by hand.
/obj/machinery/smartfridge/storage/load(obj/item/weapon, mob/user)
	. = ..()
	if(. && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_STORAGE_STORE)

/// A bag emptied into the locker. Returns how many items went in.
/obj/machinery/smartfridge/storage/load_storage(datum/storage/storage, mob/user)
	. = ..()
	if(. > 0 && ismob(user))
		tutorial_credit(user, TUTORIAL_STEP_STORAGE_STORE)
