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
/// A powered airlock forced by the synced Gorilla pair.
#define GORILLA_PRY_TIME (4 SECONDS)

// ---- The haymaker (gorilla_haymaker.dm) ----

#define GORILLA_HAYMAKER_MIN_CHARGE (0.8 SECONDS)
#define GORILLA_HAYMAKER_FULL_CHARGE (1.5 SECONDS)
/// Held this long, the pistons vent and the charge is lost.
#define GORILLA_HAYMAKER_VENT_AFTER (3 SECONDS)
/// A press of Use chrome shorter than this is a tap: the charge waits for a click.
#define GORILLA_HAYMAKER_TAP (0.3 SECONDS)
/// Pixels the bearer leans back at full charge, seen from the side. The lean builds to it over the wind-up.
#define GORILLA_HAYMAKER_LEAN 4
#define GORILLA_HAYMAKER_MIN_DAMAGE 20
#define GORILLA_HAYMAKER_MAX_DAMAGE 30
#define GORILLA_HAYMAKER_MIN_RANGE 3
#define GORILLA_HAYMAKER_MAX_RANGE 4
#define GORILLA_HAYMAKER_SPEED 3
/// The real body stays on show this long as the wind-up's puppets come up (chrome_rig/conceal_after()).
#define GORILLA_HAYMAKER_RIG_HOLD (0.04 SECONDS)
/// The punching arm is half drawn back this far into the wind-up...
#define GORILLA_HAYMAKER_DRAW (0.4 SECONDS)
/// ...and all the way back by this, a throw's length before the earliest blow.
#define GORILLA_HAYMAKER_DRAWN (0.75 SECONDS)
/// The throw: the blow lands as it ends. One server tick, so the sparks come up on the frame the fist arrives.
#define GORILLA_HAYMAKER_THROW (0.05 SECONDS)
/// The fist stays on what it hit for a beat, so the blow's sparks find it there...
#define GORILLA_HAYMAKER_DWELL (0.05 SECONDS)
/// ...carries on past it...
#define GORILLA_HAYMAKER_FOLLOW (0.15 SECONDS)
/// ...and the arms come back to rest.
#define GORILLA_HAYMAKER_RETURN (0.3 SECONDS)
/// A wind-up held too long or called off: the arms come down.
#define GORILLA_HAYMAKER_LOWER (0.25 SECONDS)
/// Pixels the body steps in behind the throw: as few as put the fist on the body.
#define GORILLA_HAYMAKER_STEP_MIN 12
#define GORILLA_HAYMAKER_STEP_MAX 16

// ---- The punching arm (gorilla_swing.dm, gorilla_thrust.dm) ----

/// The pace of one beat of a swing: even, fast then settling, or eased in and out.
#define CHROME_SWING_LINEAR 0
#define CHROME_SWING_EASE_OUT 1
#define CHROME_SWING_EASE_IN_OUT 2

/// A piston punch: the fist draws back...
#define GORILLA_THRUST_BACK (0.04 SECONDS)
/// ...and the piston drives it out. The blow lands as this ends.
#define GORILLA_THRUST_OUT (0.06 SECONDS)
/// The arm comes back to rest.
#define GORILLA_THRUST_REST (0.2 SECONDS)
/// The first time an arm's picture is shown it may still be on its way to a client: the punch waits this long first, the real arm on show.
#define GORILLA_THRUST_HOLD (0.05 SECONDS)
/// Pixels the body lunges behind a piston punch: tg's lunge at the least, further when the fist would stop short.
#define GORILLA_THRUST_LUNGE_MIN 8
#define GORILLA_THRUST_LUNGE_MAX 16
/// Degrees the body tips into a piston punch, as tg's lunge tips it.
#define GORILLA_THRUST_TIP 15
/// How long a punching arm is drawn, as a share of its own length: the body steps in until the fist lands with the arm no longer than the first, and the arm is never drawn longer than the second.
#define GORILLA_SWING_EASY_LENGTH 1.9
#define GORILLA_SWING_MAX_LENGTH 2.3
/// The most pixels a body steps in behind a fist thrown up or down the screen: further, and it stands on whoever it hits.
#define GORILLA_SWING_STEP_UPRIGHT 12
/// Pixels from the middle of a stretched fist to its knuckles: it stops this far short of the body it lands on.
#define GORILLA_FIST_KNUCKLES 2.5

// ---- Grab and slam ----

#define GORILLA_SLAM_FLOOR_DAMAGE 25
#define GORILLA_SLAM_FLOOR_STAMINA 30
#define GORILLA_SLAM_TABLE_DAMAGE 30
#define GORILLA_SLAM_TABLE_STAMINA 40
#define GORILLA_SLAM_KNOCKDOWN (2 SECONDS)
#define GORILLA_SLAM_TABLE_BREAK 50
// The slam's beats (gorilla_slam.dm), each a whole number of GORILLA_SLAM_STEPs. From the click: the grip, the hoist, the held
// beat at the top and the drive down, then the impact. Gorilla Arms: 0.44 s to the impact and 0.70 s in all.
#define GORILLA_SLAM_GRIP_TIME (0.08 SECONDS)
#define GORILLA_SLAM_HOIST_TIME (0.2 SECONDS)
#define GORILLA_SLAM_TOP_TIME (0.06 SECONDS)
#define GORILLA_SLAM_DRIVE_TIME (0.1 SECONDS)
/// After the impact: how long the body takes to come to rest, the bearer to stand back up, and the puppets to go.
#define GORILLA_SLAM_REBOUND_TIME (0.12 SECONDS)
#define GORILLA_SLAM_RISE_TIME (0.18 SECONDS)
#define GORILLA_SLAM_SETTLE_TIME (0.26 SECONDS)
/// How long a body takes to come down on its feet when the slam is called off.
#define GORILLA_SLAM_SET_DOWN_TIME (0.15 SECONDS)
/// The length of one straight step of the slam's puppets, and of the swap between the bearer's two rigs when he turns.
#define GORILLA_SLAM_STEP (0.02 SECONDS)
#define GORILLA_SLAM_SWAP (0.01 SECONDS)
/// The most and the least his piston arms are drawn to keep a fist on the body, as shares of their length.
#define GORILLA_SLAM_MAX_REACH 2.2
#define GORILLA_SLAM_MIN_REACH 0.4
/// Where the middle of the body is at the top of the lift, in pixels from the bearer: in front of him and up, seen from the
/// side; aside and up, seen from the front or back. Gorilla Arms press it overhead, flat.
#define GORILLA_SLAM_TOP_SIDE_X 4
#define GORILLA_SLAM_TOP_SIDE_Y 22
#define GORILLA_SLAM_TOP_FRONT_X 3
#define GORILLA_SLAM_TOP_FRONT_Y 28
/// Seen from behind, the floor in front of him is up the screen too, about where a body held overhead is drawn. So he goes
/// up on his toes at the top and holds it this high, and it has somewhere to come down from.
#define GORILLA_SLAM_TOP_BACK_Y 34
#define GORILLA_SLAM_TOP_BACK_RISE 4
/// How far up tg draws a body lying on a table.
#define GORILLA_SLAM_TABLE_TOP 12
/// Pixels a slammed body bounces off what it lands on, and the degrees it tips as it does.
#define GORILLA_SLAM_BOUNCE 4
#define GORILLA_SLAM_BOUNCE_TIP 6
/// Drops of blood thrown out round a body the slam cut open: the fewest and the most, and how far from it they land.
#define GORILLA_SLAM_DROPS_MIN 5
#define GORILLA_SLAM_DROPS_MAX 7
#define GORILLA_SLAM_DROPS_NEAR 9
#define GORILLA_SLAM_DROPS_FAR 19
/// What holds the bearer where he stands for the slam.
#define GORILLA_SLAM_TRAIT "gorilla_slam"

// ---- Brawler myomers (ware_line_models_a.dm): the street slam, pound, smash and pry ----

#define BRAWLER_SLAM_FLOOR_DAMAGE 18
#define BRAWLER_SLAM_FLOOR_STAMINA 20
#define BRAWLER_SLAM_TABLE_DAMAGE 22
#define BRAWLER_SLAM_TABLE_STAMINA 30
#define BRAWLER_SLAM_KNOCKDOWN (1 SECONDS)
#define BRAWLER_SLAM_TABLE_BREAK 30
/// The Brawler's shorter haul: 0.40 s to the impact. It brings the body to the shoulder, tipped back and not yet flat.
#define BRAWLER_SLAM_HOIST_TIME (0.16 SECONDS)
#define BRAWLER_SLAM_TOP_SIDE_X 11
#define BRAWLER_SLAM_TOP_SIDE_Y 13
#define BRAWLER_SLAM_TOP_FRONT_X 2
#define BRAWLER_SLAM_TOP_FRONT_Y 18
#define BRAWLER_SLAM_TOP_TURN 62
#define BRAWLER_SLAM_BOUNCE 2
#define BRAWLER_GRAB_MOVE_COOLDOWN (15 SECONDS)
/// Damage per structure smash: over a plain airlock's deflection (21) and a reinforced one's (30).
#define BRAWLER_STRUCTURE_DAMAGE 32
/// A powered airlock forced by the synced pair. The Gorilla takes GORILLA_PRY_TIME.
#define BRAWLER_PRY_TIME (7 SECONDS)
#define BRAWLER_POUND_COOLDOWN (60 SECONDS)
#define BRAWLER_POUND_STAGGER (6 SECONDS)
#define BRAWLER_POUND_STAMINA 10
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

// How hard a Gorilla throw meets a wall (owner D48). The crash goes through tg's damage and wound rolls.
/// The one-tile shove off a punch (both lines): a dent, no damage, no knockdown.
#define GORILLA_IMPACT_SHOVE 1
/// The grab hurl.
#define GORILLA_IMPACT_HURL 2
/// The haymaker.
#define GORILLA_IMPACT_HAYMAKER 3
/// A hurl's blunt hit on the part that meets the wall, and its wound bonus.
#define GORILLA_WALL_HURL_BLUNT 6
#define GORILLA_WALL_HURL_BLUNT_WOUND 15
/// A hurl's split skin on the wall's edge (a slash roll), and its wound bonus.
#define GORILLA_WALL_HURL_EDGE 6
#define GORILLA_WALL_HURL_EDGE_WOUND 5
/// A haymaker's blunt hit and its wound bonus.
#define GORILLA_WALL_HAYMAKER_BLUNT 16
#define GORILLA_WALL_HAYMAKER_BLUNT_WOUND 25
/// A haymaker's split skin and its wound bonus.
#define GORILLA_WALL_HAYMAKER_EDGE 8
#define GORILLA_WALL_HAYMAKER_EDGE_WOUND 15
/// A part already beaten adds a point of wound bonus per this much brute on it...
#define GORILLA_WALL_HURT_PER_POINT 4
/// ...up to this many.
#define GORILLA_WALL_HURT_MAX 15
/// The knockdown of a hard crash, as tg's own wall crash.
#define GORILLA_WALL_KNOCKDOWN (2 SECONDS)

// ---- Ground pound ----

#define GORILLA_POUND_CROUCH (0.45 SECONDS)
/// How long the fists take from overhead to the floor
#define GORILLA_POUND_DRIVE (0.08 SECONDS)
/// How long the bearer takes to stand back up after a ground pound
#define GORILLA_POUND_RISE (0.3 SECONDS)
#define GORILLA_POUND_STAMINA 20
/// The longest stagger a pound leaves.
#define GORILLA_POUND_STAGGER (10 SECONDS)
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
/// How long a broken back's fold stays drawn after the finisher, and how long it then takes to ease out flat.
#define GORILLA_FOLD_TIME (10 SECONDS)
#define GORILLA_FOLD_SETTLE (0.6 SECONDS)
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
#define GORILLA_CLAP_LIFT_SIDE 1
#define GORILLA_CLAP_LIFT_FRONT 15
#define GORILLA_CLAP_LIFT_BACK 3
/// The most his piston arms push out to reach the head, as a share of their length, and the pixels they come off it before the clap.
#define GORILLA_CLAP_MAX_REACH 2.1
#define GORILLA_CLAP_WIND 3
/// How long the burst body takes to fall from where it was held.
#define GORILLA_CLAP_DROP_TIME (0.2 SECONDS)
/// The head clap's hold: the fists work the head and the body hangs from it, so it goes wherever they take it. Pixels they shake
/// it side to side and lift it in the squeeze, lift it on for the toss, and drive it back down on the clap. Cut back wherever his
/// arms couldn't stay on the head.
#define GORILLA_CLAP_SHAKE 3
#define GORILLA_CLAP_HEAVE 2
#define GORILLA_CLAP_TOSS_LIFT 2
#define GORILLA_CLAP_SLAM 2
/// Degrees the hanging body swings behind its head for each pixel the head is shaken aside, and the most it swings.
#define GORILLA_CLAP_SWAY 2.5
#define GORILLA_CLAP_MAX_SWAY 7
/// The limb rip's haul: the most degrees the body turns up about its feet toward his fists as the arm is pulled, and how long
/// it takes to fall back flat when the arm gives.
#define GORILLA_RIP_RAISE 22
#define GORILLA_RIP_FALL_TIME (0.25 SECONDS)
/// How long the let-go body takes to slide back to where tg lays it (tg's own offset slide).
#define GORILLA_RIP_LET_GO (0.2 SECONDS)
/// How long nothing moves at the start of the plant, while the puppets' pictures reach the client. The plant's own
/// 0.3 s still ends inside its stage.
#define GORILLA_RIP_START_HOLD (0.15 SECONDS)
/// Seen from behind, how long the torn arm takes to come down with his fist and hang beside him.
#define GORILLA_RIP_HANG_TIME (0.25 SECONDS)
/// The limb rip's blood: how many drops burst from the socket as the arm comes away, and the furthest (pixels) the pool
/// under the shoulder is laid from the middle of the body's tile.
#define GORILLA_RIP_BURST_DROPS 12
#define GORILLA_RIP_POOL_REACH 10
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
/// The shove off the knee onto the tile ahead: how long the body is in the air, and how many pixels it rises on the way.
#define GORILLA_BACK_SHOVE_TIME (0.45 SECONDS)
#define GORILLA_BACK_SHOVE_RISE 6
/// How long the bearer's arms take to push out after it.
#define GORILLA_BACK_SHOVE_PUSH (0.12 SECONDS)

// The landed piston punch, the haymaker's hit and the backbreaker's break (gorilla_punch.dm's sound procs).
/// A sound key (/datum/sound_effect/gorilla_piston_punch): one of three punches at random.
#define GORILLA_PUNCH_SOUND "gorilla_piston_punch"
#define GORILLA_HAYMAKER_SOUND 'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_haymaker.ogg'
#define GORILLA_BACKBREAKER_SOUND 'voidcrew/modules/hyperviolence_gorilla/sound/gorilla_backbreaker.ogg'

/// Filter sources.
#define GORILLA_PUPPET_HIDE "gorilla_puppet_hide"
