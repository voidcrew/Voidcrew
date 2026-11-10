/**
 * # Dock terminal: CHARACTER preview (package C2)
 *
 * Server-rendered PNGs of the dressed mannequin, one facing at a time, cached by appearance
 * key and pushed as one-off char_preview updates. Overrides char_preview_request() and
 * char_appearance_key() from _lobby_terminal.dm, and owns char_preview_cache, the render
 * queue and its time budget, and the dress table built from the roundstart job pool.
 */
