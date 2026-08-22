/obj/machinery/power/port_gen/pacman
	time_per_sheet = 260
	/// Output before capacitor scaling. Held separately so the fuel profile survives a RefreshParts().
	var/base_power_gen = 0
	/// Fuel capacity before matter bin scaling. Same reason.
	var/base_max_sheets = 0
	/// Burn time per sheet before micro-laser scaling. Same reason.
	var/base_time_per_sheet = 0

/obj/machinery/power/port_gen/pacman/Initialize(mapload)
	base_power_gen = initial(power_gen)
	base_max_sheets = initial(max_sheets)
	base_time_per_sheet = initial(time_per_sheet)
	return ..()

/obj/machinery/power/port_gen/pacman/on_construction(mob/user)
	. = ..()
	var/obj/item/circuitboard/machine/pacman/our_board = circuit
	if(our_board?.high_production_profile)
		base_power_gen = 15 KILO JOULES
		base_max_sheets = 20
		base_time_per_sheet = 85
		time_per_sheet = 85
	// The parent may have swapped our fuel type, and Initialize() cached the name of the old one.
	var/obj/fuel = sheet_path
	sheet_name = initial(fuel.name)
	RefreshParts()

/// Capacitors set output, matter bins set fuel capacity, micro-lasers set fuel efficiency.
/obj/machinery/power/port_gen/pacman/RefreshParts()
	. = ..()
	// Fall back to a rating of one rather than zero, so a generator missing a part is weak, not dead.
	var/capacitor_rating = max(total_part_rating(/datum/stock_part/capacitor), 1)
	var/bin_rating = max(total_part_rating(/datum/stock_part/matter_bin), 1)
	var/laser_rating = max(total_part_rating(/datum/stock_part/micro_laser), 1)

	// Linear in capacitor tier: a tier-1 build matches stock tg's flat output exactly,
	// upgrades scale it up to 4x. (The old *2 doubled even an unupgraded build and
	// topped out at 8x tg's 40 kW ceiling.)
	power_gen = round(base_power_gen * capacitor_rating)
	max_sheets = base_max_sheets * bin_rating * bin_rating
	// Micro-lasers tune the burn chamber: every tier past stock stretches a sheet of fuel
	// 25% further (T1 100%, T2 125%, T3 150%, T4 175%). Their rating used to be summed
	// into `consumption`, which nothing in the codebase ever reads, so laser tier was the
	// one upgrade slot on a PACMAN that did nothing at all.
	time_per_sheet = round(base_time_per_sheet * (1 + (laser_rating - 1) * 0.25))

/obj/machinery/power/port_gen/pacman/examine(mob/user)
	. = ..()
	var/efficiency = round(time_per_sheet / max(base_time_per_sheet, 1) * 100)
	if(efficiency > 100)
		. += span_notice("Its micro-laser burn chamber is stretching every sheet of fuel to [efficiency]% of stock.")
	else
		. += span_notice("Its burn chamber is running a stock micro-laser; a better one would stretch its fuel further.")
