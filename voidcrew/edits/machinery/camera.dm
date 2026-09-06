/*
 * # Voidcrew camera scoping
 *
 * Upstream camera networks assume a single static station: everything shares
 * the "ss13" network, with a one-shot "[shuttle_id]_" prefix applied when a
 * shuttle template loads. That breaks here, where crews live on ships that
 * hop between (and share) z-levels:
 *
 * * Console subtypes mapped on ships (e.g. the Metis' research console) kept
 *   their own network name ("rd") while the ship's cameras were renamed to
 *   "[shuttle_id]_ss13" - the console listed nothing.
 * * Cameras or consoles built by the crew after ship load kept the plain
 *   "ss13" network: invisible to the ship's mapped console, while a built
 *   console would list every default-network camera in the galaxy.
 * * Mapped bare /obj/machinery/camera (e.g. all 19 on the Nano Phalanx) have
 *   no c_tag, and the console UI hides untagged cameras entirely.
 *
 * Instead, every camera and security console aboard a voidcrew ship is bound
 * to one per-ship network keyed by the ship's mobile docking port, mirroring
 * the ship-scoped radio in voidcrew/modules/comms/comms.dm. The key survives
 * z-level changes (the port moves with the ship) and cannot collide between
 * two ships of the same class. Mapped machinery binds via connect_to_shuttle()
 * at ship load (VOIDCREW EDITs in code/game/machinery/camera/camera.dm and
 * code/game/machinery/computer/camera.dm); machinery built mid-round binds
 * here in post_machine_initialize() by resolving the ship it is physically on.
 *
 * The one step that used to escape all of that was the last step of camera
 * construction: upstream ends it with a free-text "which networks?" prompt that
 * overwrites the binding post_machine_initialize() just made. Nothing a player
 * can type there matches, because the key is an internal ref string and the only
 * network name shown in game is the display name ("Metis (ship-local)") - so a
 * crew-built camera was silently orphaned no matter what was entered. Camera
 * construction aboard a ship now skips the prompt and binds to the hull instead.
 */

/// Camera network key for a voidcrew ship: stable for the ship's lifetime, unique per ship instance.
/// Kept as a proc (not a define) so the upstream VOIDCREW EDITs can use it regardless of include order.
/proc/voidcrew_ship_camera_net(obj/docking_port/mobile/port)
	return "ship_[REF(port)]"

/// Returns the voidcrew mobile docking port of the ship this atom is physically aboard, or null.
/proc/voidcrew_get_camera_ship_port(atom/movable/machine)
	var/obj/docking_port/mobile/voidcrew/ship_port = SSshuttle.get_containing_shuttle(machine)
	return istype(ship_port) ? ship_port : null

/**
 * Human-readable name for a camera network key.
 *
 * Per-ship keys are internal ref strings ("ship_[0x...]"), useless to a player
 * asking "what network is this?". Reverse-resolve them to the owning ship's
 * name; every other key (colosseum, ss13, ...) already reads fine as-is.
 * Console Initialize() lowercases its keys, so compare case-insensitively.
 */
/proc/voidcrew_camera_net_display_name(net_key)
	for(var/obj/docking_port/mobile/voidcrew/port in SSshuttle.mobile_docking_ports)
		if(LOWER_TEXT(voidcrew_ship_camera_net(port)) == LOWER_TEXT(net_key))
			var/ship_name = port.current_ship ? port.current_ship.name : port.name
			return "[ship_name] (ship-local)"
	for(var/obj/structure/overmap/dynamic/player_outpost/home as anything in GLOB.player_outposts)
		if(LOWER_TEXT(net_key) == LOWER_TEXT("outpost_[REF(home)]"))
			return "[home.name] (outpost local)"
	return net_key

/// Tell players what network the console is tuned to - there was no in-game way
/// to learn a ship's camera network name at all.
/obj/machinery/computer/security/examine(mob/user)
	. = ..()
	if(!length(network))
		return
	var/list/names = list()
	for(var/net in network)
		names += voidcrew_camera_net_display_name(net)
	. += span_notice("It is tuned to the [english_list(names)] camera network[length(names) == 1 ? "" : "s"].")

/obj/machinery/camera/post_machine_initialize()
	. = ..()
	// Bind to the ship we're physically on. Mapped ship cameras are (re)bound by
	// connect_to_shuttle() at ship load, which runs after this and wins; this
	// covers cameras assembled by the crew mid-round, when no linkup will ever
	// run again. The turf check keeps borg/mech internal cameras (loc = silicon
	// or exosuit) on their upstream networks.
	if(isturf(loc))
		var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(src)
		if(ship_port)
			network = list(voidcrew_ship_camera_net(ship_port))
		else if(get_outpost_from_atom(src))
			network = list("outpost_[REF(get_outpost_from_atom(src))]")
	// Consoles hide cameras without a c_tag. Upstream station maps hand-name
	// every camera; our ship maps mostly place bare /obj/machinery/camera, so
	// fall back to autoname-style area naming. Autoname subtypes are skipped -
	// they name themselves right after this returns, with their own counter.
	if(!c_tag && !istype(src, /obj/machinery/camera/autoname))
		var/static/list/voidcrew_autonames_in_areas = list()
		var/area/camera_area = get_area(src)
		if(camera_area)
			var/number = voidcrew_autonames_in_areas[camera_area] + 1
			voidcrew_autonames_in_areas[camera_area] = number
			c_tag = "[format_text(camera_area.name)] #[number]"

/**
 * Finishing a camera aboard a ship wires it straight into that ship's network.
 *
 * Upstream asks the builder to type network names here, which is the only place in the
 * chain that can undo the ship binding - and it always did, because the ship's key is
 * never something a player can type. Off ship (ruins, outposts) the stock prompt stays,
 * since those cameras have no hull to belong to.
 */
/obj/machinery/camera/screwdriver_act(mob/user, obj/item/tool)
	if(camera_construction_state != CAMERA_STATE_WIRED)
		return ..()
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(src)
	var/obj/structure/overmap/dynamic/player_outpost/home = get_outpost_from_atom(src)
	if(!ship_port && !home)
		return ..()
	tool.play_tool_sound(src)
	camera_construction_state = CAMERA_STATE_FINISHED
	toggle_cam(user, displaymessage = FALSE)
	network = list(ship_port ? voidcrew_ship_camera_net(ship_port) : "outpost_[REF(home)]")
	balloon_alert(user, "wired to ship network")
	to_chat(user, span_notice("You wire [src] into the [voidcrew_camera_net_display_name(network[1])] camera network."))
	return ITEM_INTERACT_SUCCESS

/obj/machinery/computer/security
	/// FALSE for screens that aren't camera consoles, so they keep their mapped network.
	var/ship_scoped_network = TRUE

/// An entertainment monitor is a television, and upstream leaves it on an empty network
/// on purpose. Binding it to the hull would turn every bar TV into a camera console.
/obj/machinery/computer/security/telescreen/entertainment
	ship_scoped_network = FALSE

/obj/machinery/computer/security/post_machine_initialize()
	. = ..()
	if(!ship_scoped_network)
		return
	// Same as cameras: consoles built mid-round bind to the ship they're on,
	// instead of keeping the galaxy-wide "ss13" default network.
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(src)
	if(ship_port)
		network = list(voidcrew_ship_camera_net(ship_port))
	else if(get_outpost_from_atom(src))
		network = list("outpost_[REF(get_outpost_from_atom(src))]")

/**
 * SecurEye follows the tablet it is running on.
 *
 * The program is the one camera viewer that isn't bolted to a hull, so it can't bind
 * once - it re-resolves the ship every time its static data is rebuilt. Without this it
 * sat on the stock "ss13" network and listed nothing at all aboard a ship.
 */
/datum/computer_file/program/secureye/ui_static_data(mob/user)
	if(computer)
		var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(computer)
		if(ship_port)
			network = list(voidcrew_ship_camera_net(ship_port))
		else if(get_outpost_from_atom(computer))
			network = list("outpost_[REF(get_outpost_from_atom(computer))]")
	return ..()

/**
 * The slime management console reads a camera network, and aboard a ship there
 * is exactly one: the per-ship key every camera on the hull is bound to above.
 *
 * Upstream leaves this console on the galaxy-wide "ss13" network and its
 * camera_advanced/connect_to_shuttle() only prefixes that with the shuttle id,
 * so on a voidcrew hull the console watched a network no camera was ever on.
 * attack_hand() then found neither a camera-visible turf nor a camera on its
 * network, fell through to unset_machine(), and the console did nothing at all
 * when a player clicked it - the Phalanx's xenobiology fitout reported as
 * "doesn't have cameras for xeno console".
 *
 * Bound on use rather than once at init on purpose: the lab is a slot module,
 * and a module's map loads after the hull it attaches to, so neither the
 * console nor its cameras can rely on a single load-time linkup having run in
 * the right order. Re-resolving costs one list lookup per click.
 *
 * Scoped to the xenobiology console deliberately. The other camera_advanced
 * subtypes aboard ships - ship_combat, base_construction/ship, the survey
 * shuttle_docker - build their own eye and never look a camera up, so binding
 * them would be churn with no effect.
 */
/obj/machinery/computer/camera_advanced/xenobio/attack_hand(mob/user, list/modifiers)
	var/obj/docking_port/mobile/voidcrew/ship_port = voidcrew_get_camera_ship_port(src)
	if(ship_port)
		networks = list(voidcrew_ship_camera_net(ship_port))
	else if(get_outpost_from_atom(src))
		networks = list("outpost_[REF(get_outpost_from_atom(src))]")
	return ..()
