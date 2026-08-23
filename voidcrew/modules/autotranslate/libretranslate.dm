/**
 * # LibreTranslate provider
 *
 * Talks to a LibreTranslate-compatible HTTP endpoint over rustg's async HTTP,
 * which does its work on rustg's own threads - the game loop never blocks on
 * a translation.
 *
 * Wire contract (LibreTranslate's own, so a stock container satisfies it):
 *
 *   POST /translate  {"q": "...", "source": "ru", "target": "en", "format": "text"}
 *                 -> {"translatedText": "..."}
 *   GET  /languages -> [{"code": "en", "targets": ["ru", ...]}, ...]
 *
 * Point it at 127.0.0.1 - there is no reason for this to be reachable from
 * anywhere else, and it has no meaningful authentication.
 */
/datum/translation_provider/libretranslate
	name = "LibreTranslate"
	/// Base URL, no trailing slash. e.g. "http://127.0.0.1:5000"
	var/endpoint
	/// Optional, only if the instance was started with key requirements on.
	var/api_key
	/// Per-request timeout handed to rustg.
	var/timeout_seconds = 5
	/// Set by probe(). Until this is TRUE the provider reports unavailable and
	/// nothing ever shows a pending indicator.
	var/available = FALSE
	/// Language code -> list of codes it can translate into, from /languages.
	var/list/supported_targets = list()

/datum/translation_provider/libretranslate/New(endpoint, api_key, timeout_seconds)
	. = ..()
	if(!isnull(endpoint))
		src.endpoint = endpoint
	if(!isnull(api_key))
		src.api_key = api_key
	if(!isnull(timeout_seconds))
		src.timeout_seconds = timeout_seconds

/datum/translation_provider/libretranslate/is_available()
	return available && !isnull(endpoint)

/datum/translation_provider/libretranslate/supports(source_language, target_language)
	var/list/targets = supported_targets[source_language]
	if(!islist(targets))
		return FALSE
	return (target_language in targets)

/**
 * Blocking capability probe. Only call during subsystem init - it parks the
 * game loop for up to timeout_seconds, which is fine at world startup and is
 * the same thing SStts does.
 *
 * Returns TRUE if the endpoint answered and advertised at least one language.
 */
/datum/translation_provider/libretranslate/proc/probe()
	available = FALSE
	supported_targets = list()
	if(!endpoint)
		return FALSE

	var/datum/http_request/request = new()
	request.prepare(RUSTG_HTTP_METHOD_GET, "[endpoint]/languages", "", build_headers(), timeout_seconds = timeout_seconds)
	request.begin_async()
	UNTIL(request.is_complete())

	var/datum/http_response/response = request.into_response()
	if(response.errored || response.status_code != 200)
		log_world("SSautotranslate: LibreTranslate probe failed - [response.error || "HTTP [response.status_code]"]")
		return FALSE

	var/list/languages
	try
		languages = json_decode(response.body)
	catch
		log_world("SSautotranslate: LibreTranslate returned unparseable /languages")
		return FALSE

	if(!islist(languages) || !length(languages))
		return FALSE

	for(var/list/entry as anything in languages)
		var/code = entry["code"]
		if(isnull(code))
			continue
		supported_targets[code] = entry["targets"] || list()

	available = TRUE
	log_world("SSautotranslate: LibreTranslate ready at [endpoint], [length(supported_targets)] language\s")
	return TRUE

/datum/translation_provider/libretranslate/proc/build_headers()
	var/list/headers = list("Content-Type" = "application/json")
	return headers

/datum/translation_provider/libretranslate/begin(datum/translation_request/request)
	var/list/body = list(
		// The say pipeline hands us html-encoded text. Entities have to be
		// resolved before they go to a translator or it will happily translate
		// "&#34;" as literal text and hand back something unusable.
		"q" = html_decode(request.source_text),
		"source" = request.source_language,
		"target" = request.target_language,
		"format" = "text",
	)
	if(api_key)
		body["api_key"] = api_key

	var/datum/http_request/http = new()
	http.prepare(RUSTG_HTTP_METHOD_POST, "[endpoint]/translate", json_encode(body), build_headers(), timeout_seconds = timeout_seconds)
	http.begin_async()
	request.provider_state = http

/datum/translation_provider/libretranslate/poll(datum/translation_request/request)
	var/datum/http_request/http = request.provider_state
	if(isnull(http))
		request.fail("no request object")
		return TRUE
	if(!http.is_complete())
		return FALSE

	var/datum/http_response/response = http.into_response()
	if(response.errored)
		request.fail(response.error)
		return TRUE
	if(response.status_code != 200)
		request.fail("HTTP [response.status_code]")
		return TRUE

	var/list/decoded
	try
		decoded = json_decode(response.body)
	catch
		request.fail("unparseable response body")
		return TRUE

	var/translated = decoded?["translatedText"]
	if(!istext(translated) || !length(translated))
		request.fail("no translatedText in response")
		return TRUE

	// Back into the encoding the rest of the chat pipeline expects.
	request.succeed(html_encode(translated))
	return TRUE

/datum/translation_provider/libretranslate/abort(datum/translation_request/request)
	// rustg owns the in-flight job and will drop the result on the floor once
	// nothing reads it. Just release our handle.
	request.provider_state = null
