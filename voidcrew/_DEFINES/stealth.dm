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
#define STEALTH_DARK_SIGHT_RANGE 4
#define STEALTH_DARK_LUMCOUNT 0.2
#define STEALTH_DARK_MULT 0.5
#define STEALTH_CLOSE_RANGE 2
/// Elbow to elbow: someone this close in its cone is seen whatever the light (decision 31)
#define STEALTH_ADJACENT_RANGE 1
/// Point-blank (decision 32): someone it can see in its cone this close is an alert on that look
#define STEALTH_POINT_BLANK_RANGE 2
/// Near (decision 32): in its cone up to this far, notice fills STEALTH_NEAR_MULT times faster
#define STEALTH_NEAR_RANGE 4
#define STEALTH_NEAR_MULT 3
#define STEALTH_CONE_HALF_ANGLE 60
#define STEALTH_WARY_HALF_ANGLE 75
#define STEALTH_SEARCH_HALF_ANGLE 90
#define STEALTH_NOTICE_RATE 1.0
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
#define STEALTH_INVESTIGATE_DELAY (2 SECONDS)
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

// ===== Real flashlight pools (decision 39, stealth_light.dm) =====
/// Tiles ahead its pool lands, when nothing stops it first
#define STEALTH_TORCH_REACH 3
/// The same, facing a diagonal
#define STEALTH_TORCH_REACH_DIAGONAL 2
/// The pool's light power (its seclite blue takes it to about 1.2 white)
#define STEALTH_TORCH_POWER 1.5
/// The pool's light range with its centre 2.5 or more tiles off, 2 or more, and nearer (tg's least useful range)
#define STEALTH_TORCH_RANGE_FAR 2.5
#define STEALTH_TORCH_RANGE_MID 2
#define STEALTH_TORCH_RANGE_NEAR MINIMUM_USEFUL_LIGHT_RANGE
/// tg's seclite colour
#define STEALTH_TORCH_COLOR "#99ccff"

// ===== Readable turns (decision 39, stealth_turns.dm) =====
/// How long a guard leans towards the side it is about to turn to before it turns
#define STEALTH_TURN_TELL (0.6 SECONDS)
/// Pixels of that lean
#define STEALTH_TURN_LEAN 3
/// How long the lean takes to show and to go
#define STEALTH_TURN_LEAN_TIME (0.2 SECONDS)
/// After a turn where it stands, nothing is plain to it at a glance for this long (yellow; the skill holds the number)
#define STEALTH_TURN_GRACE (1 SECONDS)

#define FACTION_SCAV "scav"

// ===== Stealth crits and the backstab knife (step 3a, stealth_crits.dm) =====
// Roll bonuses for hyperviolence's aimed crit roll (crit_roll.dm), on a stealth guard only. They go in before wound armour,
// so armour scales them like the rest of the roll. Numbers argued in data/stealth/STATUS.md, "Step 3a".
/// Added when the guard was unaware of everyone as the blow began
#define STEALTH_CRIT_UNAWARE_BONUS 30
/// Added when it was only suspicious
#define STEALTH_CRIT_SUSPICIOUS_BONUS 15
/// Added on top of either when the attacker aimed at the head (head, eyes or mouth)
#define STEALTH_CRIT_HEAD_BONUS 35
/// Added when the backstab knife strikes from behind (tg's check_behind()), whatever the guard's state
#define STEALTH_BACKSTAB_BONUS 40
/// The head shot crit (a bullet through the skull) needs a roll this high, and only a stealth hit can roll it
#define STEALTH_HEAD_SHOT_THRESHOLD 80
/// Least damage after armour a head shot crit needs
#define STEALTH_HEAD_SHOT_MIN_DAMAGE 20
/// A helmet this good against the bullet (after its armour penetration) stops a head shot crit outright
#define STEALTH_HEAD_SHOT_HELMET_ARMOUR 30
/// Brain damage a head shot crit deals (brains die at 200)
#define STEALTH_HEAD_SHOT_BRAIN_DAMAGE 40
/// How long a head shot crit knocks the guard down
#define STEALTH_HEAD_SHOT_KNOCKDOWN (4 SECONDS)
/// A bullet through the head
#define WOUND_SERIES_HV_HEAD_SHOT "wound_series_hv_head_shot"
