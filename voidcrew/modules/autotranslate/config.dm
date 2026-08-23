/**
 * Config entries for auto-translation.
 *
 * Add to config/game_options.txt (all optional - leaving the URL unset keeps
 * the whole feature switched off):
 *
 *   ## Base URL of a LibreTranslate-compatible endpoint. Keep it on loopback.
 *   TRANSLATE_HTTP_URL http://127.0.0.1:5000
 *   ## Only needed if the instance was started with LT_API_KEYS enabled.
 *   #TRANSLATE_HTTP_TOKEN yourkeyhere
 *   ## Per-request timeout in seconds.
 *   TRANSLATE_HTTP_TIMEOUT_SECONDS 5
 */

/datum/config_entry/string/translate_http_url

/datum/config_entry/string/translate_http_token
	protection = CONFIG_ENTRY_HIDDEN

/datum/config_entry/number/translate_http_timeout_seconds
	default = 5
	min_val = 1
	max_val = 30
	integer = TRUE
