// Voidcrew extensions to code/modules/mob/mob.dm.

/**
 * Allows item interactions in soft crit without ignoring other incapacitation sources.
 * Adapted from MonkeStation: dwasint's original crit item use and action slowdown,
 * https://github.com/Monkestation/Monkestation2.0/commit/232ff2ce43dafbb9a8501a618088addd4431e97f
 * https://github.com/Monkestation/Monkestation2.0/commit/0254a94c43bc36c6d88252caa3dc98789649ab9d
 * with SirNightKnight's source-aware checks (PR #8791) and Xander3359's hard-crit restriction (PR #8709).
 * https://github.com/Monkestation/Monkestation2.0/pull/8791
 * https://github.com/Monkestation/Monkestation2.0/pull/8709
 */
/mob/proc/incapacitated_except_softcrit(ignore_flags = NONE)
	// Check sources live: adding a stun while STAT_TRAIT is present does not emit another trait-gain signal.
	if(stat == SOFT_CRIT && HAS_TRAIT_FROM_ONLY(src, TRAIT_INCAPACITATED, STAT_TRAIT))
		ignore_flags |= TRADITIONAL_INCAPACITATED
	return INCAPACITATED_IGNORING(src, ignore_flags)
