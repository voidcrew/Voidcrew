#define ui_action_palette_offset_with_scale(scale_offset, north_offset) ("WEST+[1 + scale_offset]:[23 * scale_offset],NORTH-[1+north_offset]:5")
#define ui_palette_scroll_offset_with_scale(scale_offset, north_offset) ("WEST+[1 + scale_offset]:[8 * scale_offset],NORTH-[6+north_offset]:28")

/// Hull survey button - the wide labelled slot immediately left of THROW, completing the
/// RESIST/REST row block. This tile is ui_above_movement_top in stock tg, where the pull
/// icon lives; the pull icon is displaced one row up to ui_pull_displaced below.
#define ui_hull_survey "EAST-2:26,SOUTH+1:24"

/// Stock tg parks the pull icon on the tile the hull survey button now occupies. It renders
/// as nothing while you aren't pulling (its idle "pull0" state isn't in the HUD sheets), so
/// the tile reads as empty - but it is still a live clickable and would sit on top of ours.
/// Moved one row up, into the otherwise unused EAST-2 slot beside SLEEP.
#define ui_pull_displaced "EAST-2:26,SOUTH+1:41"
