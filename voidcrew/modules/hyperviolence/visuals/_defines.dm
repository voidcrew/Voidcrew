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
/// Throw speed (tiles a decisecond) of a tumbling part, slow enough to see the arc.
#define HV_VIS_TUMBLE_SPEED 1
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

// ---- Knife executions ----
// Step-in offsets below are a deliberate exception to _motion_core.dm's third-of-a-tile rule: pixel_w
// and pixel_z never change the SIDE_MAP sort row (y + pixel_y), so cross-tile sort order is preserved.

/// Named animation sequence for the attacker stepping in and out during a knife execution.
#define HV_VIS_TAG_KNIFE_STEP "hv_knife_step"
/// Named animation sequence for the victim's head pull and standing hunch in a knife execution.
#define HV_VIS_TAG_KNIFE_VICTIM "hv_knife_victim"
/// How long the grab and step-in at the start of a knife execution wind-up take.
#define HV_VIS_KNIFE_GRAB_TIME (0.3 SECONDS)
/// How long the blade takes to draw across the victim's throat at the end of the wind-up.
#define HV_VIS_KNIFE_CUT_TIME (0.25 SECONDS)
/// Brief hold at the end of the throat cut before the attacker lets go and the props vanish.
#define HV_VIS_KNIFE_CUT_HOLD (0.1 SECONDS)
/// How long the attacker takes to step back to zero offset after the cut completes.
#define HV_VIS_KNIFE_RELEASE_TIME (0.25 SECONDS)
/// How fast a broken wind-up eases both bodies back to their starting pose (under 0.3 s).
#define HV_VIS_KNIFE_ABORT_TIME (0.2 SECONDS)
/// How long a standing survivor takes to pitch into a forward throat-clutch hunch after release.
#define HV_VIS_KNIFE_HUNCH_IN (0.15 SECONDS)
/// How long a standing survivor holds the forward throat-clutch hunch before returning upright.
#define HV_VIS_KNIFE_HUNCH_HOLD (0.4 SECONDS)
/// How long a standing survivor takes to return from the forward hunch to their true pose.
#define HV_VIS_KNIFE_HUNCH_OUT (0.3 SECONDS)
/// Pixels a side-on (E/W) attacker steps toward the victim so their chest meets the victim's back.
#define HV_VIS_KNIFE_STEP_SIDE 19
/// Pixels a north/south attacker steps toward the victim so their chest meets the victim's back.
#define HV_VIS_KNIFE_STEP_FRONT 15
/// Per-axis pixels a diagonal attacker steps toward a helpless victim.
#define HV_VIS_KNIFE_STEP_DIAG 13
/// Degrees a side-facing standing victim is tilted back toward the attacker about their feet.
#define HV_VIS_KNIFE_TILT_SIDE 7
/// Pixels a north- or south-facing standing victim shifts back toward the attacker during the wind-up.
#define HV_VIS_KNIFE_PULL_FRONT 2
/// Feet-anchored vertical stretch added to a north- or south-facing victim so their head draws 1 px up.
#define HV_VIS_KNIFE_HEAD_STRETCH 0.042
/// Degrees a lying victim is tugged toward the attacker during the wind-up.
#define HV_VIS_KNIFE_TILT_LYING 2
/// Degrees a standing survivor hunches forward about their feet after the throat is cut.
#define HV_VIS_KNIFE_HUNCH_TILT 9
/// Native pixel length from fist centre (rows 16-17) to shoulder top (row 11) on human arm sprites.
#define HV_VIS_KNIFE_ARM_BASE_LEN 6
/// Maximum lengthwise stretch factor allowed on the attacker's forearm prop.
#define HV_VIS_KNIFE_ARM_MAX_STRETCH 2
/// Scale applied to a 32x32 diagonal knife sprite so the prop renders ~10 px long in a 32 px hand.
#define HV_VIS_KNIFE_SCALE 0.28
/// Unscaled axial sprite coordinate (from 32x32 centre) of a knife's grip under the holder's fist.
#define HV_VIS_KNIFE_SPRITE_GRIP -8.75
/// Unscaled axial sprite coordinate (from 32x32 centre) of the cutting edge heel where a front draw begins.
#define HV_VIS_KNIFE_SPRITE_HEEL -2
/// Unscaled axial sprite coordinate resting on a side-facing victim's throat while held.
#define HV_VIS_KNIFE_SPRITE_SIDE_HOLD 8
/// Unscaled axial sprite coordinate (from 32x32 centre) of the blade tip that finishes on the throat.
#define HV_VIS_KNIFE_SPRITE_TIP 12
/// Layer for the attacker's clothed forearm and hand in front of the victim's neck (above MOB_LAYER 4.0).
#define HV_VIS_KNIFE_ARM_LAYER 4.05
/// Layer for the knife blade above the forearm prop so the full blade shows in front of the neck.
#define HV_VIS_KNIFE_BLADE_LAYER 4.06
