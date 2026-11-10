/**
 * # Tutorial highlights
 *
 * Outlines, for one viewer, the objects their open tutorial item points at.
 *
 * Inputs: SSvc_tutorials.selected[ckey] (the item open in the panel, set by its "select"
 * action), each step's highlight_types, SSvc_tutorials.progress (done steps), and the
 * tutorial_highlights preference.
 */

/**
 * Rebuilds the viewer's tutorial highlights. Called when the panel opens or closes, when
 * the viewer selects an item, when the highlight preference changes, and when a step is
 * credited to them.
 *
 * Stub: the highlight rendering is not built yet. It must stay cheap and safe to call
 * for any mob, including ghosts and mobs with no client.
 */
/proc/tutorial_refresh_highlights(mob/user)
	return
