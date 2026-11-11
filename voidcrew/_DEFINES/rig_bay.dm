// The Rig Bay: exosuits sold off chained stands at Wick's outfitter (voidcrew/modules/trade/rig_bay/).

/// On a display mech while it hangs from its stand's chains (set and cleared by the clamp component).
#define TRAIT_RIG_BAY_CLAMPED "rig_bay_clamped"
/// Trait source for TRAIT_RIG_BAY_CLAMPED.
#define RIG_BAY_TRAIT "rig_bay"

/// Sent on a mech when a mob tries to climb in: (mob/entering). Hooked in rig_bay_mecha.dm.
#define COMSIG_MECHA_TRY_ENTER "mecha_try_enter"
	/// Return from COMSIG_MECHA_TRY_ENTER to refuse the entry.
	#define COMPONENT_MECHA_BLOCK_ENTER (1<<0)

/// Longest a sold mech stays locked to the buyer's crew while it is on outpost ground.
#define RIG_BAY_HOLD_TIME (20 MINUTES)
/// Pixels a chained mech hangs above its stand. Release lowers it back to 0.
#define RIG_BAY_HANG_LIFT 4

// Stand states (/obj/structure/rig_bay_stand var/stand_state)
/// Nothing on the stand; waits for the next due convoy.
#define RIG_BAY_STAND_EMPTY "empty"
/// A mech is beaming in. Its SKU has stock 0 until the beam-in finishes.
#define RIG_BAY_STAND_ARRIVING "arriving"
/// A mech hangs on the stand for sale. Its SKU has stock 1.
#define RIG_BAY_STAND_CLAMPED "clamped"
/// A sold mech is being lowered. Its SKU has stock 0.
#define RIG_BAY_STAND_RELEASING "releasing"
/// A sold mech is down and free but hasn't left the stand tile yet. Restock skips the stand.
#define RIG_BAY_STAND_SOLD_ON_STAND "sold_on_stand"
