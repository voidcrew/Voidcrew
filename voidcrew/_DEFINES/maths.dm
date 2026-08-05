#define MAGNITUDE(a, b) (sqrt(a ** 2 + b ** 2))

/// The 2026 upstream merge deleted tg's SIGN() macro; this is its old body.
/// Lives here rather than beside its first user because both ship.dm and
/// ship_autopilot.dm need it, and ship.dm is included first.
#define SIGN(x) (((x) > 0) - ((x) < 0))
