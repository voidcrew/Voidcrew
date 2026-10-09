//! vcphys: Box2D (through the pure Rust port box2d-rs) for Voidcrew's limb rig.
//!
//! Every Box2D object lives here, behind small integer handles. BYOND never sees the object graph:
//! it makes a world, puts bodies, box fixtures and revolute joints in it, steps it, reads back where
//! the bodies are, and pushes them about.
//!
//! # The boundary
//!
//! Every export is a classic BYOND `call_ext` function: text arguments in, text out,
//! `extern "C" fn(argc, argv) -> *const c_char`. That keeps it trivially debuggable (every call and
//! reply can be logged and read), and needs nothing linked from BYOND.
//!
//! Replies are one of:
//! - a handle or other value, as text
//! - `OK`
//! - `ERR:<what went wrong>` for bad arguments, unknown handles, or a caught panic
//!
//! Units are Box2D's own: metres, radians (counter-clockwise), kilograms, seconds. Converting to
//! pixels and BYOND's clockwise degrees is the caller's job.
//!
//! # Determinism
//!
//! Given the same sequence of calls, the results are the same: stepping only ever uses the time step
//! it's given, bodies are kept in handle order (`BTreeMap`), and nothing reads a clock or a random
//! source. (Floating point makes no promises across different CPUs or compilers.)
//!
//! # Threading
//!
//! BYOND calls `call_ext` functions from its one thread, so the state is thread-local.

use box2d_rs::b2_body::{B2body, B2bodyDef, B2bodyType, BodyPtr};
use box2d_rs::b2_fixture::B2fixtureDef;
use box2d_rs::b2_joint::{B2JointDefEnum, B2jointPtr, JointAsDerivedMut};
use box2d_rs::b2_math::B2vec2;
use box2d_rs::b2_world::{B2world, B2worldPtr};
use box2d_rs::b2rs_common::UserDataType;
use box2d_rs::joints::b2_revolute_joint::B2revoluteJointDef;
use box2d_rs::shapes::b2_circle_shape::B2circleShape;
use box2d_rs::shapes::b2_polygon_shape::B2polygonShape;
use std::cell::RefCell;
use std::collections::BTreeMap;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int};
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::rc::Rc;

#[derive(Default, Copy, Clone, Debug, PartialEq)]
pub struct NoData;
impl UserDataType for NoData {
    type Fixture = ();
    type Body = ();
    type Joint = ();
}

struct World {
    world: B2worldPtr<NoData>,
    bodies: BTreeMap<u32, BodyPtr<NoData>>,
    joints: BTreeMap<u32, B2jointPtr<NoData>>,
    next_handle: u32,
}

#[derive(Default)]
struct State {
    worlds: BTreeMap<u32, World>,
    next_world: u32,
}

thread_local! {
    static STATE: RefCell<State> = RefCell::new(State::default());
    static REPLY: RefCell<CString> = RefCell::new(CString::default());
}

type Reply = Result<String, String>;

/// Parses the arguments BYOND passed, runs the command, and hands back its reply as text. Panics
/// are caught here: they must not unwind into BYOND.
fn run(argc: c_int, argv: *const *const c_char, command: fn(&[String]) -> Reply) -> *const c_char {
    let args: Vec<String> = (0..argc.max(0) as usize)
        .map(|i| unsafe {
            let arg = *argv.add(i);
            if arg.is_null() {
                String::new()
            } else {
                CStr::from_ptr(arg).to_string_lossy().into_owned()
            }
        })
        .collect();
    let text = match catch_unwind(AssertUnwindSafe(|| command(&args))) {
        Ok(Ok(value)) => value,
        Ok(Err(message)) => format!("ERR:{message}"),
        Err(_) => "ERR:panic".to_string(),
    };
    REPLY.with(|reply| {
        *reply.borrow_mut() = CString::new(text.replace('\0', " ")).unwrap_or_default();
        reply.borrow().as_ptr()
    })
}

fn num(args: &[String], index: usize, name: &str) -> Result<f32, String> {
    let text = args.get(index).ok_or_else(|| format!("missing {name}"))?;
    let value: f32 = text.trim().parse().map_err(|_| format!("{name} is not a number: {text}"))?;
    if value.is_finite() {
        Ok(value)
    } else {
        Err(format!("{name} is not finite"))
    }
}

fn handle(args: &[String], index: usize, name: &str) -> Result<u32, String> {
    let text = args.get(index).ok_or_else(|| format!("missing {name}"))?;
    text.trim().parse().map_err(|_| format!("{name} is not a handle: {text}"))
}

fn with_world<T>(id: u32, f: impl FnOnce(&mut World) -> Result<T, String>) -> Result<T, String> {
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        let world = state.worlds.get_mut(&id).ok_or_else(|| format!("no world {id}"))?;
        f(world)
    })
}

fn body_of(world: &World, id: u32) -> Result<BodyPtr<NoData>, String> {
    world.bodies.get(&id).cloned().ok_or_else(|| format!("no body {id}"))
}

fn fmt_body(id: u32, body: &BodyPtr<NoData>) -> String {
    let body = body.borrow();
    let position = body.get_position();
    let velocity = body.get_linear_velocity();
    format!(
        "{id} {:.5} {:.5} {:.5} {:.5} {:.5} {:.5}",
        position.x,
        position.y,
        body.get_angle(),
        velocity.x,
        velocity.y,
        body.get_angular_velocity()
    )
}

// The commands. Each takes the text arguments and returns a reply.

pub fn version(_: &[String]) -> Reply {
    Ok(format!("vcphys {} box2d-rs 0.0.4", env!("CARGO_PKG_VERSION")))
}

/// world_create(gravity_x, gravity_y) -> world
pub fn world_create(args: &[String]) -> Reply {
    let gravity = B2vec2::new(num(args, 0, "gravity_x")?, num(args, 1, "gravity_y")?);
    STATE.with(|state| {
        let mut state = state.borrow_mut();
        state.next_world += 1;
        let id = state.next_world;
        state.worlds.insert(id, World { world: B2world::new(gravity), bodies: BTreeMap::new(), joints: BTreeMap::new(), next_handle: 0 });
        Ok(id.to_string())
    })
}

/// world_destroy(world) -> OK. Everything in it goes with it.
pub fn world_destroy(args: &[String]) -> Reply {
    let id = handle(args, 0, "world")?;
    STATE.with(|state| {
        let removed = state.borrow_mut().worlds.remove(&id);
        let world = removed.ok_or_else(|| format!("no world {id}"))?;
        // Joints first, then bodies, so nothing is left holding a reference to the world.
        for (_, joint) in world.joints {
            world.world.borrow_mut().destroy_joint(joint);
        }
        for (_, body) in world.bodies {
            world.world.borrow_mut().destroy_body(body);
        }
        Ok("OK".to_string())
    })
}

/// world_step(world, dt, velocity_iterations, position_iterations, substeps) -> OK
/// Takes `substeps` steps of exactly `dt` seconds each.
pub fn world_step(args: &[String]) -> Reply {
    let id = handle(args, 0, "world")?;
    let dt = num(args, 1, "dt")?;
    let velocity_iterations = num(args, 2, "velocity_iterations")? as i32;
    let position_iterations = num(args, 3, "position_iterations")? as i32;
    let substeps = num(args, 4, "substeps")? as i32;
    if !(dt > 0.0 && dt <= 0.1) || !(1..=64).contains(&substeps) {
        return Err("dt must be in (0, 0.1] and substeps in 1..=64".into());
    }
    with_world(id, |world| {
        for _ in 0..substeps {
            world.world.borrow_mut().step(dt, velocity_iterations.clamp(1, 32), position_iterations.clamp(1, 32));
        }
        Ok("OK".to_string())
    })
}

/// world_read(world) -> "id x y angle vx vy spin;..." for every body, in handle order.
pub fn world_read(args: &[String]) -> Reply {
    with_world(handle(args, 0, "world")?, |world| {
        Ok(world.bodies.iter().map(|(id, body)| fmt_body(*id, body)).collect::<Vec<_>>().join(";"))
    })
}

/// world_stats(world) -> "bodies=N joints=M"
pub fn world_stats(args: &[String]) -> Reply {
    with_world(handle(args, 0, "world")?, |world| Ok(format!("bodies={} joints={}", world.bodies.len(), world.joints.len())))
}

/// body_create(world, type, x, y, angle, linear_damping, angular_damping[, can_sleep[, fixed_rotation]])
/// -> body
/// type: 0 static, 1 kinematic, 2 dynamic. can_sleep 0 keeps a body simulated even when it's
/// barely moving (Box2D otherwise stops simulating resting bodies, and a stalled motor won't wake one).
/// fixed_rotation 1 makes a body that never turns (something that slides about, like a mob).
pub fn body_create(args: &[String]) -> Reply {
    let id = handle(args, 0, "world")?;
    let body_type = match num(args, 1, "type")? as i32 {
        0 => B2bodyType::B2StaticBody,
        1 => B2bodyType::B2KinematicBody,
        2 => B2bodyType::B2DynamicBody,
        other => return Err(format!("unknown body type {other}")),
    };
    let mut def = B2bodyDef::<NoData>::default();
    def.body_type = body_type;
    def.position = B2vec2::new(num(args, 2, "x")?, num(args, 3, "y")?);
    def.angle = num(args, 4, "angle")?;
    def.linear_damping = num(args, 5, "linear_damping")?.max(0.0);
    def.angular_damping = num(args, 6, "angular_damping")?.max(0.0);
    if args.len() > 7 {
        def.allow_sleep = num(args, 7, "can_sleep")? != 0.0;
    }
    if args.len() > 8 {
        def.fixed_rotation = num(args, 8, "fixed_rotation")? != 0.0;
    }
    with_world(id, |world| {
        let body = B2world::create_body(world.world.clone(), &def);
        world.next_handle += 1;
        world.bodies.insert(world.next_handle, body);
        Ok(world.next_handle.to_string())
    })
}

/// body_destroy(world, body) -> OK. Its fixtures and joints go with it.
pub fn body_destroy(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    with_world(handle(args, 0, "world")?, |world| {
        let body = world.bodies.remove(&body_id).ok_or_else(|| format!("no body {body_id}"))?;
        // Box2D destroys attached joints itself; forget our handles to them.
        let attached: Vec<u32> = world
            .joints
            .iter()
            .filter(|(_, joint)| {
                let joint = joint.borrow();
                Rc::ptr_eq(&joint.get_base().get_body_a(), &body) || Rc::ptr_eq(&joint.get_base().get_body_b(), &body)
            })
            .map(|(id, _)| *id)
            .collect();
        for joint_id in attached {
            world.joints.remove(&joint_id);
        }
        world.world.borrow_mut().destroy_body(body);
        Ok("OK".to_string())
    })
}

/// fixture_box(world, body, half_width, half_height, centre_x, centre_y, angle, density, friction,
/// restitution, group) -> OK
/// A box in the body's own frame. Fixtures sharing a negative group never collide with each other.
/// A body can have more than one: to make a body start colliding with something it was grouped
/// away from, add a second, weightless box in another group. (Changing a fixture's group in place
/// isn't offered: box2d-rs panics refiltering a fixture that's touching anything.)
pub fn fixture_box(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let (half_width, half_height) = (num(args, 2, "half_width")?, num(args, 3, "half_height")?);
    if half_width <= 0.0 || half_height <= 0.0 {
        return Err("box half sizes must be positive".into());
    }
    let centre = B2vec2::new(num(args, 4, "centre_x")?, num(args, 5, "centre_y")?);
    let angle = num(args, 6, "angle")?;
    let mut shape = B2polygonShape::default();
    shape.set_as_box_angle(half_width, half_height, centre, angle);
    let mut def = B2fixtureDef::<NoData>::default();
    def.shape = Some(Rc::new(RefCell::new(shape)));
    def.density = num(args, 7, "density")?.max(0.0);
    def.friction = num(args, 8, "friction")?.max(0.0);
    def.restitution = num(args, 9, "restitution")?.clamp(0.0, 1.0);
    def.filter.group_index = num(args, 10, "group")? as i16;
    with_world(handle(args, 0, "world")?, |world| {
        let body = body_of(world, body_id)?;
        B2body::create_fixture(body, &def);
        Ok("OK".to_string())
    })
}

/// fixture_circle(world, body, radius, centre_x, centre_y, density, friction, restitution, group) -> OK
/// A circle in the body's own frame. Groups work as they do for fixture_box().
pub fn fixture_circle(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let radius = num(args, 2, "radius")?;
    if radius <= 0.0 {
        return Err("circle radius must be positive".into());
    }
    let mut shape = B2circleShape::default();
    shape.base.m_radius = radius;
    shape.m_p = B2vec2::new(num(args, 3, "centre_x")?, num(args, 4, "centre_y")?);
    let mut def = B2fixtureDef::<NoData>::default();
    def.shape = Some(Rc::new(RefCell::new(shape)));
    def.density = num(args, 5, "density")?.max(0.0);
    def.friction = num(args, 6, "friction")?.max(0.0);
    def.restitution = num(args, 7, "restitution")?.clamp(0.0, 1.0);
    def.filter.group_index = num(args, 8, "group")? as i16;
    with_world(handle(args, 0, "world")?, |world| {
        let body = body_of(world, body_id)?;
        B2body::create_fixture(body, &def);
        Ok("OK".to_string())
    })
}

/// joint_revolute(world, body_a, body_b, anchor_x, anchor_y, lower, upper, motor_torque[,
/// collide_connected]) -> joint
/// Pins two bodies together at a point in the world. The angle limits, if lower < upper, are
/// relative to how the bodies sit now. A motor torque above 0 adds joint friction: a motor held
/// at zero speed that can only push that hard, which keeps a ragdoll from flopping like string.
/// collide_connected 1 lets the two bodies still collide with each other (Box2D otherwise stops
/// jointed bodies colliding): pinned together where they overlap, they never stop pushing apart.
pub fn joint_revolute(args: &[String]) -> Reply {
    let (a_id, b_id) = (handle(args, 1, "body_a")?, handle(args, 2, "body_b")?);
    let anchor = B2vec2::new(num(args, 3, "anchor_x")?, num(args, 4, "anchor_y")?);
    let (lower, upper) = (num(args, 5, "lower")?, num(args, 6, "upper")?);
    let motor_torque = num(args, 7, "motor_torque")?.max(0.0);
    with_world(handle(args, 0, "world")?, |world| {
        let (a, b) = (body_of(world, a_id)?, body_of(world, b_id)?);
        if Rc::ptr_eq(&a, &b) {
            return Err("a joint needs two different bodies".into());
        }
        let mut def = B2revoluteJointDef::<NoData>::default();
        def.initialize(a, b, anchor);
        def.base.collide_connected = args.len() > 8 && num(args, 8, "collide_connected")? != 0.0;
        def.enable_limit = lower < upper;
        def.lower_angle = lower;
        def.upper_angle = upper;
        def.enable_motor = motor_torque > 0.0;
        def.motor_speed = 0.0;
        def.max_motor_torque = motor_torque;
        let joint = world.world.borrow_mut().create_joint(&B2JointDefEnum::RevoluteJoint(def));
        world.next_handle += 1;
        world.joints.insert(world.next_handle, joint);
        Ok(world.next_handle.to_string())
    })
}

/// joint_destroy(world, joint) -> OK
pub fn joint_destroy(args: &[String]) -> Reply {
    let joint_id = handle(args, 1, "joint")?;
    with_world(handle(args, 0, "world")?, |world| {
        let joint = world.joints.remove(&joint_id).ok_or_else(|| format!("no joint {joint_id}"))?;
        world.world.borrow_mut().destroy_joint(joint);
        Ok("OK".to_string())
    })
}

/// joint_set_limits(world, joint, lower, upper) -> OK
/// New angle limits for a revolute joint, relative to how it sat when made. lower >= upper frees it.
pub fn joint_set_limits(args: &[String]) -> Reply {
    let joint_id = handle(args, 1, "joint")?;
    let (lower, upper) = (num(args, 2, "lower")?, num(args, 3, "upper")?);
    with_revolute(handle(args, 0, "world")?, joint_id, |revolute| {
        revolute.enable_limit(lower < upper);
        if lower < upper {
            revolute.set_limits(lower, upper);
        }
    })
}

/// joint_set_motor(world, joint, speed, max_torque) -> OK
/// Drives a revolute joint at a speed (radians a second, counter-clockwise), pushing no harder than
/// max_torque. A max_torque of 0 turns the motor off.
pub fn joint_set_motor(args: &[String]) -> Reply {
    let joint_id = handle(args, 1, "joint")?;
    let (speed, max_torque) = (num(args, 2, "speed")?, num(args, 3, "max_torque")?.max(0.0));
    with_revolute(handle(args, 0, "world")?, joint_id, |revolute| {
        revolute.enable_motor(max_torque > 0.0);
        revolute.set_motor_speed(speed);
        revolute.set_max_motor_torque(max_torque);
    })
}

fn with_revolute(
    world_id: u32,
    joint_id: u32,
    f: impl FnOnce(&mut box2d_rs::joints::b2_revolute_joint::B2revoluteJoint<NoData>),
) -> Reply {
    with_world(world_id, |world| {
        let joint = world.joints.get(&joint_id).cloned().ok_or_else(|| format!("no joint {joint_id}"))?;
        let mut joint = joint.borrow_mut();
        match joint.as_derived_mut() {
            JointAsDerivedMut::ERevoluteJoint(revolute) => {
                f(revolute);
                Ok("OK".to_string())
            }
            _ => Err(format!("joint {joint_id} isn't revolute")),
        }
    })
}

/// body_set_transform(world, body, x, y, angle) -> OK
/// Puts a body somewhere else at once (a teleport, not a move: nothing in between is hit).
pub fn body_set_transform(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let position = B2vec2::new(num(args, 2, "x")?, num(args, 3, "y")?);
    let angle = num(args, 4, "angle")?;
    with_world(handle(args, 0, "world")?, |world| {
        body_of(world, body_id)?.borrow_mut().set_transform(position, angle);
        Ok("OK".to_string())
    })
}

/// body_set_velocity(world, body, vx, vy, spin) -> OK
pub fn body_set_velocity(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let velocity = B2vec2::new(num(args, 2, "vx")?, num(args, 3, "vy")?);
    let spin = num(args, 4, "spin")?;
    with_world(handle(args, 0, "world")?, |world| {
        let body = body_of(world, body_id)?;
        let mut body = body.borrow_mut();
        body.set_linear_velocity(velocity);
        body.set_angular_velocity(spin);
        Ok("OK".to_string())
    })
}

/// body_read(world, body) -> "id x y angle vx vy spin"
pub fn body_read(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    with_world(handle(args, 0, "world")?, |world| Ok(fmt_body(body_id, &body_of(world, body_id)?)))
}

/// Where on a body to push: the world point given, or its centre of mass if none is.
fn push_point(args: &[String], index: usize, body: &BodyPtr<NoData>) -> Result<B2vec2, String> {
    if args.len() > index + 1 {
        Ok(B2vec2::new(num(args, index, "point_x")?, num(args, index + 1, "point_y")?))
    } else {
        Ok(body.borrow().get_world_center())
    }
}

/// body_impulse(world, body, impulse_x, impulse_y[, point_x, point_y]) -> OK
pub fn body_impulse(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let impulse = B2vec2::new(num(args, 2, "impulse_x")?, num(args, 3, "impulse_y")?);
    with_world(handle(args, 0, "world")?, |world| {
        let body = body_of(world, body_id)?;
        let point = push_point(args, 4, &body)?;
        body.borrow_mut().apply_linear_impulse(impulse, point, true);
        Ok("OK".to_string())
    })
}

/// body_force(world, body, force_x, force_y[, point_x, point_y]) -> OK. Lasts one step.
pub fn body_force(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let force = B2vec2::new(num(args, 2, "force_x")?, num(args, 3, "force_y")?);
    with_world(handle(args, 0, "world")?, |world| {
        let body = body_of(world, body_id)?;
        let point = push_point(args, 4, &body)?;
        body.borrow_mut().apply_force(force, point, true);
        Ok("OK".to_string())
    })
}

/// body_torque(world, body, torque) -> OK. Lasts one step.
pub fn body_torque(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let torque = num(args, 2, "torque")?;
    with_world(handle(args, 0, "world")?, |world| {
        body_of(world, body_id)?.borrow_mut().apply_torque(torque, true);
        Ok("OK".to_string())
    })
}

/// body_angular_impulse(world, body, impulse) -> OK
pub fn body_angular_impulse(args: &[String]) -> Reply {
    let body_id = handle(args, 1, "body")?;
    let impulse = num(args, 2, "impulse")?;
    with_world(handle(args, 0, "world")?, |world| {
        body_of(world, body_id)?.borrow_mut().apply_angular_impulse(impulse, true);
        Ok("OK".to_string())
    })
}

/// Exports each command to BYOND under a `vcphys_` name, so nothing clashes with anything else
/// BYOND loads.
macro_rules! export {
    ($($export:ident => $command:ident),* $(,)?) => {
        $(
            #[no_mangle]
            pub extern "C" fn $export(argc: c_int, argv: *const *const c_char) -> *const c_char {
                run(argc, argv, $command)
            }
        )*
    };
}

export! {
    vcphys_version => version,
    vcphys_world_create => world_create,
    vcphys_world_destroy => world_destroy,
    vcphys_world_step => world_step,
    vcphys_world_read => world_read,
    vcphys_world_stats => world_stats,
    vcphys_body_create => body_create,
    vcphys_body_destroy => body_destroy,
    vcphys_body_read => body_read,
    vcphys_fixture_box => fixture_box,
    vcphys_joint_revolute => joint_revolute,
    vcphys_joint_destroy => joint_destroy,
    vcphys_body_impulse => body_impulse,
    vcphys_body_force => body_force,
    vcphys_body_torque => body_torque,
    vcphys_body_angular_impulse => body_angular_impulse,
    vcphys_joint_set_limits => joint_set_limits,
    vcphys_joint_set_motor => joint_set_motor,
    vcphys_fixture_circle => fixture_circle,
    vcphys_body_set_transform => body_set_transform,
    vcphys_body_set_velocity => body_set_velocity,
}
