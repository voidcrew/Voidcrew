// Rhythm battles (voidcrew/modules/fnf)

/// Server time in deciseconds, including how far into the current tick we are. Key presses
/// arrive mid-tick, so world.time alone would round every press to the tick.
#define FNF_NOW (world.time + world.tick_lag * TICK_USAGE_REAL / 100)

/// How far off a press can be from its note and still count, in milliseconds either side.
#define FNF_WINDOW_SICK 55
#define FNF_WINDOW_GOOD 100
#define FNF_WINDOW_BAD 140
#define FNF_WINDOW_SHIT 175

/// A long note let go this close to its end counts as held to the end, in milliseconds.
#define FNF_HOLD_GRACE 90

/// Battle states.
#define FNF_STATE_READY 0
#define FNF_STATE_COUNTDOWN 1
#define FNF_STATE_PLAYING 2
#define FNF_STATE_OVER 3

/// Health runs from 0 (the challenger on the right lost) to 100 (the opponent on the left lost).
#define FNF_HEALTH_MAX 100

/// Layout, in pixels: the strums' height above the singer's tile, how far below them notes
/// start, the gap between lanes, and the health bar's size.
#define FNF_STRUM_Y 60
#define FNF_TRAVEL_PX 150
#define FNF_LANE_GAP 22
#define FNF_BAR_WIDTH 128
#define FNF_BAR_HEIGHT 6
/// How wide a health bar's own frame is (see /obj/effect/abstract/fnf_hud/healthbar/proc/set_frame()).
#define FNF_HUD_FRAME_WIDTH 144

/// Trait source for being kept on the floor through a game over.
#define FNF_GAME_OVER_TRAIT "fnf_game_over"
/// Trait source for being locked into singing.
#define FNF_BATTLE_TRAIT "fnf_battle"
/// How far a singer's screen zooms in on the stage.
#define FNF_ZOOM 2
/// Priority of a summoned opponent's skin colour over their limbs: the lowest, so anything else
/// that recolours limbs (a hulk's green) still wins.
#define FNF_SKIN_PRIORITY 1

// Corruption+ songs (voidcrew/modules/fnf/corruption.dm).
/// The colour corruption coats things in.
#define FNF_CORRUPTION_COLOUR "#261636"
/// What corrupted hands turn.
#define FNF_CORRUPTION_HANDS "#a8102c"
/// How much of the corruption it takes to swallow one piece of the body, start to finish.
#define FNF_CORRUPTION_SPAN 0.35
/// How far a head's taken over before its face is the corruption's: halfway, as dark as it gets
/// with its own face still to be seen on it.
#define FNF_CORRUPTION_FACE 0.5
/// How far below its peak corruption has to fall for a piece to be fought wholly free.
#define FNF_CORRUPTION_FIGHT 0.4
/// How much of a taken head has to be fought free for its near eye to come back, the grin staying.
#define FNF_CORRUPTION_FACE_HALF 0.45
/// And for the whole face to.
#define FNF_CORRUPTION_FACE_FREED 0.9
/// What the main colour of clothes corruption's taken turns: its violet, with next to no green, so
/// their shading sinks to indigo rather than teal.
#define FNF_CORRUPTION_CLOTHES_COLOUR "#2c0640"
/// What the bright trims of clothes corruption's taken glow.
#define FNF_CORRUPTION_TRIM "#ff289e"
/// The darkest clothes' main colour is taken to be, so dark clothes stay dark (brightness, 0 to 1).
#define FNF_CORRUPTION_DARKEST_MAIN 0.4
/// How much brighter than the clothes' main colour a trim has to be to glow fully.
#define FNF_CORRUPTION_TRIM_RISE 0.3
