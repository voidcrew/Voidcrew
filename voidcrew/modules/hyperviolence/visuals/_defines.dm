// Hyperviolence visuals: defines private to this part. Defines shared between the hyperviolence
// parts live in voidcrew/_DEFINES/hyperviolence.dm. Every number here is a first guess, untuned.
//
// This folder is named so it sorts after the other hyperviolence parts in tgstation.dme: its
// overrides of their procs must come after the procs are declared, or DM silently drops them.
// For the same reason this file and _motion_core.dm sort first inside the folder.

// ---- Named animation sequences ----
// Every animation this part plays on a mob is a named animate() sequence. A named sequence runs
// alongside every other animation on the atom (tg's lying turn, its offsets, the floating bob),
// adds only its own change on top, and replaces only an earlier sequence of the same name. Each one
// ends exactly where it began, so the server-side transform and pixel offsets never move.

#define HV_VIS_TAG_FLINCH "hv_flinch"
#define HV_VIS_TAG_HITSTOP "hv_hitstop"
#define HV_VIS_TAG_LURCH "hv_lurch"
#define HV_VIS_TAG_LIMP "hv_limp"
#define HV_VIS_TAG_FALL "hv_fall"
#define HV_VIS_TAG_SLIDE "hv_slide"
#define HV_VIS_TAG_POSE "hv_pose"
#define HV_VIS_TAG_TWITCH "hv_twitch"
#define HV_VIS_TAG_ARC "hv_arc"
#define HV_VIS_TAG_SPIN "hv_spin"
#define HV_VIS_TAG_PAINT "hv_paint"
#define HV_VIS_TAG_DRIFT "hv_drift"
#define HV_VIS_TAG_TREMBLE "hv_tremble"
#define HV_VIS_TAG_LEAN "hv_lean"
#define HV_VIS_TAG_PRESS "hv_press"
#define HV_VIS_TAG_LIFT "hv_lift"
#define HV_VIS_TAG_SHAKE "hv_shake"
#define HV_VIS_TAG_REAR "hv_rear"

/// What ends a held animation (/datum/component/hv_motion_hold).
#define HV_VIS_END_MOVE (1<<0)
#define HV_VIS_END_STAND (1<<1)
#define HV_VIS_END_REVIVE (1<<2)
#define HV_VIS_END_DEATH (1<<3)
#define HV_VIS_END_LIE (1<<4)

/// Where the feet of a standing 32x32 body are, from the middle of its icon. Leans pivot here.
#define HV_VIS_FEET_Y -16

/// The x and y of a direction, each -1, 0 or 1.
#define HV_VIS_DX(dir) (((dir) & EAST) ? 1 : (((dir) & WEST) ? -1 : 0))
#define HV_VIS_DY(dir) (((dir) & NORTH) ? 1 : (((dir) & SOUTH) ? -1 : 0))

// ---- Getting hit ----

/// Least damage in one tick that makes a body flinch.
#define HV_VIS_FLINCH_MIN 4
/// Damage per pixel a flinch pushes the body along the blow, and the most it ever pushes.
#define HV_VIS_FLINCH_DAMAGE_PER_PIXEL 6
#define HV_VIS_FLINCH_MAX_PUSH 8
/// Damage per degree a flinch tilts a standing body, and the most it ever tilts.
#define HV_VIS_FLINCH_DAMAGE_PER_DEGREE 3
#define HV_VIS_FLINCH_MAX_TILT 12
/// Damage in one tick (a shotgun's pellets together) that turns a flinch into a stagger.
#define HV_VIS_STAGGER_DAMAGE 40
/// Least damage to the head that whips it back.
#define HV_VIS_HEADSHOT_MIN 10
/// Tilt of a head snap, at least and at most.
#define HV_VIS_HEADSHOT_MIN_TILT 10
#define HV_VIS_HEADSHOT_MAX_TILT 22
/// How long a hit-stop holds both bodies still: three frames at 20 frames a second.
#define HV_VIS_HITSTOP_TIME (0.15 SECONDS)
/// The colour filter that flashes a body pale on a big hit.
#define HV_VIS_FLASH_FILTER "hv_vis_flash"
/// How far a lost limb throws the body toward the missing side, in pixels and degrees.
#define HV_VIS_LURCH_PUSH 4
#define HV_VIS_LURCH_TILT 14
/// The dip and lean of each step on one leg.
#define HV_VIS_LIMP_DIP 2
#define HV_VIS_LIMP_TILT 6

// ---- Dying ----

/// Damage in the killing tick that slides a body a whole tile.
#define HV_VIS_FULL_SLIDE_DAMAGE 40
/// How long a whole-tile slide takes.
#define HV_VIS_SLIDE_TIME (0.4 SECONDS)
/// How long a head shot that kills whips the head back before the body drops.
#define HV_VIS_KILL_WHIP_TIME (0.2 SECONDS)
/// How high a heavy killing blow lifts the body as it throws it back a tile.
#define HV_VIS_LAUNCH_LIFT 4
/// Most a body slides within its own tile, in pixels.
#define HV_VIS_MAX_SLIDE 10
/// How long a corpse keeps a pose (a slide, a curl) before it eases back. Moving, standing up or
/// being revived ends it at once.
#define HV_VIS_POSE_HOLD (20 MINUTES)
/// The beat an executed body holds before it slumps.
#define HV_VIS_SLUMP_BEAT (0.3 SECONDS)
/// How a body died, which decides how it falls (hv_vis_death_kind()).
/// Nothing that just hit it: poison, suffocation, a slow death in crit.
#define HV_VIS_DEATH_QUIET 0
/// A blow from a direction killed it.
#define HV_VIS_DEATH_HIT 1
/// A blow to the head killed it, or the head came off.
#define HV_VIS_DEATH_HEADSHOT 2
/// Fire or a burning blow killed it.
#define HV_VIS_DEATH_BURNED 3
/// It ran out of blood.
#define HV_VIS_DEATH_BLED_OUT 4
/// An execution round killed it.
#define HV_VIS_DEATH_EXECUTED 5

// ---- Flying gore ----

/// Styles of tumble (/datum/component/hv_tumble).
#define HV_VIS_TUMBLE_LIMB 1
#define HV_VIS_TUMBLE_HEAD 2
#define HV_VIS_TUMBLE_BRAIN 3
#define HV_VIS_TUMBLE_ORGAN 4
#define HV_VIS_TUMBLE_SLIDE 5
/// A part that comes off but goes nowhere (a head that bursts where it is).
#define HV_VIS_TUMBLE_NONE 6
/// How long a tumbling part takes to cross a tile, slow enough to see the arc.
#define HV_VIS_TUMBLE_STEP (0.1 SECONDS)
/// The layer of a part in the air: over bodies on the floor, under anyone on their feet.
#define HV_VIS_TUMBLE_LAYER (LYING_MOB_LAYER + 0.05)
/// Most blood streaks one tumbling part leaves along its way.
#define HV_VIS_TUMBLE_MAX_STREAKS 4

// ---- Blood ----

/// How long a spray takes to reach each further tile.
#define HV_VIS_SPRAY_STEP (0.06 SECONDS)
/// How long each tile of spray takes to paint in.
#define HV_VIS_SPRAY_PAINT (0.15 SECONDS)
/// How long a smear on a wall takes to run down.
#define HV_VIS_DRIP_TIME (6 SECONDS)
/// How long a pool takes to spread to its new size, and a lobe to run onto the next tile.
#define HV_VIS_POOL_CREEP (1.8 SECONDS)
#define HV_VIS_LOBE_CREEP (1.5 SECONDS)
/// How far floating blood drifts from the wound, in pixels, at least and at most.
#define HV_VIS_DRIFT_MIN 5
#define HV_VIS_DRIFT_MAX 10

// ---- Executions and finishers ----

/// How far the shooter leans in over the victim while the barrel is pressed to the head.
#define HV_VIS_PRESS_LEAN 4
/// The still moment at the end of the press, after the trembling stops.
#define HV_VIS_PRESS_PAUSE (0.3 SECONDS)
/// Screen shake of a finisher's killing blow, for everyone who sees it: length and strength in tiles.
#define HV_VIS_KILL_SHAKE_TIME 4
#define HV_VIS_KILL_SHAKE_STRENGTH 0.12
#define HV_VIS_KILL_SHAKE_RANGE 7
