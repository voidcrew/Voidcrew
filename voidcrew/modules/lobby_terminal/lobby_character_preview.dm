/**
 * # Dock terminal: CHARACTER preview (package C2)
 *
 * Server-rendered PNGs of the dressed mannequin, one facing at a time, cached by appearance
 * key and pushed as one-off char_preview updates. Overrides char_preview_request() and
 * char_appearance_key() from _lobby_terminal.dm, and owns char_preview_cache, the render
 * queue and its time budget, and the dress table built from the roundstart job pool.
 *
 * Flow: char_preview_request(dir) pushes a cached facing at once, or queues one render of
 * the facing on screen. After LOBBY_CHAR_IDLE_FILL with no new request, the other three
 * facings are queued at low priority, so turning is instant afterwards. Every finished
 * facing of the current look is pushed; the client keeps them and turns locally.
 *
 * DoS guard: one global queue with one entry per terminal (a new request replaces the old
 * one, so spam collapses to the latest look), one worker rendering one facing per pass,
 * at most LOBBY_CHAR_TERMINAL_RENDERS renders a second per terminal and a global budget of
 * LOBBY_CHAR_BUDGET_MS of render time per second. Renders read only the terminal owner's
 * own prefs; no action names another player.
 *
 * Render: the dummy is dressed and flattened into a /datum/universal_icon tree
 * (get_flat_uni_icon), then rust-g iconforge composites it off the main thread and the PNG
 * is read back as base64 and deleted. Measured: about 30 ms of main thread a facing, against
 * about 65 ms for getFlatIcon(), with the same pixels.
 *
 * Memory: nothing goes into the RSC and nothing is registered with SSassets. Each terminal keeps the last LOBBY_CHAR_CACHE_LOOKS looks, four
 * facings each (about 1-2 KB a facing).
 *
 * Compile with -DLOBBY_CHAR_PREVIEW_DEBUG for the timing log and the headless benchmark.
 */

/// Human dummy slot the preview renders on. Only the worker uses it, so it is never busy.
#define LOBBY_CHAR_DUMMY "lobby_char"
/// Looks (appearance keys) cached per terminal, four facings each.
#define LOBBY_CHAR_CACHE_LOOKS 6
/// Idle time before the other three facings are rendered.
#define LOBBY_CHAR_IDLE_FILL (1.5 SECONDS)
/// Renders a second one terminal may cause.
#define LOBBY_CHAR_TERMINAL_RENDERS 2
/// Render time (ms) the worker may spend in any one second, over every terminal.
#define LOBBY_CHAR_BUDGET_MS 80
/// A worker that hasn't finished a pass for this long is taken as dead and replaced.
#define LOBBY_CHAR_WORKER_STALE (10 SECONDS)
/// Where rust-g writes each render before it is read back as base64 and deleted.
#define LOBBY_CHAR_FORGE_DIR "data/lobby_char/"

/// Terminals waiting on renders: terminal -> list of dirs, the first rendered first.
GLOBAL_LIST_EMPTY(lobby_char_render_queue)
/// Render time spent recently: list(list(world.time, ms), ...), oldest first.
GLOBAL_LIST_EMPTY(lobby_char_render_spend)
/// world.time of the worker's last pass; 0 when no worker runs.
GLOBAL_VAR_INIT(lobby_char_worker_beat, 0)
/// TRUE while a render holds the dummy. Still TRUE at the next render means the last one runtimed.
GLOBAL_VAR_INIT(lobby_char_rendering, FALSE)
/// Job category -> the /datum/job whose outfit the preview wears. Built once per round.
GLOBAL_LIST(lobby_char_dress_jobs)
/// Serial for render file names, so two renders never share a file.
GLOBAL_VAR_INIT(lobby_char_forge_serial, 0)

/datum/lobby_terminal
	/// Facing the client last asked for.
	var/char_preview_dir = SOUTH
	/// TRUE while the queued facing is the one on screen, so it goes before other terminals' idle fills.
	var/char_preview_urgent = FALSE
	/// world.time of this terminal's renders in the last second.
	var/list/char_preview_renders
	/// Timer for the idle fill of the other facings.
	var/char_preview_idle_timer

/datum/lobby_terminal/Destroy()
	GLOB.lobby_char_render_queue -= src
	if(char_preview_idle_timer)
		deltimer(char_preview_idle_timer)
		char_preview_idle_timer = null
	char_preview_cache = null
	return ..()

/// dir null means the facing asked for last (callers that only know the look changed).
/datum/lobby_terminal/char_preview_request(dir)
	if(isnull(dir))
		dir = char_preview_dir
	dir = text2num("[dir]")
	if(!(dir in GLOB.cardinals))
		return FALSE
	char_preview_dir = dir
	var/key = char_appearance_key()
	if(!key)
		return FALSE
	var/list/look = char_preview_cache?[key]
	var/png = look?["[dir]"]
	if(png)
		char_preview_touch(key)
		char_preview_send(key, dir, png)
	else
		// Replaces any older request from this terminal, idle fill included.
		GLOB.lobby_char_render_queue -= src
		GLOB.lobby_char_render_queue[src] = list(dir)
		char_preview_urgent = TRUE
		lobby_char_worker_start()
	char_preview_idle_timer = addtimer(CALLBACK(src, PROC_REF(char_preview_fill)), LOBBY_CHAR_IDLE_FILL, TIMER_UNIQUE|TIMER_OVERRIDE|TIMER_STOPPABLE)
	return TRUE

/datum/lobby_terminal/char_appearance_key()
	var/datum/preferences/prefs = owner?.prefs
	if(!prefs)
		return null
	var/static/list/skip_keys = list("age", "background", "pda_ringtone", "pda_theme", "uplink_loc")
	var/static/list/skip_prefixes = list("random_", "tts_", "bark_", "voice_")
	var/list/look = list()
	for(var/preference_type in GLOB.preference_entries)
		var/datum/preference/preference = GLOB.preference_entries[preference_type]
		if(preference.savefile_identifier != PREFERENCE_CHARACTER || istype(preference, /datum/preference/name))
			continue
		var/savefile_key = preference.savefile_key
		if(savefile_key in skip_keys)
			continue
		var/skipped = FALSE
		for(var/prefix in skip_prefixes)
			if(findtext(savefile_key, prefix) == 1)
				skipped = TRUE
				break
		if(skipped)
			continue
		look[savefile_key] = prefs.read_preference(preference_type)
	var/list/quirks = list()
	for(var/quirk_name in prefs.all_quirks)
		var/datum/quirk/quirk_type = SSquirks.quirks[quirk_name]
		if(quirk_type && (initial(quirk_type.quirk_flags) & QUIRK_CHANGES_APPEARANCE))
			quirks += quirk_name
	look["#quirks"] = quirks
	look["#dress"] = char_preview_category()
	return md5(json_encode(look))

/// The job category the mannequin wears (C1's resolver); Silicon wears Assistant.
/datum/lobby_terminal/proc/char_preview_category()
	var/category = char_resolved_dress(owner?.prefs)
	if(!(category in GLOB.job_categories) || category == JOB_CAT_SILICON)
		category = JOB_CAT_ASSISTANT
	return category

/// Queues the facings this look hasn't got yet, behind any facing already waiting.
/datum/lobby_terminal/proc/char_preview_fill()
	char_preview_idle_timer = null
	if(!ui || QDELETED(ui))
		return
	var/key = char_appearance_key()
	if(!key)
		return
	var/list/look = char_preview_cache?[key]
	var/list/wanted = GLOB.lobby_char_render_queue[src] || list()
	for(var/dir in GLOB.cardinals)
		if(!look?["[dir]"] && !(dir in wanted))
			wanted += dir
	if(!length(wanted))
		return
	GLOB.lobby_char_render_queue[src] = wanted
	lobby_char_worker_start()

/// Moves a look to the newest end of the LRU.
/datum/lobby_terminal/proc/char_preview_touch(key)
	var/list/look = char_preview_cache?[key]
	if(!look)
		return
	char_preview_cache -= key
	char_preview_cache[key] = look

/// Stores one facing, dropping the oldest looks past LOBBY_CHAR_CACHE_LOOKS.
/datum/lobby_terminal/proc/char_preview_store(key, dir, png)
	LAZYINITLIST(char_preview_cache)
	var/list/look = char_preview_cache[key] || list()
	look["[dir]"] = png
	char_preview_cache -= key
	char_preview_cache[key] = look
	while(length(char_preview_cache) > LOBBY_CHAR_CACHE_LOOKS)
		char_preview_cache.Cut(1, 2)

/datum/lobby_terminal/proc/char_preview_send(key, dir, png)
	if(!ui || QDELETED(ui))
		return
	ui.send_update(list("char_preview" = list("key" = key, "dir" = dir, "png" = png)))

/// TRUE when this terminal has render quota left this second.
/datum/lobby_terminal/proc/char_preview_quota()
	var/cutoff = world.time - 1 SECONDS
	while(length(char_preview_renders) && char_preview_renders[1] <= cutoff)
		char_preview_renders.Cut(1, 2)
	return length(char_preview_renders) < LOBBY_CHAR_TERMINAL_RENDERS

/// Renders one facing of the current look, caches it and pushes it if the look is still current.
/datum/lobby_terminal/proc/char_preview_render_one(dir)
	var/key = char_appearance_key()
	if(!key)
		return
	var/list/look = char_preview_cache?[key]
	if(look?["[dir]"])
		if(dir == char_preview_dir)
			char_preview_send(key, dir, look["[dir]"])
		return
	LAZYADD(char_preview_renders, world.time)
	var/list/timing = list()
	var/png = lobby_char_render(owner.prefs, char_preview_category(), dir, owner, timing)
	// Main-thread time only; the wait on rust-g is a sleep and costs the server nothing.
	var/cost = timing["setup"] + timing["flat"] + timing["queue"] + timing["b64"]
	GLOB.lobby_char_render_spend += list(list(world.time, cost))
#ifdef LOBBY_CHAR_PREVIEW_DEBUG
	log_world("LOBBY_CHAR_RENDER [owner?.ckey] dir=[dir] cost=[cost]ms setup=[timing["setup"]] flat=[timing["flat"]] queue=[timing["queue"]] wait=[timing["wait_ticks"]]t b64=[timing["b64"]] bytes=[length(png)]")
#endif
	if(!png || QDELETED(src))
		return
	char_preview_store(key, dir, png)
	// The look can change while the dummy is waited on; an old look is cached, never pushed.
	if(char_appearance_key() == key)
		char_preview_send(key, dir, png)

/// Render time (ms) spent in the last second, pruning older entries.
/proc/lobby_char_render_spent()
	var/cutoff = world.time - 1 SECONDS
	var/list/spend = GLOB.lobby_char_render_spend
	while(length(spend))
		var/list/oldest = spend[1]
		if(oldest[1] > cutoff)
			break
		spend.Cut(1, 2)
	. = 0
	for(var/list/entry as anything in spend)
		. += entry[2]

/// Starts the render worker unless a live one is already running.
/proc/lobby_char_worker_start()
	if(GLOB.lobby_char_worker_beat && world.time - GLOB.lobby_char_worker_beat < LOBBY_CHAR_WORKER_STALE)
		return
	GLOB.lobby_char_worker_beat = world.time
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(lobby_char_worker))

/// Renders one queued facing per pass until the queue is empty, inside the budgets.
/proc/lobby_char_worker()
	var/list/queue = GLOB.lobby_char_render_queue
	while(length(queue))
		GLOB.lobby_char_worker_beat = world.time
		if(SSatoms.initialized != INITIALIZATION_INNEW_REGULAR || lobby_char_render_spent() >= LOBBY_CHAR_BUDGET_MS)
			sleep(1)
			continue
		// The facing on screen goes first; then round-robin over idle fills.
		var/datum/lobby_terminal/next
		for(var/urgent_pass in list(TRUE, FALSE))
			for(var/datum/lobby_terminal/terminal as anything in queue.Copy())
				if(QDELETED(terminal) || !terminal.owner?.prefs || !terminal.ui || QDELETED(terminal.ui))
					queue -= terminal
					continue
				if(urgent_pass && !terminal.char_preview_urgent)
					continue
				if(terminal.char_preview_quota())
					next = terminal
					break
			if(next)
				break
		if(!next)
			sleep(1)
			continue
		var/list/dirs = queue[next]
		var/dir = dirs[1]
		dirs.Cut(1, 2)
		next.char_preview_urgent = FALSE
		queue -= next
		if(length(dirs))
			queue[next] = dirs // to the back of the line
		next.char_preview_render_one(dir)
		stoplag()
	GLOB.lobby_char_worker_beat = 0

/// The job whose outfit a category wears: its most common outfit in the roundstart job pool (C1's lobby_char_job_pool()).
/proc/lobby_char_dress_job(category)
	if(isnull(GLOB.lobby_char_dress_jobs))
		var/list/slots_by_outfit = list() // category -> outfit -> slots
		var/list/job_by_outfit = list() // "[category]|[outfit]" -> job
		for(var/datum/job/job as anything in lobby_char_job_pool())
			var/job_category = job.job_category
			if(job.ship_role != "crew" || !job_category || job_category == JOB_CAT_SILICON || !ispath(job.outfit, /datum/outfit))
				continue
			var/list/by_outfit = slots_by_outfit[job_category]
			if(!by_outfit)
				by_outfit = list()
				slots_by_outfit[job_category] = by_outfit
			by_outfit[job.outfit] += 1
			if(!job_by_outfit["[job_category]|[job.outfit]"])
				job_by_outfit["[job_category]|[job.outfit]"] = job
		var/list/dress = list()
		for(var/job_category in slots_by_outfit)
			var/list/by_outfit = slots_by_outfit[job_category]
			var/best_outfit
			for(var/outfit in by_outfit)
				if(!best_outfit || by_outfit[outfit] > by_outfit[best_outfit])
					best_outfit = outfit
			dress[job_category] = job_by_outfit["[job_category]|[best_outfit]"]
		GLOB.lobby_char_dress_jobs = dress
	return GLOB.lobby_char_dress_jobs[category] || GLOB.lobby_char_dress_jobs[JOB_CAT_ASSISTANT] || SSjob.get_job_type(/datum/job/unassigned)

/**
 * Renders prefs' character dressed for category, facing dir, as base64 PNG.
 * Same steps as render_new_preview_appearance(), but with the job picked by ship role
 * category (Voidcrew never sets job_preferences). timing, if given, gets setup/flat/b64 ms.
 */
/proc/lobby_char_render(datum/preferences/prefs, category, dir, client/player, list/timing)
	if(!prefs)
		return null
	var/start = TICK_USAGE_REAL
	var/mob/living/carbon/human/dummy/mannequin = lobby_char_dress(prefs, category, player)
	if(timing)
		timing["setup"] = TICK_USAGE_TO_MS(start)
	start = TICK_USAGE_REAL
	var/datum/universal_icon/flat = get_flat_uni_icon(mannequin, dir)
	if(timing)
		timing["flat"] = TICK_USAGE_TO_MS(start)
	unset_busy_human_dummy(LOBBY_CHAR_DUMMY)
	GLOB.lobby_char_rendering = FALSE
	// rust-g composites off the main thread; the worker only waits on it.
	start = TICK_USAGE_REAL
	if(!fexists(LOBBY_CHAR_FORGE_DIR)) // rust-g won't make the folder
		text2file("", "[LOBBY_CHAR_FORGE_DIR].keep")
	var/sheet = "lobby_char_[++GLOB.lobby_char_forge_serial % 16]"
	var/entries = json_encode(list("c" = flat.to_list()))
	var/job_id = rustg_iconforge_generate_async(LOBBY_CHAR_FORGE_DIR, sheet, entries, FALSE, FALSE, TRUE)
	if(timing)
		timing["queue"] = TICK_USAGE_TO_MS(start)
	var/waited_from = world.time
	var/data_out
	UNTIL((data_out = rustg_iconforge_check(job_id)) != RUSTG_JOB_NO_RESULTS_YET)
	if(timing)
		timing["wait_ticks"] = (world.time - waited_from) / world.tick_lag
	start = TICK_USAGE_REAL
	if(!findtext(data_out, "{", 1, 2))
		stack_trace("Lobby character preview render failed: [data_out]")
		return null
	var/list/data = json_decode(data_out)
	var/list/sizes = data["sizes"]
	if(!length(sizes))
		stack_trace("Lobby character preview render made no image: [data["error"]]")
		return null
	var/png_path = "[LOBBY_CHAR_FORGE_DIR][sheet]_[sizes[1]].png"
	. = rustg_hash_file(RUSTG_HASH_BASE64, png_path)
	fdel(png_path)
	if(!length(.))
		stack_trace("Lobby character preview render not read back: [data["error"]]")
		return null
	if(timing)
		timing["b64"] = TICK_USAGE_TO_MS(start)

/// Puts the shared dummy in prefs' character, dressed for category. Returns it busy; the caller releases it.
/proc/lobby_char_dress(datum/preferences/prefs, category, client/player)
	if(GLOB.lobby_char_rendering) // the last render runtimed while holding the dummy
		unset_busy_human_dummy(LOBBY_CHAR_DUMMY)
	var/datum/job/job = lobby_char_dress_job(category)
	var/mob/living/carbon/human/dummy/mannequin = generate_or_wait_for_human_dummy(LOBBY_CHAR_DUMMY)
	GLOB.lobby_char_rendering = TRUE
	prefs.apply_prefs_to(mannequin, TRUE)
	if(job)
		mannequin.job = job.title
		mannequin.dress_up_as_job(job, visual_only = TRUE, player_client = player, consistent = TRUE)
	if(SSquirks?.initialized)
		mannequin.cleanse_quirk_datums()
		for(var/quirk_name in prefs.all_quirks)
			var/datum/quirk/quirk_type = SSquirks.quirks[quirk_name]
			if(quirk_type && (initial(quirk_type.quirk_flags) & QUIRK_CHANGES_APPEARANCE))
				mannequin.add_quirk(quirk_type, player, announce = FALSE)
	return mannequin

#ifdef LOBBY_CHAR_PREVIEW_DEBUG
/// The plain DM way (getFlatIcon), kept for the benchmark's comparison only.
/proc/lobby_char_render_flat(datum/preferences/prefs, category, dir, client/player, list/timing)
	var/start = TICK_USAGE_REAL
	var/mob/living/carbon/human/dummy/mannequin = lobby_char_dress(prefs, category, player)
	timing["setup"] = TICK_USAGE_TO_MS(start)
	start = TICK_USAGE_REAL
	var/icon/flat = getFlatIcon(mannequin, dir, no_anim = TRUE)
	timing["flat"] = TICK_USAGE_TO_MS(start)
	unset_busy_human_dummy(LOBBY_CHAR_DUMMY)
	GLOB.lobby_char_rendering = FALSE
	start = TICK_USAGE_REAL
	. = icon2base64(flat)
	timing["b64"] = TICK_USAGE_TO_MS(start)

/datum/controller/subsystem/ticker/Initialize()
	. = ..()
	Master.sleep_offline_after_initializations = FALSE
	delay_end = TRUE
	INVOKE_ASYNC(GLOBAL_PROC, GLOBAL_PROC_REF(lobby_char_bench))

/// Headless benchmark: renders species x outfits x facings both ways, logs the cost per stage, writes the PNGs as base64 lines, then soaks.
/proc/lobby_char_bench()
	UNTIL(SSticker.current_state >= GAME_STATE_PREGAME)
	SSticker.SetTimeLeft(-1)
	sleep(5 SECONDS)
	var/out = "data/lobby_c2_bench/"
	fdel(out)
	var/datum/client_interface/mock = new
	var/datum/preferences/prefs = new(mock)
	mock.prefs = prefs
	var/datum/preference/species_pref = GLOB.preference_entries[/datum/preference/choiced/species]
	var/list/species = list(SPECIES_HUMAN, SPECIES_LIZARD, SPECIES_MOTH, SPECIES_FELINE, SPECIES_PLASMAMAN, SPECIES_ETHEREAL)
	var/list/categories = list(JOB_CAT_ENGINEERING, JOB_CAT_SECURITY, JOB_CAT_MEDICAL, JOB_CAT_ASSISTANT, JOB_CAT_COMMAND, JOB_CAT_CARGO)
	for(var/category in categories)
		var/datum/job/job = lobby_char_dress_job(category)
		text2file("DRESS [category] = [job?.title] [job?.outfit]", "[out]timing.txt")
	for(var/way in list("forge", "flat"))
		var/list/totals = list()
		var/count = 0
		for(var/species_id in species)
			prefs.write_preference(species_pref, species_id)
			var/first = TRUE
			for(var/category in categories)
				for(var/dir in GLOB.cardinals)
					var/list/timing = list()
					var/png = way == "forge" ? lobby_char_render(prefs, category, dir, mock, timing) : lobby_char_render_flat(prefs, category, dir, mock, timing)
					var/line = ""
					var/cost = 0
					for(var/stage in timing)
						line += " [stage]=[timing[stage]]"
						if(stage != "wait_ticks")
							cost += timing[stage]
					text2file("RENDER [way] [species_id] [category] dir=[dir] cost=[cost][line] bytes=[length(png)][first ? " COLD" : ""]", "[out]timing.txt")
					text2file("[way]_[species_id]_[category]_[dir]|[png]", "[out]pngs.txt")
					if(!first)
						timing["cost"] = cost
						for(var/stage in timing)
							totals[stage] += timing[stage]
						count++
					first = FALSE
					stoplag()
		var/mean = "WARM MEAN [way] over [count]:"
		for(var/stage in totals)
			mean += " [stage]=[totals[stage] / count]"
		text2file(mean, "[out]timing.txt")
	text2file("SOAK READY [world.timeofday]", "[out]timing.txt")
	sleep(30 SECONDS)
	text2file("SOAK START [world.timeofday]", "[out]timing.txt")
	var/soak_ms = 0
	for(var/i in 1 to 500)
		prefs.write_preference(species_pref, species[(i % length(species)) + 1])
		var/list/timing = list()
		lobby_char_render(prefs, categories[(i % length(categories)) + 1], GLOB.cardinals[(i % 4) + 1], mock, timing)
		soak_ms += timing["setup"] + timing["flat"] + timing["queue"] + timing["b64"]
		stoplag()
	text2file("SOAK END [world.timeofday] mean=[soak_ms / 500]", "[out]timing.txt")
	sleep(30 SECONDS)
	text2file("BENCH DONE", "[out]timing.txt")
#endif

#undef LOBBY_CHAR_DUMMY
#undef LOBBY_CHAR_CACHE_LOOKS
#undef LOBBY_CHAR_IDLE_FILL
#undef LOBBY_CHAR_TERMINAL_RENDERS
#undef LOBBY_CHAR_BUDGET_MS
#undef LOBBY_CHAR_WORKER_STALE
#undef LOBBY_CHAR_FORGE_DIR
