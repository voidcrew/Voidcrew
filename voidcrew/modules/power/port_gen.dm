/obj/machinery/power/port_gen/pacman
	time_per_sheet = 260
	/// Output before capacitor scaling. Held separately so the fuel profile survives a RefreshParts().
	var/base_power_gen = 0
	/// Fuel capacity before matter bin scaling. Same reason.
	var/base_max_sheets = 0

/obj/machinery/power/port_gen/pacman/Initialize(mapload)
	base_power_gen = initial(power_gen)
	base_max_sheets = initial(max_sheets)
	return ..()

/obj/machinery/power/port_gen/pacman/on_construction(mob/user)
	. = ..()
	var/obj/item/circuitboard/machine/pacman/our_board = circuit
	if(our_board?.high_production_profile)
		base_power_gen = 15 KILO JOULES
		base_max_sheets = 20
		time_per_sheet = 85
	// The parent may have swapped our fuel type, and Initialize() cached the name of the old one.
	var/obj/fuel = sheet_path
	sheet_name = initial(fuel.name)
	RefreshParts()

/// Capacitors set output, matter bins set fuel capacity.
/obj/machinery/power/port_gen/pacman/RefreshParts()
	. = ..()
	// Fall back to a rating of one rather than zero, so a generator missing a part is weak, not dead.
	var/capacitor_rating = max(total_part_rating(/datum/stock_part/capacitor), 1)
	var/bin_rating = max(total_part_rating(/datum/stock_part/matter_bin), 1)

	// Linear in capacitor tier: a tier-1 build matches stock tg's flat output exactly,
	// upgrades scale it up to 4x. (The old *2 doubled even an unupgraded build and
	// topped out at 8x tg's 40 kW ceiling.)
	power_gen = round(base_power_gen * capacitor_rating)
	max_sheets = base_max_sheets * bin_rating * bin_rating
	consumption = total_part_rating(/datum/stock_part/micro_laser)
