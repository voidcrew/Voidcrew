// Stealth layer for chosen human NPCs (voidcrew/modules/stealth/). Awareness is AI state only.

// ===== Awareness states (BB_STEALTH_STATE) =====
#define STEALTH_UNAWARE "unaware"
#define STEALTH_SUSPICIOUS "suspicious"
#define STEALTH_ALERT "alert"
#define STEALTH_SEARCHING "searching"

// ===== Blackboard keys =====
/// One of the STEALTH_* states
#define BB_STEALTH_STATE "stealth_state"
/// world.time of the last state change
#define BB_STEALTH_STATE_SINCE "stealth_state_since"
/// world.time the guard last stopped being unaware (stealth_was_unaware())
#define BB_STEALTH_UNAWARE_LOST_AT "stealth_unaware_lost_at"
/// The state before the last change, so a blow can be judged by the state it began in (stealth_state_at_blow())
#define BB_STEALTH_PREV_STATE "stealth_prev_state"
/// TRUE once alerted, searching or hit. Fades after STEALTH_WARY_TIME with nothing new (checked each scan).
#define BB_STEALTH_WARY "stealth_wary"
/// The candidate with the highest notice
#define BB_STEALTH_FOCUS "stealth_focus"
/// world.time it last saw (or was hit from) whoever it is after; the turf is the controller's last_seen_turf
#define BB_STEALTH_LAST_SEEN_AT "stealth_last_seen_at"
/// REFs of fallen group members it has already reacted to
#define BB_STEALTH_BODIES_SEEN "stealth_bodies_seen"

// Notice entry fields (the controller's notice_map)
#define STEALTH_ENTRY_NOTICE 1
#define STEALTH_ENTRY_TURF 2
#define STEALTH_ENTRY_SEEN_AT 3

// ===== Bark kinds =====
#define STEALTH_BARK_SUSPICIOUS "stealth_suspicious"
#define STEALTH_BARK_GIVE_UP "stealth_give_up"
#define STEALTH_BARK_LOST "stealth_lost"
#define STEALTH_BARK_SEARCH "stealth_search"
#define STEALTH_BARK_HIT_UNSEEN "stealth_hit_unseen"
#define STEALTH_BARK_BODY "stealth_body"
#define STEALTH_BARK_CHATTER "stealth_chatter"
/// It just put its target down
#define STEALTH_BARK_DOWNED "stealth_target_downed"
/// It yanks open the locker or crate it saw its target get into (decision 33)
#define STEALTH_BARK_CLOSET_OPEN "stealth_closet_open"
/// It gives up on a locker or crate it can't get open (decision 33)
#define STEALTH_BARK_CLOSET_GIVE_UP "stealth_closet_give_up"
/// It slipped on something
#define STEALTH_BARK_SLIP "stealth_slip"

// ===== What a stealth goto is for =====
#define STEALTH_GOTO_PATROL "patrol"
#define STEALTH_GOTO_INVESTIGATE "investigate"
#define STEALTH_GOTO_BODY "body"
#define STEALTH_GOTO_SEARCH "search"
#define STEALTH_GOTO_HOME "home"
#define STEALTH_GOTO_CLOSET "closet"

// ===== Numbers (first playtest defaults; the owner tunes them) =====
#define STEALTH_SCAN_INTERVAL (1 SECONDS)
#define STEALTH_SIGHT_RANGE 8
#define STEALTH_ALERT_MAX_RANGE 7
#define STEALTH_DARK_LUMCOUNT 0.2
#define STEALTH_DARK_MULT 0.5
/// Elbow to elbow: someone this close in its cone is seen whatever the light (decision 31)
#define STEALTH_ADJACENT_RANGE 1
/// Point-blank (decision 32): someone it can see in its cone this close is an alert on that look
#define STEALTH_POINT_BLANK_RANGE 2
/// Near (decision 32): in its cone up to this far, notice fills STEALTH_NEAR_MULT times faster
#define STEALTH_NEAR_RANGE 4
#define STEALTH_NEAR_MULT 3
#define STEALTH_CONE_HALF_ANGLE 60
#define STEALTH_NOTICE_MIN_FALLOFF 0.25
#define STEALTH_SUSPICIOUS_AT 1.0
#define STEALTH_ALERT_AT 2.5
/// Notice never climbs past this, so nobody banks a lead that hides someone else
#define STEALTH_NOTICE_MAX STEALTH_ALERT_AT
#define STEALTH_NOTICE_DECAY 0.34
#define STEALTH_NOTICE_FORGET (20 SECONDS)
#define STEALTH_BEHIND_RATE 0.4
#define STEALTH_STILL_MULT 0.5
#define STEALTH_LYING_MULT 0.5
#define STEALTH_SUSPICIOUS_MULT 1.5
#define STEALTH_SEARCHING_MULT 2
#define STEALTH_WARY_MULT 1.5
#define STEALTH_MAX_CANDIDATES 8
#define STEALTH_LOOK_AROUND_TIME (4 SECONDS)
#define STEALTH_SUSPICIOUS_TIMEOUT (12 SECONDS)
#define STEALTH_LOSE_TARGET_TIME (4 SECONDS)
#define STEALTH_SEARCH_TIME (40 SECONDS)
/// After putting its target down with nobody else about: how long it looks round before calming down
#define STEALTH_CALM_LOOK_TIME (6 SECONDS)
/// How long wary lasts after the last notice gain, hit, touch, alert or search
#define STEALTH_WARY_TIME (60 SECONDS)
#define STEALTH_SEARCH_POINTS 3
#define STEALTH_SEARCH_RADIUS 5
#define STEALTH_BODY_SCAN_INTERVAL (2 SECONDS)
#define STEALTH_BARK_KIND_COOLDOWN (8 SECONDS)
/// Past the end of a slip's knockdown, how long getting up still counts as getting up from the slip
#define STEALTH_SLIP_GRACE (1 SECONDS)
#define STEALTH_GROUP_RADIUS 48
#define STEALTH_ROUTE_CLAIM_RANGE 2
#define STEALTH_PATROL_DEFAULT_WAIT (6 SECONDS)
#define STEALTH_LOOK_TURN_INTERVAL (3 SECONDS)
#define STEALTH_LOOK_TURN_ARC 90
#define STEALTH_SENTRY_TURN_INTERVAL (8 SECONDS)
/// How long a sentry looks aside before it faces its post again
#define STEALTH_SENTRY_GLANCE_TIME (2 SECONDS)
#define STEALTH_CHATTER_RANGE 3
#define STEALTH_CHATTER_COOLDOWN (45 SECONDS)
#define STEALTH_PATROL_MAX_FAILS 3
#define STEALTH_PATROL_SKIP_TIME (2 MINUTES)
#define STEALTH_PATROL_MAX_PATH 60
#define STEALTH_LEASH_RANGE 24
/// Tiles a single walk covers; a destination further off is walked in legs
#define STEALTH_WALK_LEG 40
/// A sentry that can't get back to its post tries again this often
#define STEALTH_HOME_RETRY_TIME (30 SECONDS)
/// Alert: someone else must be this many tiles nearer than its target before it turns on them
#define STEALTH_SWITCH_MARGIN 2
/// Alert: the shortest time between two changes of target
#define STEALTH_SWITCH_COOLDOWN (4 SECONDS)
/// Health lost within STEALTH_HARM_WINDOW, with nobody to blame, that sends it looking
#define STEALTH_HARM_HEALTH 10
#define STEALTH_HARM_WINDOW (10 SECONDS)
/// The shortest time between two reactions to harm nobody can be blamed for
#define STEALTH_HARM_COOLDOWN (10 SECONDS)
/// How far its group hears it being blown up, burned, gassed or stunned
#define STEALTH_HARM_ALERT_RANGE 9
#define STEALTH_ADMIN_OVERLAY_TIME (5 MINUTES)
/// How often an admin sight overlay is redrawn for a guard that hasn't moved or turned
#define STEALTH_ADMIN_SIGHT_REDRAW (5 SECONDS)
/// Seconds of search between "Come on out." lines
#define STEALTH_SEARCH_BARK_INTERVAL (12 SECONDS)

// Lockers and crates it saw someone get into (decision 33, stealth_closet.dm)
/// Seen on open ground this recently and now in a locker in view: it saw them get in
#define STEALTH_CLOSET_SEEN_WINDOW (1.5 SECONDS)
/// After this long on one locker (walking, opening, bashing) it gives up and searches round it
#define STEALTH_CLOSET_GIVE_UP_TIME (45 SECONDS)
/// A guard that isn't the one opening it stands this close and covers it
#define STEALTH_CLOSET_COVER_RANGE 3

// Doors seen moving (decision 37, stealth_doors.dm)
/// A door one of the group opened: its next close this soon after is theirs too (an airlock shuts itself after 6 s)
#define STEALTH_DOOR_GUARD_MEMORY (20 SECONDS)
/// After a door sent someone to look, it only gets glances for this long
#define STEALTH_DOOR_CUE_COOLDOWN (30 SECONDS)
/// A door that sent someone to look STEALTH_DOOR_CUE_MAX times within this long is ignored for the rest of it
#define STEALTH_DOOR_CUE_MEMORY (3 MINUTES)
#define STEALTH_DOOR_CUE_MAX 2

// The mark over a guard's head (stealth_meter.dm, owner decision 27)
/// Pixel rows in the "?" and "!" glyphs: fill and drain steps
#define STEALTH_METER_ROWS 7
/// Tiles from the guard within which a living player makes the mark worth drawing
#define STEALTH_METER_RANGE 10
/// pixel_z of the glyph's bottom over a standing, medium-height guard: a clear gap over the hair
#define STEALTH_METER_HEAD_Z 36
/// pixel_z of the glyph's bottom over a guard lying down (its sprite also drops PIXEL_Y_OFFSET_LYING)
#define STEALTH_METER_LYING_Z 29

/// The scav den's side
// ===== Flashlights (decision 31, stealth_light.dm) =====
/// It keeps its light on this long after it last wanted it
#define STEALTH_LIGHT_HOLD (5 SECONDS)
/// A heavy EMP cuts a guard's seclite out for this long
#define STEALTH_LIGHT_EMP_HEAVY (40 SECONDS)
/// A light EMP cuts a guard's seclite out for this long
#define STEALTH_LIGHT_EMP_LIGHT (20 SECONDS)

// ===== Flashlight beams (decisions 39 and 41, stealth_light.dm) =====
/// The beam's light range in tiles, from where it starts (the lit floor ends 4 tiles ahead of the guard)
#define STEALTH_TORCH_RANGE 5
/// The beam's light power (its seclite blue takes it to about 1.5 white)
#define STEALTH_TORCH_POWER 1.9
/// Degrees of the beam at full strength; tg fades it to nothing over the next 30 each side
#define STEALTH_TORCH_ANGLE 30
/// Tiles ahead of the guard's own tile the beam starts (the hand, not the body), so its own tile stays dark
#define STEALTH_TORCH_FORWARD 0.5
/// tg's seclite colour
#define STEALTH_TORCH_COLOR "#99ccff"
/// A turn of 90 degrees or more shows the beam halfway for this long before it lands
#define STEALTH_TORCH_TURN_STEP (0.15 SECONDS)
/// A step at a walk shows the beam half a tile back for this long
#define STEALTH_TORCH_HALF_STEP (0.2 SECONDS)
/// Suspicious or searching and standing: the beam swings a side, back, the other side, back, one move per this long
#define STEALTH_TORCH_SWEEP_STEP (0.6 SECONDS)
/// A seclite that is cut out sputters: world.time offsets it flashes on at, and how long each flash lasts
#define STEALTH_TORCH_SPUTTER_AT list(0.2 SECONDS, 0.5 SECONDS)
#define STEALTH_TORCH_SPUTTER_FLASH (0.1 SECONDS)
/// Loudness of the click when a guard switches its light
#define STEALTH_TORCH_CLICK_VOLUME 25
/// The visible cone (decision 42) comes in this many lengths, an eighth of a tile apart; the last is an open beam
#define STEALTH_BEAM_LENGTHS 22
/// Pixels from the guard's tile centre to its icon's centre (stealth_beam.dmi is 128x192, the guard at its bottom middle)
#define STEALTH_BEAM_PIVOT 96
/// The longest a guard's cone waits for SSlighting to apply its lamp before it shows anyway (decision 42 sync)
#define STEALTH_BEAM_WAIT_CAP (5 SECONDS)
/// A lit light someone carries within this many tiles of an unaware guard standing in the dark draws its notice
/// even behind it (never further than the light itself reaches)
#define STEALTH_STRAY_LIGHT_RANGE 5
/// Notice a second from such a light. It only ever fills to suspicious: the guard turns and uses its eyes.
#define STEALTH_STRAY_LIGHT_RATE 0.5
/// Bark: someone's light is on it
#define STEALTH_BARK_LIGHT "stealth_light"
/// Bark: its own light cut out
#define STEALTH_BARK_LIGHT_DEAD "stealth_light_dead"

// ===== Readable turns (decision 39, stealth_turns.dm) =====
/// How long a guard leans towards the side it is about to turn to before it turns
#define STEALTH_TURN_TELL (0.6 SECONDS)
/// Pixels of that lean
#define STEALTH_TURN_LEAN 3
/// The lean's key in tg's mob offsets (add_offsets()); it shows and goes over tg's own offset animation
#define STEALTH_TURN_LEAN_SOURCE "stealth_lean"

#define FACTION_SCAV "scav"

// ===== Disguises (decision 40, stealth_disguise.dm) =====
/// The den's own doors
#define ACCESS_SCAV "scav"
/// The den boss's vault (scav_den.dm): only his pass opens it
#define ACCESS_SCAV_VAULT "scav_vault"
// What someone wears of the scavs' own
/// Their face is hidden (tg's get_face_name() finds none)
#define STEALTH_PIECE_MASK (1<<0)
/// The scav fatigues, showing, under nothing the guards don't wear
#define STEALTH_PIECE_CLOTHES (1<<1)
/// A scav pass in the ID slot
#define STEALTH_PIECE_ID (1<<2)
/// What someone wears is worked out again when it is older than this (a mask pulled down, a face wrecked)
#define STEALTH_DISGUISE_CACHE_TIME (2 SECONDS)
/// Share of the usual notice gained in the fatigues, in the fatigues and a mask, and in the whole set inside the
/// guard's near range (beyond it the whole set gains none). Scaled by the guard's skill (`disguise`).
#define STEALTH_DISGUISE_FILL_CLOTHES 0.5
#define STEALTH_DISGUISE_FILL_MASKED 0.25
#define STEALTH_DISGUISE_FILL_FULL 0.05
/// Tiles within which a guard that sees them plainly stops them, for the same three. Its skill and being wary add to it.
#define STEALTH_CHALLENGE_RANGE_CLOTHES 5
#define STEALTH_CHALLENGE_RANGE_MASKED 3
#define STEALTH_CHALLENGE_RANGE_FULL 2
/// It reads a pass from this close
#define STEALTH_CHALLENGE_CHECK_RANGE 2
/// It reads a pass for this long before it lets them go
#define STEALTH_CHALLENGE_CHECK_TIME (2 SECONDS)
/// With no pass shown, it asks again after this long
#define STEALTH_CHALLENGE_WARN_TIME (3 SECONDS)
/// With no pass shown after this long, the disguise is blown
#define STEALTH_CHALLENGE_FAIL_TIME (6 SECONDS)
/// Not near enough to read the pass this long after the stop (kept out of reach), the disguise is blown
#define STEALTH_CHALLENGE_REACH_TIME (STEALTH_CHALLENGE_FAIL_TIME + STEALTH_CHALLENGE_CHECK_TIME)
/// Further than this from where it stopped them is walking off
#define STEALTH_CHALLENGE_LEASH 2
/// How long a guard that read their pass lets them be
#define STEALTH_PASS_TIME (5 MINUTES)
/// Someone it waved on is stopped again (the pass came off and went back on) within STEALTH_PASS_RECHECK_COOLDOWN of a
/// wave, or after STEALTH_PASS_RECHECK_MAX waves within STEALTH_PASS_RECHECK_MEMORY: it sees through them instead.
#define STEALTH_PASS_RECHECK_COOLDOWN (60 SECONDS)
#define STEALTH_PASS_RECHECK_MEMORY (5 MINUTES)
#define STEALTH_PASS_RECHECK_MAX 2
/// How long a guard remembers the wearer of a disguise it saw through (a face it remembers for good)
#define STEALTH_MADE_TIME (5 MINUTES)
/// Tiles within which a guard has a word for one of its own
#define STEALTH_GREET_RANGE 4
#define STEALTH_GREET_COOLDOWN (30 SECONDS)
/// Anything sharp with this much force is a weapon in hand, like any gun or melee weapon
#define STEALTH_WEAPON_FORCE 10
/// One of its own goes by
#define STEALTH_BARK_GREET "stealth_greet"
/// It asks one of its own for a light
#define STEALTH_BARK_SMOKE "stealth_smoke"
/// It stops someone to see their pass
#define STEALTH_BARK_CHALLENGE "stealth_challenge"
/// The pass is good
#define STEALTH_BARK_ID_PASS "stealth_id_pass"
/// No pass yet: it asks again
#define STEALTH_BARK_ID_FAIL "stealth_id_fail"
/// It has seen through a disguise
#define STEALTH_BARK_BLOWN "stealth_blown"

// ===== Stealth crits, the head shot and the backstab (step 3a, decision 45; stealth_crits.dm, knife_executions.dm) =====
// Roll bonuses for hyperviolence's aimed crit roll (crit_roll.dm), on a stealth guard only. They go in before wound armour,
// so armour scales them like the rest of the roll.
/// Added when the guard was unaware of everyone as the blow began
#define STEALTH_CRIT_UNAWARE_BONUS 30
/// Added when it was only suspicious
#define STEALTH_CRIT_SUSPICIOUS_BONUS 15
/// Added on top of either when the attacker aimed at the head (head, eyes or mouth)
#define STEALTH_CRIT_HEAD_BONUS 35
// The head shot (decision 45): a bullet aimed at the head of a guard caught off guard. Graded by what the round can do
// against what is on the head.
// The round's power gives burst, down or nothing; each protection step on the head moves it one down the ladder.
/// Nothing happens beyond the hit itself
#define STEALTH_HEAD_SHOT_NONE 0
/// Stopped short of the skull: knocked out for STEALTH_HEAD_SHOT_HELMET_TIME
#define STEALTH_HEAD_SHOT_HELMET 1
/// Through the skull: brain damage, a heavy bleed, out cold until the bleed takes him
#define STEALTH_HEAD_SHOT_DOWN 2
/// The head bursts (hv_burst_head_apart())
#define STEALTH_HEAD_SHOT_BURST 3
/// Head protection (tg's armour against the round after its penetration, plus wound armour) for one step down
#define STEALTH_HEAD_SHOT_STEP_ONE 20
/// For two steps down
#define STEALTH_HEAD_SHOT_STEP_TWO 50
/// For three steps down: nothing beyond the hit
#define STEALTH_HEAD_SHOT_STEP_THREE 80
/// Least power for a round through the skull (power: the round's damage, plus half a positive wound bonus, plus the caliber bonus)
#define STEALTH_HEAD_SHOT_MIN_POWER 15
/// Power at which the head bursts
#define STEALTH_HEAD_SHOT_BURST_POWER 40
/// Added to the power of a rifle or shotgun round (stealth_heavy_caliber()), once per shot
#define STEALTH_HEAD_SHOT_HEAVY_CALIBER 15
/// The power of a round from a suppressed gun is multiplied by this
#define STEALTH_HEAD_SHOT_SUPPRESSED_MULT 0.75
/// Brain damage a round through the skull deals (BRAIN_DAMAGE_SEVERE is 100, brains die at 200)
#define STEALTH_HEAD_SHOT_BRAIN_DAMAGE 120
/// Blood flow of the wound a round through the skull leaves (tg's critical puncture is 3, a cut throat about 4)
#define STEALTH_HEAD_SHOT_FLOW 8
/// How long a round through the skull knocks him out: longer than the bleed takes to put him under for good
#define STEALTH_HEAD_SHOT_DOWN_TIME (90 SECONDS)
/// How long a round a helmet stopped knocks him out
#define STEALTH_HEAD_SHOT_HELMET_TIME (6 SECONDS)
/// A bullet through the head
#define WOUND_SERIES_HV_HEAD_SHOT "wound_series_hv_head_shot"
