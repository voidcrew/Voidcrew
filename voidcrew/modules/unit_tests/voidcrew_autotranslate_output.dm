/// Translation filtering uses server configuration and preserves original speech.
/datum/unit_test/voidcrew_autotranslate_output
	var/regex/previous_filter
	var/filter_saved = FALSE

/datum/unit_test/voidcrew_autotranslate_output/Destroy()
	if(filter_saved)
		SSautotranslate.english_output_filter = previous_filter
	return ..()

/datum/unit_test/voidcrew_autotranslate_output/Run()
	previous_filter = SSautotranslate.english_output_filter
	filter_saved = TRUE
	// Harmless fixtures exercise the same configuration compiler as production.
	SSautotranslate.english_output_filter = config.compile_filter_regex(list("blockedexample", "blockedexamples"))
	var/datum/translation_request/request = allocate(/datum/translation_request, "test", "Original speech", "ru", "en")
	request.succeed("A blockedexample appeared.")
	TEST_ASSERT(request.errored, "A configured blocked word was accepted")
	TEST_ASSERT_NULL(request.result, "Rejected output remained available to the cache or listeners")
	TEST_ASSERT_EQUAL(request.source_text, "Original speech", "Rejecting a translation changed the original speech")

	request.succeed("An ordinary translation.")
	TEST_ASSERT(!request.errored, "An ordinary translation was rejected")
	TEST_ASSERT_EQUAL(request.result, "An ordinary translation.", "An ordinary translation was changed")
	request.succeed("a BLOCKEDEXAMPLE&#39;s words")
	TEST_ASSERT(request.errored, "Capitalization or HTML encoding bypassed rejection")
	TEST_ASSERT_NULL(request.result, "A failed retry retained an earlier successful result")
	request.succeed("blocked&#101;xample")
	TEST_ASSERT(request.errored, "An encoded blocked word reached the display")
	request.succeed("blockedexamples")
	TEST_ASSERT(request.errored, "A configured plural was accepted")
	request.succeed("unblockedexample, blockedexamplemore")
	TEST_ASSERT(!request.errored, "Unrelated words were rejected by a substring match")
	request.succeed("   ")
	TEST_ASSERT(request.errored, "Whitespace-only output was accepted")

	request.source_text = "Original blockedexample"
	request.succeed("blockedexample")
	TEST_ASSERT(request.errored, "A blocked translation should fall back to original speech")
	TEST_ASSERT_EQUAL(request.source_text, "Original blockedexample", "Original evidence was changed")

	request.target_language = "ru"
	request.succeed("blockedexample")
	TEST_ASSERT(!request.errored, "The English word filter was applied to another target language")
	request.target_language = "en"
	SSautotranslate.english_output_filter = null
	request.succeed("blockedexample")
	TEST_ASSERT(!request.errored, "An empty blocklist rejected a translation")
