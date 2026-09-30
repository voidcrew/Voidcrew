/// Picks tests at world start from world.params, so one test build can be split across several
/// isolated worlds at once. Every param is optional; with none set every test runs.
///   test_only  - comma separated type path prefixes; only matching tests run
///   test_skip  - comma separated type path prefixes; matching tests are skipped
///   test_shard - "k/n"; tests that walk a long list (every_ship) take every nth entry from k
/proc/voidcrew_select_unit_tests(list/tests)
	var/list/only = splittext(world.params["test_only"] || "", ",")
	var/list/skip = splittext(world.params["test_skip"] || "", ",")
	only -= ""
	skip -= ""
	if(!length(only) && !length(skip))
		return tests
	var/list/selected = list()
	for(var/test_type in tests)
		var/path_text = "[test_type]"
		if(length(only) && !voidcrew_test_path_matches(path_text, only))
			continue
		if(length(skip) && voidcrew_test_path_matches(path_text, skip))
			continue
		selected += test_type
	return selected

/proc/voidcrew_test_path_matches(path_text, list/prefixes)
	for(var/prefix in prefixes)
		if(path_text == prefix || findtext(path_text, "[prefix]/", 1, length(prefix) + 2))
			return TRUE
	return FALSE

/// Whether the entry at this 1-based position belongs to this world's shard.
/proc/voidcrew_test_shard_takes(position)
	var/list/shard = splittext(world.params["test_shard"] || "", "/")
	if(length(shard) != 2)
		return TRUE
	var/index = text2num(shard[1])
	var/count = text2num(shard[2])
	if(!index || !count)
		return TRUE
	return (position - 1) % count == index - 1
