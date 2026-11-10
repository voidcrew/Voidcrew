/**
 * # Dock terminal: CHARACTER section (package C1)
 *
 * A thin adapter over /datum/preferences for the terminal's CHARACTER tab. Overrides the
 * seams declared in _lobby_terminal.dm without the `proc/` keyword: char_data(), char_act(),
 * char_changed(), char_push(), char_save().
 *
 * Owns: every char_* action except the preview's, the char/char_static pushes, saving,
 * sync with tg's character window, the species confirm flow, the native colour pick and the
 * shared roundstart job pool GLOB (C2 reads it for the preview's outfits).
 *
 * Preference adapters (is_accessible override, lobby_char_writes, ui_act sync) live in
 * lobby_character_prefs.dm; the preview in lobby_character_preview.dm.
 */
