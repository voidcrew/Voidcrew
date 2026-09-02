///Turns the dir by 180 degrees
#define DIRFLIP(d) turn(d, 180)

/**
 * Fixture NPCs - outpost traders, outpost loiterers, vestige patrons - refuse to be put
 * inside anything: lockers, crates, body bags, bluespace body bags, roller beds.
 *
 * They already cancel COMSIG_MOUSEDROP_ONTO and carry move_resist = INFINITY, but a
 * closet does not take a mob aboard through either of those. close() runs take_contents()
 * over everything standing on the closet's own tile, and a body bag is density = FALSE,
 * so it can be pulled onto a shopkeep's tile and simply zipped shut (issue #131).
 * Honoured in /obj/structure/closet/insertion_allowed (voidcrew/edits/objects/structures/
 * closet_containment.dm), which is the single gate every container path runs through.
 */
#define TRAIT_NO_CONTAINMENT "no_containment"
