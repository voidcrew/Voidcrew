/**
 * Weapon blueprints + machined gun parts
 *
 * The two physical halves of the blueprint -> gun pipeline that the weapons bench
 * consumes. See weapons_bench.dm and the per-gun files under guns/.
 *
 * - A blueprint is the "key": found in ruin loot / bought from traders, loaded
 *   into a weapons bench, retained across builds and stealable. It names the gun
 *   it produces and the part it needs.
 * - A part is the "clock output": printed at the protolathe once its techweb part
 *   node is researched. Inert on its own -- only a weapons bench (plus the matching
 *   blueprint and a firing pin) turns it into a gun.
 */

/obj/item/gun_blueprint
	name = "weapon blueprint"
	desc = "A fabrication data disk holding the schematics for a firearm. Load it into a weapons assembly bench."
	icon = 'icons/obj/devices/circuitry_n_data.dmi'
	icon_state = "datadisk1"
	w_class = WEIGHT_CLASS_SMALL
	/// Typepath of the gun this blueprint builds.
	var/result_path
	/// Typepath of the /obj/item/gun_part required to build it.
	var/required_part
	/// Display name of the resulting weapon (examine / bench readout).
	var/blueprint_name = "weapon"

/obj/item/gun_blueprint/examine(mob/user)
	. = ..()
	. += span_notice("Schematic: <b>[blueprint_name]</b>.")
	. += span_notice("Build it at a <b>weapons assembly bench</b> with the matching machined part and a firing pin.")

/obj/item/gun_part
	name = "weapon component"
	desc = "A machined firearm component. Useless on its own -- feed it into a weapons assembly bench together with the matching blueprint and a firing pin."
	icon = 'icons/obj/weapons/guns/ballistic.dmi'
	icon_state = "detective"
	w_class = WEIGHT_CLASS_NORMAL
