/**
 * # SSautotranslate
 *
 * Owns the translation provider, deduplicates identical requests, caches
 * results, and polls in-flight work.
 *
 * Deduplication matters more than it looks. A say is heard by every player in
 * range, and every one of them who wants it translated would otherwise
 * generate an identical request. Requests are keyed on
 * (source language, target language, text) so a line said in a crowded room
 * costs exactly one backend call regardless of how many people heard it.
 *
 * The cache is in-memory and dies with the round. Persisting it across rounds
 * is the single biggest cost saving available and is left as a follow-up -
 * see save_cache()/load_cache() stubs at the bottom.
 */
SUBSYSTEM_DEF(autotranslate)
	name = "Auto Translate"
	wait = 0.1 SECONDS
	priority = FIRE_PRIORITY_CHAT
	runlevels = RUNLEVEL_LOBBY | RUNLEVEL_SETUP | RUNLEVEL_GAME | RUNLEVEL_POSTGAME

	/// The active backend. Never null after Initialize().
	var/datum/translation_provider/provider

	/// Requests currently out with the provider.
	var/list/datum/translation_request/active_requests = list()
	/// Cache key -> in-flight request, so duplicates can subscribe instead of
	/// dispatching again.
	var/list/datum/translation_request/requests_by_key = list()
	/// Cache key -> translated text.
	var/list/translation_cache = list()

	/// Evict oldest entries once the cache passes this.
	var/max_cache_entries = 5000

	var/cache_hits = 0
	var/cache_misses = 0
	var/requests_dispatched = 0
	var/requests_failed = 0
	var/requests_deduplicated = 0
	/// Translation notices actually handed to a chat panel.
	var/chat_updates_sent = 0
	/// Notices we could not deliver because the listener had no panel window.
	/// If this is climbing while runechat works, that is your culprit.
	var/chat_updates_dropped = 0

/datum/controller/subsystem/autotranslate/Initialize()
	// No configured endpoint means the feature stays completely inert: no
	// pending indicators, no requests, no cost.
	var/endpoint = CONFIG_GET(string/translate_http_url)
	if(!endpoint)
		provider = new /datum/translation_provider/none()
		return SS_INIT_NO_NEED

	var/datum/translation_provider/libretranslate/backend = new(
		endpoint,
		CONFIG_GET(string/translate_http_token),
		CONFIG_GET(number/translate_http_timeout_seconds),
	)

	// Blocking, but only here at startup. If it fails we fall back to the
	// null provider rather than timing out on every line for the whole round.
	if(!backend.probe())
		log_world("SSautotranslate: endpoint [endpoint] did not answer, translation disabled for this round")
		provider = new /datum/translation_provider/none()
		return SS_INIT_SUCCESS

	provider = backend
	return SS_INIT_SUCCESS

/datum/controller/subsystem/autotranslate/stat_entry(msg)
	msg = "\n  Provider:[provider?.name || "none"]|Active:[length(active_requests)]|Cached:[length(translation_cache)]|Hits:[cache_hits]|Miss:[cache_misses]"
	return ..()

/// Swaps the backend. Any in-flight work against the old provider is aborted.
/datum/controller/subsystem/autotranslate/proc/set_provider(datum/translation_provider/new_provider)
	if(isnull(new_provider))
		return FALSE
	for(var/datum/translation_request/request as anything in active_requests)
		provider?.abort(request)
		resolve(request, null, FALSE)
	active_requests.Cut()
	requests_by_key.Cut()
	provider = new_provider
	log_world("SSautotranslate: provider set to [new_provider.name]")
	return TRUE

/// TRUE if a translation could plausibly be produced for this direction.
/// Callers should check this before showing a pending indicator - there is no
/// point promising a translation that is never coming.
/datum/controller/subsystem/autotranslate/proc/can_translate(source_language, target_language)
	if(isnull(provider) || !provider.is_available())
		return FALSE
	if(source_language == target_language)
		return FALSE
	return provider.supports(source_language, target_language)

/datum/controller/subsystem/autotranslate/proc/build_key(text, source_language, target_language)
	return "[source_language]|[target_language]|[text]"

/**
 * The entry point.
 *
 * on_result is invoked as (translated_text, success). On failure
 * translated_text is null and the caller should leave the original in place.
 *
 * Returns TRUE if the callback will be invoked (now or later), FALSE if the
 * request was rejected outright, in which case the callback never fires.
 *
 * Note that a cache hit invokes the callback synchronously, before this proc
 * returns. Callers that attach to a chat message must therefore be fully
 * constructed before calling this.
 */
/datum/controller/subsystem/autotranslate/proc/request_translation(text, source_language, target_language, datum/callback/on_result)
	if(!istext(text) || !length(text))
		return FALSE
	if(isnull(on_result))
		return FALSE
	if(!can_translate(source_language, target_language))
		return FALSE

	var/key = build_key(text, source_language, target_language)

	var/cached = translation_cache[key]
	if(!isnull(cached))
		cache_hits++
		on_result.Invoke(cached, TRUE)
		return TRUE

	cache_misses++

	var/datum/translation_request/existing = requests_by_key[key]
	if(!isnull(existing))
		// Somebody else already asked for exactly this. Ride along.
		requests_deduplicated++
		existing.subscribers += on_result
		return TRUE

	var/datum/translation_request/request = new(key, text, source_language, target_language)
	request.subscribers += on_result
	request.started_at = world.time
	requests_by_key[key] = request
	active_requests += request
	requests_dispatched++
	provider.begin(request)
	return TRUE

/datum/controller/subsystem/autotranslate/fire(resumed)
	if(!length(active_requests))
		return

	// Collect first, mutate after. Removing entries from the list being walked
	// makes DM skip the following element, and resolve() runs consumer
	// callbacks that can touch the subsystem again.
	var/list/datum/translation_request/finished = list()

	for(var/datum/translation_request/request as anything in active_requests)
		if(world.time > request.started_at + TRANSLATION_REQUEST_TIMEOUT)
			provider?.abort(request)
			request.fail("timed out")
			finished += request
		else if(provider.poll(request))
			finished += request

		if(MC_TICK_CHECK)
			break

	for(var/datum/translation_request/request as anything in finished)
		active_requests -= request
		requests_by_key -= request.key

		if(request.errored)
			requests_failed++
			resolve(request, null, FALSE)
		else
			store_in_cache(request.key, request.result)
			resolve(request, request.result, TRUE)

		qdel(request)

/// Fans a finished request out to everybody who subscribed to it.
/datum/controller/subsystem/autotranslate/proc/resolve(datum/translation_request/request, result, success)
	for(var/datum/callback/subscriber as anything in request.subscribers)
		subscriber.Invoke(result, success)
	request.subscribers?.Cut()

/datum/controller/subsystem/autotranslate/proc/store_in_cache(key, value)
	if(isnull(value))
		return
	translation_cache[key] = value
	if(length(translation_cache) > max_cache_entries)
		// Cheap eviction: drop the oldest half rather than tracking usage.
		translation_cache.Cut(1, round(max_cache_entries * 0.5))

/// Wipes the cache. Exposed for admins and for provider swaps.
/datum/controller/subsystem/autotranslate/proc/clear_cache()
	var/cleared = length(translation_cache)
	translation_cache.Cut()
	return cleared

/**
 * TODO: persist the cache between rounds.
 *
 * SS13 chat repeats heavily - names, department callouts, "code red". A warm
 * on-disk cache is worth more than any backend tuning. Left unimplemented so
 * this module stays free of storage decisions.
 */
/datum/controller/subsystem/autotranslate/proc/save_cache(path)
	return FALSE

/datum/controller/subsystem/autotranslate/proc/load_cache(path)
	return FALSE
