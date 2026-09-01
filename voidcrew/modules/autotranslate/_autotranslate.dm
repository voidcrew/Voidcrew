/**
 * # Auto-translation - DM side API
 *
 * Shows a message in its original language immediately, marks it as having a
 * translation in flight, and then morphs the text over to the translation
 * letter-by-letter once the backend answers.
 *
 * This file only contains the plumbing. No translation backend is implemented
 * here - see provider.dm for the interface a backend has to satisfy.
 *
 * The two display surfaces are driven differently, on purpose:
 *
 * - Runechat (maptext floating over the speaker) is rendered server side, so
 *   the morph animation itself runs in DM. See /datum/text_morph and
 *   /datum/chatmessage/proc/set_display_text().
 * - The chat panel is a browser. Streaming a dozen animation frames per
 *   message per client over the wire would be wasteful, so DM sends a single
 *   "here is the final text" message and tgui-panel plays the animation.
 *   See /datum/translated_speech/proc/push_chat_update() for the payload.
 */

/// Translation has been requested but has not come back yet.
#define TRANSLATION_PENDING "pending"
/// Translation arrived and the morph has been kicked off.
#define TRANSLATION_DONE "done"
/// Backend errored, timed out, or is unavailable. Original text stays put.
#define TRANSLATION_FAILED "failed"

/// How long a single request may stay in flight before we give up on it.
#define TRANSLATION_REQUEST_TIMEOUT (8 SECONDS)

/// How long the letter-by-letter morph takes end to end.
#define TRANSLATION_MORPH_DURATION (0.5 SECONDS)
/// Delay between morph frames. 0.05s = 20fps.
#define TRANSLATION_MORPH_INTERVAL (0.05 SECONDS)
/// How many characters ahead of the reveal point get scrambled. This is the
/// "flair" - 0 gives a plain left-to-right wipe.
#define TRANSLATION_MORPH_SCRAMBLE 3

/// How often the runechat pending indicator advances a frame.
#define TRANSLATION_PENDING_INTERVAL (0.25 SECONDS)
/// Frames of the runechat pending indicator, cycled while we wait.
GLOBAL_LIST_INIT(translation_pending_frames, list("&nbsp;.", "&nbsp;..", "&nbsp;..."))

/**
 * Chat payload type used to tell the panel a translation landed.
 *
 * The "internal/" prefix matters: canPageAcceptType() in chat/model.ts passes
 * those through to every page regardless of the player's tab filters, and
 * getCombinableMessage() refuses to merge them with neighbouring messages.
 */
#define TRANSLATION_PANEL_MESSAGE "internal/translation"

/// Incrementing id handed to each translated message so DM and JS agree on
/// which chat line is being talked about.
GLOBAL_VAR_INIT(translation_message_id, 0)

/**
 * Per-boot token mixed into every id.
 *
 * The counter alone is not enough. It resets to zero on every server restart,
 * but the chat panel persists messages to browser storage across sessions -
 * so a fresh "tsl-1" collides with a "tsl-1" restored from a previous round,
 * and document.querySelector returns the older one. The translation then
 * lands on a dead line from a past round while the real one waits forever.
 */
GLOBAL_VAR_INIT(translation_id_prefix, "[world.timeofday]x[rand(1000, 9999)]")

/proc/next_translation_id()
	GLOB.translation_message_id++
	return "tsl-[GLOB.translation_id_prefix]-[GLOB.translation_message_id]"

/**
 * Splits text into a list of individually renderable units.
 *
 * Two things make this more than splittext():
 * - BYOND indexes strings by byte. text[i] returns the whole UTF-8 character
 *   and length(char) gives its byte width, so we step by that. Cyrillic is
 *   two bytes and would otherwise be torn in half.
 * - Chat text has already been html_encode()'d, so it contains entities like
 *   &#34; and &amp;. Those have to travel as one unit or a half-written
 *   entity ends up in the middle of an animation frame.
 */
/proc/translation_charlist(text)
	var/list/units = list()
	var/text_length = length(text)
	var/i = 1
	while(i <= text_length)
		var/char = text[i]
		var/char_length = length(char)
		if(char == "&")
			var/entity = char
			var/scan = i + char_length
			var/terminated = FALSE
			// Entities are short. If we do not find a ';' quickly it was a
			// bare ampersand and we treat it as an ordinary character.
			while(scan <= text_length && length(entity) <= 12)
				var/next_char = text[scan]
				entity += next_char
				scan += length(next_char)
				if(next_char == ";")
					terminated = TRUE
					break
				if(next_char == " ")
					break
			if(terminated)
				units += entity
				i = scan
				continue
		units += char
		i += char_length
	return units

/**
 * TRUE if the text contains any multi-byte character.
 *
 * For a Russian <-> English deployment this is an exact proxy for "contains
 * Cyrillic": ASCII is one byte, Cyrillic is two. If you ever add a third
 * language this needs to become a real script check.
 */
/proc/text_has_non_ascii(text)
	var/text_length = length(text)
	var/i = 1
	while(i <= text_length)
		var/char = text[i]
		var/char_length = length(char)
		if(char_length > 1)
			return TRUE
		i += char_length
	return FALSE

/**
 * Wraps the spoken portion of a message so the chat panel can find it later.
 *
 * Call this on the raw message before it goes through compose_message(). The
 * span survives into the final chat HTML, and runechat strips spans anyway so
 * it does not disturb the maptext path.
 *
 * The title attribute gives a native tooltip; the tsl-pending-text class
 * carries the dotted underline and the trailing tsl-pending span animates the
 * dots. All three are cleared by the panel when the translation lands.
 *
 * DO NOT put _ + | or ^ in this markup. compose_message() runs
 * apply_message_emphasis() over the result, and those four characters are
 * emphasis delimiters. A single underscore in a class name will happily pair
 * with an underscore the player typed in their message and wrap a <u> across
 * the span boundary, producing broken HTML. Hyphens only.
 */
/proc/wrap_translatable(text, id)
	return "<span class='translatable tsl-pending-text' data-tsl-id='[id]' title='Awaiting translation...'>[text]</span><span class='tsl-pending' data-tsl-for='[id]'></span>"

// -----------------------------------------------------------------------------
// Language codes
//
// Only two, deliberately. Adding a third means text_has_non_ascii() is no
// longer a valid source-language detector and you need a real one.
// -----------------------------------------------------------------------------

#define AUTOTRANSLATE_LANG_EN "en"
#define AUTOTRANSLATE_LANG_RU "ru"

/// Preference values, as shown in the UI.
#define AUTOTRANSLATE_PREF_OFF "Off"
#define AUTOTRANSLATE_PREF_ENGLISH "Translate to English"
#define AUTOTRANSLATE_PREF_RUSSIAN "Translate to Russian"

/// Maps a preference value to the language code to translate into, or null
/// if the player has it switched off.
/proc/autotranslate_pref_to_code(pref_value)
	switch(pref_value)
		if(AUTOTRANSLATE_PREF_ENGLISH)
			return AUTOTRANSLATE_LANG_EN
		if(AUTOTRANSLATE_PREF_RUSSIAN)
			return AUTOTRANSLATE_LANG_RU
	return null

/**
 * Guesses which of our two languages a message is in.
 *
 * Cyrillic is multi-byte in UTF-8 and ASCII is not, so for a strictly RU/EN
 * deployment this is exact rather than probabilistic. It does not catch
 * translit (Russian typed in Latin characters), which is common enough among
 * Russian players to be worth knowing about but not worth guessing at.
 */
/proc/autotranslate_detect_language(text)
	return text_has_non_ascii(text) ? AUTOTRANSLATE_LANG_RU : AUTOTRANSLATE_LANG_EN

/// generate_image() is asynchronous and defers itself onto SSrunechat under
/// load, so a freshly created bubble may not have rendered text yet. These
/// bound how long we keep trying to bind to one before giving up.
#define TRANSLATION_BIND_MAX_ATTEMPTS 10
#define TRANSLATION_BIND_RETRY_INTERVAL (0.1 SECONDS)

// -----------------------------------------------------------------------------
// Runechat read time
//
// A translated bubble shows text the viewer has not read before, arriving with
// part of its five second lifespan already burned on the backend round trip.
// It gets time added back, scaled to how much there is to read.
// -----------------------------------------------------------------------------

/// How long to fade back in if the bubble had already started disappearing.
#define TRANSLATION_RUNECHAT_RECOVER_TIME (0.2 SECONDS)
/// Deciseconds granted per character. ~15 characters a second.
#define TRANSLATION_READ_TIME_PER_CHAR 0.66
/// Even a two word translation gets a moment.
#define TRANSLATION_READ_TIME_MIN (2 SECONDS)
/// Ceiling, so one very long line cannot park a bubble on screen forever.
#define TRANSLATION_READ_TIME_MAX (6 SECONDS)

/// Extra runechat time to grant for a translation of this length.
/proc/translation_read_time(text)
	return clamp(
		length_char(text) * TRANSLATION_READ_TIME_PER_CHAR,
		TRANSLATION_READ_TIME_MIN,
		TRANSLATION_READ_TIME_MAX,
	)
