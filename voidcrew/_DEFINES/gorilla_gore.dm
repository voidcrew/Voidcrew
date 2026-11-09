// Gorilla Arms x hyperviolence (voidcrew/modules/hyperviolence_gorilla/). Balance notes for
// developers; none of these numbers go in player text. Unit tests can't see these (they compile
// before voidcrew/_DEFINES/), so tests use the literal values with a comment naming the define.

/// 32x32 pictures: knuckle sparks, piston pumps and heat, scuffs, the pry seam, snapped bones, dents,
/// the finisher masks.
#define GORILLA_GORE_ICON 'voidcrew/modules/hyperviolence_gorilla/icons/gorilla_gore.dmi'
/// 64x64 pictures drawn at -16,-16 on the floor tile in front of a wall: the wall impacts.
#define GORILLA_GORE_LARGE_ICON 'voidcrew/modules/hyperviolence_gorilla/icons/gorilla_gore_large.dmi'

/// Layer for sparks and flashes over the whole body.
#define GORILLA_ANIM_TOP_LAYER (-(HIGHEST_LAYER - 0.5))
/// Layer for the piston pump and heat over the worn arm plates: just above the plates (under suits).
#define GORILLA_ANIM_PLATE_LAYER (-(CYBERWARE_WORN_LAYER - 0.05))

// ---- The punch (gorilla_punch.dm) ----

/// Wound bonus on a Gorilla piston punch; the Brawler keeps its own.
#define GORILLA_PUNCH_WOUND_BONUS 15
/// Wound bonus on a Brawler punch.
#define BRAWLER_PUNCH_WOUND_BONUS 10
/// Brute after armour a punch must deal to strain the limb it hit.
#define GORILLA_STRAIN_MIN_DAMAGE 8
/// How long a limb holds strain after its last hit.
#define GORILLA_STRAIN_MEMORY (15 SECONDS)
/// Melee cover on a limb (after penetration) that stops a forced snap: #509's aorta scale.
#define GORILLA_SNAP_ARMOUR 40

// ---- Shared cooldowns, kept on the bearer (TIMER_COOLDOWN) so both arms share them ----

/// The haymaker and every finisher: the pistons are spent.
#define COOLDOWN_GORILLA_PISTONS "gorilla_pistons"
/// The hurl and the slam: one grab move at a time.
#define COOLDOWN_GORILLA_GRAB_MOVE "gorilla_grab_move"
/// The ground pound.
#define COOLDOWN_GORILLA_POUND "gorilla_pound"
/// The deploy flex (cosmetic).
#define COOLDOWN_GORILLA_FLEX "gorilla_flex"

#define GORILLA_PISTONS_COOLDOWN (20 SECONDS)
/// After a finisher that was called off before the kill.
#define GORILLA_PISTONS_INTERRUPTED (10 SECONDS)
/// After a haymaker held too long and vented.
#define GORILLA_PISTONS_VENTED (5 SECONDS)
#define GORILLA_GRAB_MOVE_COOLDOWN (10 SECONDS)
#define GORILLA_POUND_COOLDOWN (45 SECONDS)
#define GORILLA_FLEX_COOLDOWN (10 SECONDS)

// ---- The haymaker (gorilla_haymaker.dm) ----

#define GORILLA_HAYMAKER_MIN_CHARGE (0.8 SECONDS)
#define GORILLA_HAYMAKER_FULL_CHARGE (1.5 SECONDS)
/// Held this long, the pistons vent and the charge is lost.
#define GORILLA_HAYMAKER_VENT_AFTER (3 SECONDS)
/// A press of Use chrome shorter than this is a tap: the charge waits for a click.
#define GORILLA_HAYMAKER_TAP (0.3 SECONDS)
#define GORILLA_HAYMAKER_MIN_DAMAGE 20
#define GORILLA_HAYMAKER_MAX_DAMAGE 30
#define GORILLA_HAYMAKER_MIN_RANGE 3
#define GORILLA_HAYMAKER_MAX_RANGE 4
#define GORILLA_HAYMAKER_SPEED 3
/// Extra brute when a haymaker's body hits a wall.
#define GORILLA_HAYMAKER_WALL_DAMAGE 10

// ---- Grab and slam ----

#define GORILLA_SLAM_FLOOR_DAMAGE 25
#define GORILLA_SLAM_FLOOR_STAMINA 30
#define GORILLA_SLAM_TABLE_DAMAGE 30
#define GORILLA_SLAM_TABLE_STAMINA 40
#define GORILLA_SLAM_KNOCKDOWN (2 SECONDS)
#define GORILLA_SLAM_TABLE_BREAK 50
/// What a click while grabbing turned into (gorilla_arms/proc/try_slam()). Not a slam: carry on with the punch.
#define GORILLA_SLAM_NO 0
/// A slam was done.
#define GORILLA_SLAM_DONE 1
/// A slam onto a table that can't happen now: leave the click to tg's own table smash.
#define GORILLA_SLAM_PASS 2

// ---- Throws (gorilla_throw.dm) ----

/// What stopped a planned knockback short of its full reach.
#define GORILLA_THROW_CLEAR 0
/// A wall: the body hits it.
#define GORILLA_THROW_WALL 1
/// A mob standing in the way: the body hits it.
#define GORILLA_THROW_MOB 2
/// Glass, a door, a railing, a hazard or no gravity: the body stops short and hits nothing.
#define GORILLA_THROW_SHORT 3
/// Most decals a Gorilla throw leaves along its path.
#define GORILLA_TRAIL_MAX 4
/// Most blood drops and splats one tile of a bleeding body's skid gets.
#define GORILLA_SKID_SPLATS 4

// What a wall impact draws, by the injury it caused (owner D38).
/// No skin broken: a dent and chips.
#define GORILLA_SPLAT_DENT 1
/// Skin broken, moderate: a half-moon on the floor and a thin smear on the wall's edge.
#define GORILLA_SPLAT_EDGE 2
/// Severe bleeding or a torn artery: a spray up the wall and runs.
#define GORILLA_SPLAT_SPRAY 3

// ---- Ground pound ----

#define GORILLA_POUND_CROUCH (0.45 SECONDS)
/// How long the fists take from overhead to the floor
#define GORILLA_POUND_DRIVE (0.08 SECONDS)
/// How long the bearer takes to stand back up after a ground pound
#define GORILLA_POUND_RISE (0.3 SECONDS)
#define GORILLA_POUND_STAMINA 20
#define GORILLA_POUND_DAZE (3 SECONDS)
/// Loose items this far from the pound hop a tile outward.
#define GORILLA_POUND_ITEM_REACH 2

// ---- Finishers (gorilla_finisher.dm) ----

/// Damage on the bearer that makes them let go.
#define GORILLA_FINISHER_INTERRUPT 10
/// Melee cover on the head that turns the head clap's burst into a crumpled helmet: #509's skull gate.
#define GORILLA_CLAP_HELMET_ARMOUR 30
/// Melee cover on an arm that turns the limb rip into a dislocation.
#define GORILLA_RIP_ARMOUR 40
/// The limb rip's look. Pixels the bearer steps in toward the body, and degrees he leans back from his feet as he
/// hauls (seen from the side).
#define GORILLA_RIP_LEAN 5
#define GORILLA_RIP_LEAN_BACK 12
/// How far his piston arms push out to take the wrist, as a share of their length. They hold it there as he hauls.
#define GORILLA_RIP_REACH 1.7
/// The hauled arm, as a share of its length: the most it stretches to meet his fists, how much further the haul
/// pulls it, and the most it ever stretches.
#define GORILLA_RIP_MAX_STRETCH 1.8
#define GORILLA_RIP_HAUL 0.35
#define GORILLA_RIP_MAX_HAUL 2.1
/// Seen from the side, degrees the arm comes up off the floor into his fists.
#define GORILLA_RIP_TILT 30
/// The haul's steps, and the pixels the body comes up off the floor with the arm.
#define GORILLA_RIP_HAUL_STEPS 6
#define GORILLA_RIP_LIFT 3
/// Melee cover on the chest that turns the broken back into cracked ribs.
#define GORILLA_BACK_ARMOUR 40
/// How long a broken back's fold stays drawn after the finisher.
#define GORILLA_FOLD_TIME (10 SECONDS)
/// The head clap's burst: one short line of blood this many tiles long.
#define GORILLA_CLAP_SPRAY_TILES 2
/// How far the head clap throws the brain (the eyes, ears and tongue drop on the spot or a tile out).
#define GORILLA_CLAP_BRAIN_MIN 1
#define GORILLA_CLAP_BRAIN_MAX 2
/// The head clap's look. How far the held body is brought in toward the bearer (a share of a tile) and how many pixels
/// up it is held until the burst, seen from the side, the front and the back: close enough for his fists to close on its head.
#define GORILLA_CLAP_HOLD_SIDE 0.875
#define GORILLA_CLAP_HOLD_FRONT 0.7
#define GORILLA_CLAP_HOLD_BACK 0.85
#define GORILLA_CLAP_LIFT_SIDE 4
#define GORILLA_CLAP_LIFT_FRONT 15
#define GORILLA_CLAP_LIFT_BACK 6
/// The most his piston arms push out to reach the head, as a share of their length, and the pixels they come off it before the clap.
#define GORILLA_CLAP_MAX_REACH 2.1
#define GORILLA_CLAP_WIND 3
/// How long the burst body takes to fall from where it was held.
#define GORILLA_CLAP_DROP_TIME (0.2 SECONDS)
/// The limb rip's blow with the torn arm: up over his head, then down on theirs. The hit lands as it comes down.
#define GORILLA_CLUB_RAISE (0.2 SECONDS)
#define GORILLA_CLUB_STRIKE (0.1 SECONDS)
/// How long before the arm is all the way down the blow lands (recorded 0 to 0.12 s late without it).
#define GORILLA_CLUB_HIT_LEAD (0.05 SECONDS)
/// How far his arms push out on that blow, and the most the torn arm in his fists stretches to reach, as shares of their length.
#define GORILLA_CLUB_REACH 1.6
#define GORILLA_CLUB_MAX_STRETCH 1.5
/// Pixels toward the viewer a backbroken body lies on the bearer's tile, so he doesn't hide it, and the offset's source.
#define GORILLA_BACK_IN_FRONT 10
#define GORILLA_LAID_IN_FRONT_OFFSET "gorilla_laid_in_front"
/// How long a broken back stays folded over the knee before it is rolled off.
#define GORILLA_BACK_FOLD_HOLD (0.3 SECONDS)

// The landed piston punch, the haymaker's hit and the backbreaker's break (gorilla_punch.dm's sound procs).
/// A sound key (/datum/sound_effect/gorilla_piston_punch): one of three punches at random.
#define GORILLA_PUNCH_SOUND "gorilla_piston_punch"
#define GORILLA_HAYMAKER_SOUND 'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_haymaker.ogg'
#define GORILLA_BACKBREAKER_SOUND 'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_backbreaker.ogg'

/// Filter sources.
#define GORILLA_PUPPET_HIDE "gorilla_puppet_hide"
