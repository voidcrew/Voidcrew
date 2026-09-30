// # Bounty lairs: numbers
//
// Owner: P10 lairs (framework and lich) and P12 mafia mobs, each in its own marked section.
// Placeholders until balance/lairs.md lands.

// ===== P10 =====
// Kill-only postings, lair sites, the lair clock and the lich kill bounty
// (voidcrew/modules/bounties/bounty_lair.dm). Spec 14.1-14.3, balance/lairs.md sections 8 and 10.
// Unit tests compile before this file: a test uses the literal value with the define named beside it.

/// close() reason (beside the shared BOUNTY_CLOSE_*): the lair or the event a kill-only bounty pointed at went away before the kill was turned in
#define BOUNTY_CLOSE_LAIR_GONE "lair_gone"
/// The id a lair's gate poddoors are mapped with. They open when the lair's last gatekeeper dies.
#define BOUNTY_LAIR_GATE_ID "bounty_lair_gate"
/// Sent on the lich lair (/obj/structure/overmap/space_ruin/lich_lair) when Ilthuun dies: (mob/living/slain)
#define COMSIG_BOUNTY_LICH_SLAIN "bounty_lich_slain"

// ----- When lairs are posted -----

/// How often the lair clock (SSbounty_lairs) looks at the board
#define BOUNTY_LAIR_TICK (1 MINUTES)
/// The first lair of a kind comes this long into the round, plus up to BOUNTY_LAIR_FIRST_SPREAD
#define BOUNTY_LAIR_FIRST_AFTER (45 MINUTES)
#define BOUNTY_LAIR_FIRST_SPREAD (15 MINUTES)
/// Active crewed player ships needed before a lair is posted
#define BOUNTY_LAIR_MIN_SHIPS 3
/// After a lair's bounty closes, the next of that kind waits this long (a random time between the two)
#define BOUNTY_LAIR_GAP_MIN (60 MINUTES)
#define BOUNTY_LAIR_GAP_MAX (90 MINUTES)
/// When a lair could not be placed, how soon the clock tries again
#define BOUNTY_LAIR_RETRY (5 MINUTES)
/// How long a lair's bounty stays up. The clock waits while any ship hunts it or anyone is inside the lair.
#define BOUNTY_LAIR_EXPIRY (60 MINUTES)
/// Tries at a free overmap square in the lair's zone band (the red band is small)
#define BOUNTY_LAIR_OVERMAP_TRIES 80
/// Zone band weights for a lair: always yellow or red (spec 14.4)
#define BOUNTY_LAIR_WEIGHT_YELLOW 2
#define BOUNTY_LAIR_WEIGHT_RED 1

// ----- Pay (balance/lairs.md section 8) -----

/// The mafia club's base credits, before the zone multiplier; all of it is paid on the trophy
#define BOUNTY_PAY_LAIR_MIN 4800
#define BOUNTY_PAY_LAIR_MAX 5600
/// The mafia club's trade vouchers; red space adds BOUNTY_RED_VOUCHER_BONUS
#define BOUNTY_VOUCHERS_LAIR 3
/// The lich pays the Most Wanted band times this (spec 14.3), plus the Most Wanted vouchers
#define BOUNTY_LICH_PAY_MULT 1.5
/// The lich's bounty clock holds while he lives; once he is dead it runs this long
#define BOUNTY_LICH_EXPIRY_AFTER_KILL (45 MINUTES)

// ----- Inside a lair -----

/// After a lair boss falls, how long to wait for its next phase (the don out of his mech) before the trophy drops
#define BOUNTY_LAIR_TROPHY_GRACE (5 SECONDS)
/// Tiles the trophy's flood fill looks through for a safe floor, from where the boss fell, before giving up
#define BOUNTY_LAIR_TROPHY_SEARCH 60
/// A second pass that keeps the goons in their rooms, once every zone_mobs marker has had time to spawn (its resolver retries for up to a minute)
#define BOUNTY_LAIR_GOON_LEASH_DELAY (65 SECONDS)

// ===== P12 =====
// The mafia club's people (bounty_lair_mafia.dm): balance/lairs.md sections 3-5 and 10, spec section 15.
// Unit tests can't see these; they use the literal values with the define named in a comment.

/// The faction every club mob shares: goons, lieutenants, the mech and the don
#define BOUNTY_MAFIA_FACTION "bounty_mafia"
/// The club's dialogue, loaded from BOUNTY_MAFIA_STRINGS_DIR
#define BOUNTY_MAFIA_STRINGS_FILE "bounty_lair_mafia.json"
#define BOUNTY_MAFIA_STRINGS_DIR "voidcrew/modules/bounties/strings"
/// Shortest gap between two lines from one mob, unless a line is forced
#define BOUNTY_MAFIA_BARK_COOLDOWN (12 SECONDS)
/// Chance a second, per mob, that an idle goon says something while players are about
#define BOUNTY_MAFIA_IDLE_BARK_CHANCE 1

/// Sent on the mech as the don climbs out, before the mech's death: (mob/living/basic/bounty_lair_boss/mafia_don/don)
#define COMSIG_BOUNTY_MAFIA_DON_EJECTED "bounty_mafia_don_ejected"
/// Sent on the don when his trophy drops: (obj/item/bounty_proof/trophy/mafia_don/trophy)
#define COMSIG_BOUNTY_MAFIA_TROPHY_DROPPED "bounty_mafia_trophy_dropped"

/// Blackboard key: a turf a club mob is walking to (its room, or cover behind the wreck)
#define BB_BOUNTY_MAFIA_MOVE_TO "BB_bounty_mafia_move_to"

// ----- mobsters -----
// Every blow and round is the real item's in their hand (bounty_real_weapon()): its look, damage and magazine.

#define BOUNTY_MOBSTER_KNIFE /obj/item/knife/kitchen
#define BOUNTY_MOBSTER_KNIFE_HEALTH 120
#define BOUNTY_MOBSTER_KNIFE_COOLDOWN (0.8 SECONDS)
#define BOUNTY_MOBSTER_KNIFE_SPEED 1.2

#define BOUNTY_MOBSTER_PISTOL_GUN /obj/item/gun/ballistic/automatic/pistol/aps
#define BOUNTY_MOBSTER_PISTOL_HEALTH 120
/// A pistol fires this many shots each time it fires, this far apart; a goon only decides to shoot every half second
#define BOUNTY_MOBSTER_PISTOL_BURST 2
#define BOUNTY_MOBSTER_PISTOL_BURST_GAP (0.25 SECONDS)
#define BOUNTY_MOBSTER_PISTOL_COOLDOWN (0.5 SECONDS)
#define BOUNTY_MOBSTER_PISTOL_RELOAD (2 SECONDS)
#define BOUNTY_MOBSTER_PISTOL_SPEED 1.4

#define BOUNTY_MOBSTER_SMG_GUN /obj/item/gun/ballistic/automatic/mini_uzi
#define BOUNTY_MOBSTER_SMG_HEALTH 150
#define BOUNTY_MOBSTER_SMG_BURST 5
#define BOUNTY_MOBSTER_SMG_BURST_GAP (0.1 SECONDS)
#define BOUNTY_MOBSTER_SMG_WINDUP (0.3 SECONDS)
#define BOUNTY_MOBSTER_SMG_COOLDOWN (1 SECONDS)
#define BOUNTY_MOBSTER_SMG_RELOAD (2.5 SECONDS)
#define BOUNTY_MOBSTER_SMG_SPEED 1.4

/// The shout before a room's first shot
#define BOUNTY_MOBSTER_ALERT (0.5 SECONDS)
/// The rest of the room's first shots spread over this after the shout
#define BOUNTY_MOBSTER_FIRST_SHOT_SPREAD (0.5 SECONDS)
/// A goon hit while bringing a spun-up gun to bear loses this long
#define BOUNTY_MOBSTER_FUMBLE (1 SECONDS)
/// Goons of one room that may go after one hunter standing in a doorway
#define BOUNTY_MOBSTER_MAX_ON_ONE 2
/// How far a goon sees and shoots
#define BOUNTY_MOBSTER_SIGHT 9
/// How far a goon keeps after a hunter it can't see any more (inside its own room)
#define BOUNTY_MOBSTER_CHASE 12
/// Out of its room with nobody to fight and unable to walk back this long (another leash holds it), it takes the room it's in
#define BOUNTY_MOBSTER_ROOM_GIVE_UP (20 SECONDS)
/// A room bigger than this many tiles isn't searched for its doors (a goon spawned somewhere odd)
#define BOUNTY_MOBSTER_ROOM_MAX_TILES 400

// ----- lieutenants -----

#define BOUNTY_LIEUTENANT_TOMMY_GUN /obj/item/gun/ballistic/automatic/tommygun
#define BOUNTY_LIEUTENANT_TOMMY_HEALTH 350
#define BOUNTY_LIEUTENANT_TOMMY_BURST 6
#define BOUNTY_LIEUTENANT_TOMMY_BURST_GAP (0.1 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_WINDUP (0.3 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_COOLDOWN (1 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_RELOAD (3 SECONDS)
#define BOUNTY_LIEUTENANT_TOMMY_SPEED 1.4

/// Brute fights with his fists: a human's punch
#define BOUNTY_LIEUTENANT_BRUTE_HEALTH 400
#define BOUNTY_LIEUTENANT_BRUTE_COOLDOWN (1 SECONDS)
/// Percent chance a blow knocks the hunter down
#define BOUNTY_LIEUTENANT_BRUTE_KNOCKDOWN_CHANCE 25
#define BOUNTY_LIEUTENANT_BRUTE_KNOCKDOWN (1 SECONDS)
#define BOUNTY_LIEUTENANT_BRUTE_SPEED 1.2

/// Both lieutenants take this much of any brute or burn damage
#define BOUNTY_LIEUTENANT_DAMAGE_MOD 0.8

/// The lieutenants' names for the role var
#define BOUNTY_LIEUTENANT_TOMMY "tommy"
#define BOUNTY_LIEUTENANT_BRUTE "brute"

// ----- the don's mech -----

#define BOUNTY_MECH_HEALTH_1 350
#define BOUNTY_MECH_HEALTH_2 700
#define BOUNTY_MECH_HEALTH_3 1050
#define BOUNTY_MECH_HEALTH_4 1400
#define BOUNTY_MECH_BRUTE_MOD 0.6
#define BOUNTY_MECH_BURN_MOD 0.8
#define BOUNTY_MECH_SPEED 2
/// How far it sees hunters and aims its guns: the garage and the back office behind its gate (about 21 tiles deep)
#define BOUNTY_MECH_SIGHT 20
/// How far it keeps after someone who has hurt it, seen or not: it closes in as far as its arena lets it
#define BOUNTY_MECH_GRUDGE_RANGE 30

#define BOUNTY_MECH_STOMP_DAMAGE_MIN 28
#define BOUNTY_MECH_STOMP_DAMAGE_MAX 36
#define BOUNTY_MECH_STOMP_AP 10
#define BOUNTY_MECH_STOMP_COOLDOWN (1.2 SECONDS)
/// A stomp throws them this many tiles straight back, at this throw speed
#define BOUNTY_MECH_STOMP_THROW 3
#define BOUNTY_MECH_STOMP_THROW_SPEED 2

/// The lock-on: a marker under each hunter it can see, then one rocket per marker
#define BOUNTY_MECH_ROCKET_LOCK (0.8 SECONDS)
#define BOUNTY_MECH_ROCKET_DAMAGE 70
#define BOUNTY_MECH_ROCKET_KNOCKDOWN (1 SECONDS)
#define BOUNTY_MECH_ROCKET_COOLDOWN (9 SECONDS)
/// Damage a rocket does to a table, window or door it hits in the arena, as a multiple of its damage
#define BOUNTY_MECH_ROCKET_DEMOLITION 8
/// What a rocket does to a player's exosuit in its way, against its bullet armour: never the anti-furniture multiplier
#define BOUNTY_MECH_ROCKET_EXOSUIT_DAMAGE 90

/// The exosuit gun on its arm: its rounds are this gun's (bounty_real_weapon())
#define BOUNTY_MECH_LMG_GUN /obj/item/mecha_parts/mecha_equipment/weapon/ballistic/lmg
#define BOUNTY_MECH_LMG_WINDUP (0.6 SECONDS)
#define BOUNTY_MECH_LMG_ROUNDS 12
/// The 12 rounds go out over this long
#define BOUNTY_MECH_LMG_FIRE_TIME (1.5 SECONDS)
#define BOUNTY_MECH_LMG_COOLDOWN (5 SECONDS)
/// Full width of the red cone, in degrees; the rounds spread over it
#define BOUNTY_MECH_LMG_ARC 30
/// The cone's shortest reach; it always reaches as far as its target, and no round flies past it
#define BOUNTY_MECH_LMG_RANGE 8
#define BOUNTY_MECH_LMG_DEMOLITION 0.25

/// Between the end of one ability and the start of the next
#define BOUNTY_MECH_ABILITY_GAP (1.2 SECONDS)

/// An EMP stalls it this long and takes this percent of its max health; never tg's full-health hit on a robot
#define BOUNTY_MECH_EMP_STALL (2 SECONDS)
#define BOUNTY_MECH_EMP_DAMAGE_PERCENT 5
/// After a stall it shrugs off further EMPs this long, so an ion gun can't hold it still
#define BOUNTY_MECH_EMP_IMMUNITY (3 SECONDS)

/// With no hunter in the arena, seen, or shooting at it this long, it resets to full health and a fresh posse
#define BOUNTY_MECH_RESET_AFTER (60 SECONDS)

// ----- the don on foot -----

/// His name when his posting's record gives none: the name P10's card shows for Club Volga
#define BOUNTY_DON_NAME "Arkady Sokolov"
/// His gold pistol: its look, its rounds and its magazine (bounty_real_weapon()); he fires strings of BOUNTY_MOBSTER_PISTOL_BURST as a goon does
#define BOUNTY_DON_GUN /obj/item/gun/ballistic/automatic/pistol/deagle/gold
#define BOUNTY_DON_HEALTH 250
#define BOUNTY_DON_COOLDOWN (0.5 SECONDS)
#define BOUNTY_DON_RELOAD (2 SECONDS)
/// He raises the pistol this long before each string of shots
#define BOUNTY_DON_RAISE (0.2 SECONDS)
#define BOUNTY_DON_SPEED 1.4
#define BOUNTY_DON_EJECT_STAGGER (2 SECONDS)
