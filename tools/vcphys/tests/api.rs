//! The API as BYOND sees it: text in, text out.
use vcphys::*;

fn call(command: fn(&[String]) -> Result<String, String>, args: &[&str]) -> Result<String, String> {
    command(&args.iter().map(|s| s.to_string()).collect::<Vec<_>>())
}

fn ok(command: fn(&[String]) -> Result<String, String>, args: &[&str]) -> String {
    call(command, args).unwrap_or_else(|e| panic!("{e}"))
}

/// A floor, and a two-link arm hanging off a box, knocked sideways.
fn scene() -> (String, String) {
    let world = ok(world_create, &["0", "-9.8"]);
    let ground = ok(body_create, &[&world, "0", "0", "-0.5", "0", "0", "0"]);
    ok(fixture_box, &[&world, &ground, "5", "0.5", "0", "0", "0", "0", "0.6", "0", "0"]);
    let upper = ok(body_create, &[&world, "2", "0", "1.5", "0", "0.05", "0.3"]);
    ok(fixture_box, &[&world, &upper, "0.1", "0.25", "0", "-0.25", "0", "1", "0.6", "0.1", "-1"]);
    let lower = ok(body_create, &[&world, "2", "0", "1.0", "0", "0.05", "0.3"]);
    ok(fixture_box, &[&world, &lower, "0.1", "0.25", "0", "-0.25", "0", "1", "0.6", "0.1", "-1"]);
    // An elbow that only bends one way, a quarter turn at most.
    ok(joint_revolute, &[&world, &upper, &lower, "0", "1.0", "0", "1.5708", "0.2"]);
    ok(body_impulse, &[&world, &lower, "0.8", "0"]);
    for _ in 0..90 {
        ok(world_step, &[&world, "0.016666667", "8", "3", "1"]);
    }
    let read = ok(world_read, &[&world]);
    (world, read)
}

#[test]
fn same_calls_same_result() {
    let (first_world, first) = scene();
    let (second_world, second) = scene();
    assert_eq!(first, second, "two identical runs came out different");
    ok(world_destroy, &[&first_world]);
    ok(world_destroy, &[&second_world]);
}

#[test]
fn joint_limit_holds() {
    let (world, read) = scene();
    // Bodies in handle order: ground (1), upper (2), lower (3). Field 3 is the angle.
    let angles: Vec<f32> = read.split(';').map(|body| body.split(' ').nth(3).unwrap().parse().unwrap()).collect();
    let bend = angles[2] - angles[1];
    assert!(bend >= -0.05 && bend <= 1.6208, "the elbow bent {bend} rad, outside its limits");
    ok(world_destroy, &[&world]);
}

#[test]
fn things_fall_and_land() {
    let world = ok(world_create, &["0", "-9.8"]);
    let ground = ok(body_create, &[&world, "0", "0", "-0.5", "0", "0", "0"]);
    ok(fixture_box, &[&world, &ground, "5", "0.5", "0", "0", "0", "0", "0.6", "0", "0"]);
    let crate_ = ok(body_create, &[&world, "2", "0", "3", "0", "0", "0"]);
    ok(fixture_box, &[&world, &crate_, "0.25", "0.25", "0", "0", "0", "1", "0.6", "0", "0"]);
    ok(world_step, &[&world, "0.016666667", "8", "3", "64"]);
    ok(world_step, &[&world, "0.016666667", "8", "3", "64"]);
    let y: f32 = ok(body_read, &[&world, &crate_]).split(' ').nth(2).unwrap().parse().unwrap();
    assert!((y - 0.25).abs() < 0.02, "the crate came to rest at {y}, not on the floor");
    ok(world_destroy, &[&world]);
}

#[test]
fn bad_calls_say_why() {
    assert!(call(world_step, &["999", "0.016", "8", "3", "1"]).unwrap_err().contains("no world"));
    let world = ok(world_create, &["0", "-9.8"]);
    assert!(call(body_read, &[&world, "42"]).unwrap_err().contains("no body"));
    assert!(call(body_create, &[&world, "7", "0", "0", "0", "0", "0"]).unwrap_err().contains("body type"));
    assert!(call(world_step, &[&world, "0.5", "8", "3", "1"]).is_err(), "a huge time step was allowed");
    assert!(call(world_create, &["NaN", "0"]).is_err(), "NaN gravity was allowed");
    assert!(call(fixture_box, &[&world]).unwrap_err().contains("missing"));
    ok(world_destroy, &[&world]);
    assert!(call(world_stats, &[&world]).unwrap_err().contains("no world"), "a destroyed world still answers");
}

#[test]
fn destroying_a_body_forgets_its_joints() {
    let world = ok(world_create, &["0", "-9.8"]);
    let a = ok(body_create, &[&world, "2", "0", "1", "0", "0", "0"]);
    ok(fixture_box, &[&world, &a, "0.1", "0.1", "0", "0", "0", "1", "0.5", "0", "0"]);
    let b = ok(body_create, &[&world, "2", "0", "0.8", "0", "0", "0"]);
    ok(fixture_box, &[&world, &b, "0.1", "0.1", "0", "0", "0", "1", "0.5", "0", "0"]);
    ok(joint_revolute, &[&world, &a, &b, "0", "0.9", "0", "0", "0"]);
    assert_eq!(ok(world_stats, &[&world]), "bodies=2 joints=1");
    ok(body_destroy, &[&world, &a]);
    assert_eq!(ok(world_stats, &[&world]), "bodies=1 joints=0");
    ok(world_destroy, &[&world]);
}

#[test]
fn collisions_limits_and_motors_can_change() {
    let world = ok(world_create, &["0", "0"]);
    // Two boxes in the same negative group, one flung through the other.
    let a = ok(body_create, &[&world, "2", "0", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world, &a, "0.2", "0.2", "0", "0", "0", "1", "0.5", "0", "-1"]);
    let b = ok(body_create, &[&world, "2", "-1", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world, &b, "0.2", "0.2", "0", "0", "0", "1", "0.5", "0", "-1"]);
    ok(body_impulse, &[&world, &b, "1", "0"]);
    ok(world_step, &[&world, "0.016666667", "8", "3", "60"]);
    let passed: f32 = ok(body_read, &[&world, &b]).split(' ').nth(1).unwrap().parse().unwrap();
    assert!(passed > 0.3, "the same group collided anyway (b is at {passed})");
    // Now they should: move b back and fling it again.
    let world2 = ok(world_create, &["0", "0"]);
    let a2 = ok(body_create, &[&world2, "2", "0", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world2, &a2, "0.2", "0.2", "0", "0", "0", "1", "0.5", "0", "-1"]);
    let b2 = ok(body_create, &[&world2, "2", "-1", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world2, &b2, "0.2", "0.2", "0", "0", "0", "1", "0.5", "0", "-1"]);
    // A second, weightless box in group 0 each, and they collide after all.
    ok(fixture_box, &[&world2, &a2, "0.2", "0.2", "0", "0", "0", "0", "0.5", "0", "0"]);
    ok(fixture_box, &[&world2, &b2, "0.2", "0.2", "0", "0", "0", "0", "0.5", "0", "0"]);
    ok(body_impulse, &[&world2, &b2, "1", "0"]);
    ok(world_step, &[&world2, "0.016666667", "8", "3", "60"]);
    // With no bounce they carry on together, b still behind a.
    let b_x: f32 = ok(body_read, &[&world2, &b2]).split(' ').nth(1).unwrap().parse().unwrap();
    let a_x: f32 = ok(body_read, &[&world2, &a2]).split(' ').nth(1).unwrap().parse().unwrap();
    assert!(b_x < a_x - 0.3, "ungrouped bodies passed through each other (b at {b_x}, a at {a_x})");
    // A motor spins a free joint; a limit then holds it.
    let base = ok(body_create, &[&world2, "0", "5", "0", "0", "0", "0"]);
    let arm = ok(body_create, &[&world2, "2", "5", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world2, &arm, "0.3", "0.05", "0.3", "0", "0", "1", "0.5", "0", "-2"]);
    let joint = ok(joint_revolute, &[&world2, &base, &arm, "5", "0", "0", "0", "0"]);
    ok(joint_set_motor, &[&world2, &joint, "3", "50"]);
    ok(world_step, &[&world2, "0.016666667", "8", "3", "30"]);
    let spun: f32 = ok(body_read, &[&world2, &arm]).split(' ').nth(3).unwrap().parse().unwrap();
    assert!(spun > 1.0, "the motor didn't turn the joint ({spun} rad)");
    ok(joint_set_limits, &[&world2, &joint, "-0.1", "0.1"]);
    ok(world_step, &[&world2, "0.016666667", "8", "3", "60"]);
    let held: f32 = ok(body_read, &[&world2, &arm]).split(' ').nth(3).unwrap().parse().unwrap();
    assert!(held.abs() < 0.3, "the new limit didn't hold ({held} rad)");
    assert!(call(joint_set_motor, &[&world2, "999", "1", "1"]).unwrap_err().contains("no joint"));
    ok(world_destroy, &[&world]);
    ok(world_destroy, &[&world2]);
}

/// Top-down, as the Serverblight chase uses it: no gravity, a circle that never turns, sliding
/// along a wall it's pushed into, then teleported and stopped while touching it.
#[test]
fn a_slider_slides_along_walls_and_teleports() {
    let world = ok(world_create, &["0", "0"]);
    let wall = ok(body_create, &[&world, "0", "2", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world, &wall, "0.5", "5", "0", "0", "0", "0", "0", "0", "0"]);
    let slider = ok(body_create, &[&world, "2", "1.2", "0", "0", "1", "0", "0", "1"]);
    ok(fixture_circle, &[&world, &slider, "0.3", "0", "0", "1", "0", "0", "0"]);
    for _ in 0..60 {
        // Diagonally into the wall: the wall stops the x, the y carries on.
        ok(body_force, &[&world, &slider, "3", "3"]);
        ok(world_step, &[&world, "0.016666667", "8", "3", "1"]);
    }
    let state: Vec<f32> = ok(body_read, &[&world, &slider]).split(' ').skip(1).map(|v| v.parse().unwrap()).collect();
    assert!(state[0] < 1.21, "went into the wall: x {}", state[0]);
    assert!(state[1] > 0.5, "didn't slide along it: y {}", state[1]);
    assert_eq!(state[2], 0.0, "turned with fixed rotation");
    ok(body_set_transform, &[&world, &slider, "-3", "4", "0"]);
    ok(body_set_velocity, &[&world, &slider, "0", "0", "0"]);
    ok(world_step, &[&world, "0.016666667", "8", "3", "1"]);
    let moved: Vec<f32> = ok(body_read, &[&world, &slider]).split(' ').skip(1).map(|v| v.parse().unwrap()).collect();
    assert!((moved[0] + 3.0).abs() < 0.01 && (moved[1] - 4.0).abs() < 0.01, "teleport didn't take: {moved:?}");
    assert!(call(fixture_circle, &[&world, &slider, "0", "0", "0", "1", "0", "0", "0"]).is_err());
}

/// Two boxes glued where they overlap, still colliding with each other: pushed apart, the glue
/// holds them anyway.
#[test]
fn glued_bodies_still_collide() {
    let world = ok(world_create, &["0", "0"]);
    let a = ok(body_create, &[&world, "2", "0", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world, &a, "0.5", "0.5", "0", "0", "0", "1", "0.7", "0", "0"]);
    let b = ok(body_create, &[&world, "2", "0.4", "0", "0", "0", "0"]);
    ok(fixture_box, &[&world, &b, "0.5", "0.5", "0", "0", "0", "1", "0.7", "0", "0"]);
    ok(joint_revolute, &[&world, &a, &b, "0.2", "0", "0", "0", "0", "1"]);
    for _ in 0..30 {
        ok(world_step, &[&world, "0.016666667", "8", "3", "1"]);
    }
    let read = |body: &str| -> Vec<f32> { ok(body_read, &[&world, body]).split(' ').skip(1).map(|v| v.parse().unwrap()).collect() };
    let (first, second) = (read(&a), read(&b));
    let apart = ((second[0] - first[0]).powi(2) + (second[1] - first[1]).powi(2)).sqrt();
    // The overlap pushed them round the pin (they started 0.4 apart, overlapping by 0.6).
    assert!(first[2].abs() + second[2].abs() > 0.01 || apart > 0.41, "they didn't collide: {first:?} {second:?}");
    assert!(apart < 1.0, "the glue let go: {apart}");
}
