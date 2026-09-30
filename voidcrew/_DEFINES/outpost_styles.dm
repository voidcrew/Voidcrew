// Outpost styles. A player outpost takes its style from the shell its founder picks, and every
// room it buys later (upgrades, the ship bay) loads the map drawn for that style.
// To add a style: define it here, add a shell template with that `style`, and add a map template
// per room. A room without a map for the style falls back to OUTPOST_STYLE_DEFAULT.
// See voidcrew/modules/player_outposts/outpost_styles.dm.

/// Salvaged and patched up: rust, grime, warm light. Built from the look of the Grease Pit.
#define OUTPOST_STYLE_RUNDOWN "rundown"
/// New from the registry: bright tile, trim, glass and planters.
#define OUTPOST_STYLE_CLEAN "clean"
/// The style a room falls back to when it has no map for an outpost's style
#define OUTPOST_STYLE_DEFAULT OUTPOST_STYLE_RUNDOWN

/// Where the baked preview pictures of outpost shells and rooms live (tools/outpost_upgrade_previews)
#define OUTPOST_PREVIEW_DIR "voidcrew/modules/player_outposts/previews/"
