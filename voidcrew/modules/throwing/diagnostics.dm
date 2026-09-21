/// VOIDCREW: number of /datum/thrownthing instances currently alive (created and not yet destroyed).
/// Compared against length(SSthrowing.processing) this exposes throws that outlived their queue entry.
GLOBAL_VAR_INIT(thrownthing_alive, 0)

