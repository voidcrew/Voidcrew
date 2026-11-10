/**
 * # Dock terminal: CHARACTER preference adapters (package C1)
 *
 * Owns /datum/preferences/var/lobby_char_writes, the flag-gated /datum/preference/is_accessible()
 * override that lets the terminal write character prefs whatever tg's window last showed,
 * the /datum/preferences/ui_act() override that tells the terminal when tg's window changed
 * something, lobby_compile_char() and the null-safe slot switch.
 */
