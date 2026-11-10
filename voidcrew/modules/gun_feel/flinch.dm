// Hit flinch: a mob taking brute or burn damage from an attack jolts a few pixels along the blow and
// springs back. After Shiptest's shake_animation() in apply_damage(), but it only moves pixel_w and
// pixel_z, as a relative parallel animation that adds up to zero, the same way tg's shake_up_animation()
// works. So it never touches transform (lying down, size) and never stops or shifts any other animation.

/mob/living
	/// No new flinch starts until this world.time, so automatic fire never stacks them.
	COOLDOWN_DECLARE(gun_feel_flinch_cooldown)

/mob/living/apply_damage(
	damage = 0,
	damagetype = BRUTE,
	def_zone = null,
	blocked = 0,
	forced = FALSE,
	spread_damage = FALSE,
	wound_bonus = 0,
	exposed_wound_bonus = 0,
	sharpness = NONE,
	attack_direction = null,
	attacking_item,
	wound_clothing = TRUE,
)
	. = ..()
	// Only blows: something hit us, or came from a direction. Fire, cold and the like don't flinch.
	if(. > 0 && (damagetype == BRUTE || damagetype == BURN) && (attacking_item || attack_direction))
		gun_feel_flinch(GUN_FEEL_FLINCH_BASE + . * GUN_FEEL_FLINCH_PER_DAMAGE, attack_direction)

/**
 * Jolts this mob's sprite a few pixels and lets it spring back.
 *
 * Arguments:
 * * strength - pixels, rounded and capped at GUN_FEEL_FLINCH_MAX
 * * push_dir - direction to jolt towards (the way the blow was travelling). Null picks a side.
 *
 * Returns TRUE if a flinch started.
 */
/mob/living/proc/gun_feel_flinch(strength, push_dir)
	if(stat == DEAD || !isturf(loc) || !COOLDOWN_FINISHED(src, gun_feel_flinch_cooldown))
		return FALSE
	var/pixels = clamp(round(strength, 1), 1, GUN_FEEL_FLINCH_MAX)
	var/sign_x = 0
	var/sign_y = 0
	if(push_dir & EAST)
		sign_x = 1
	else if(push_dir & WEST)
		sign_x = -1
	if(push_dir & NORTH)
		sign_y = 1
	else if(push_dir & SOUTH)
		sign_y = -1
	if(!sign_x && !sign_y)
		sign_x = pick(-1, 1)
	var/shift_w = sign_x * pixels
	var/shift_z = sign_y * max(1, round(pixels * GUN_FEEL_FLINCH_VERTICAL, 1))
	COOLDOWN_START(src, gun_feel_flinch_cooldown, GUN_FEEL_FLINCH_COOLDOWN)
	animate(src, pixel_w = shift_w, pixel_z = shift_z, time = GUN_FEEL_FLINCH_OUT_TIME, easing = QUAD_EASING | EASE_OUT, flags = ANIMATION_PARALLEL | ANIMATION_RELATIVE)
	animate(pixel_w = -shift_w, pixel_z = -shift_z, time = GUN_FEEL_FLINCH_BACK_TIME, easing = ELASTIC_EASING | EASE_OUT, flags = ANIMATION_RELATIVE)
	return TRUE
