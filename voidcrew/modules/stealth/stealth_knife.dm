/**
 * # The matte combat knife (step 3a, owner decisions 5 and 12)
 *
 * tg's combat knife with a blackened blade. Its one difference: struck into a stealth guard from behind (tg's
 * check_behind(), the heretic blade's backstab test), it adds STEALTH_BACKSTAB_BONUS to the aimed crit roll
 * (stealth_crits.dm). On anyone else, players included, it is a plain combat knife. No new attack or animation.
 *
 * Players get it as scav den loot (step 4). It has no buy, print or craft route.
 */
/obj/item/knife/combat/matte
	name = "matte combat knife"
	desc = "A combat knife with a blackened blade that doesn't catch the light."
	color = "#6E6E7D"
