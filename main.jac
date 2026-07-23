import from services.source { source_tree, source_file, SourceFile, SourceView }
import from services.docs { ensure_docs, docs_status, doc_tree, doc_page }

cl import ".styles.global.css";
cl import ".styles.site.css";

cl {
    # File-based routing: pages/ builds the router; app just renders it.
    def:pub app(children: any) -> JsxElement {
        return <>{children}</>;
    }
}

# ═══ The native game: the same rlgl cube shooter that compiles to a desktop
# binary, here compiled to /static/main.wasm by the client build and rendered
# in the browser by components/WasmGame.jac via the WebGL shim in
# raylib_shim.jac. Ported from the this_is_jac showcase.
import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def CloseWindow -> None;  def SetTargetFPS(
        fps: i32
    ) -> None;  def BeginDrawing -> None;  def EndDrawing -> None;  def rlClearColor(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlClearScreenBuffers -> None;  def DrawFPS(
        pos_x: i32, pos_y: i32
    ) -> None;  def IsKeyDown(key: i32) -> bool;  def IsKeyPressed(
        key: i32
    ) -> bool;  def GetFrameTime -> f32;  def GetMouseX -> i32;  def GetMouseY -> i32;  def IsMouseButtonPressed(
        button: i32
    ) -> bool;  def DisableCursor -> None;  def EnableCursor -> None;  def rlMatrixMode(
        mode: i32
    ) -> None;  def rlLoadIdentity -> None;  def rlPushMatrix -> None;  def rlPopMatrix -> None;  def rlTranslatef(
        x: f32, y: f32, z: f32
    ) -> None;  def rlRotatef(angle: f32, x: f32, y: f32, z: f32) -> None;  def rlFrustum(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;  def rlOrtho(
        left: f64, right: f64, bottom: f64, top: f64, znear: f64, zfar: f64
    ) -> None;  def rlBegin(mode: i32) -> None;  def rlEnd -> None;  def rlVertex3f(
        x: f32, y: f32, z: f32
    ) -> None;  def rlColor4ub(r: u8, g: u8, b: u8, a: u8) -> None;  def rlEnableDepthTest -> None;  def rlDisableDepthTest -> None;  def rlSetLineWidth(
        width: f32
    ) -> None;  def EndMode3D -> None;  def GetTime -> f64;  def FileExists(
        fileName: str
    ) -> bool;  def LoadFileText(fileName: str) -> str;  def TextToInteger(
        text: str
    ) -> i32;  def SaveFileText(fileName: str, text: str) -> bool;
}

glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004;

"""Open a window. No frame-rate cap is set, so the loop runs as fast as the
hardware allows (call `SetTargetFPS` yourself if you want to limit it)."""
def open_window(width: int, height: int, title: str) {
    InitWindow(width, height, title);
}

"""True once the user closes the window or presses ESC."""
def should_close -> bool {
    return WindowShouldClose();
}

"""Tear the window down."""
def close_window {
    CloseWindow();
}

"""Seconds elapsed during the previous frame (for frame-rate-independent motion)."""
def dt -> float {
    return GetFrameTime();
}

"""Held-this-frame test for a raylib key code."""
def key_held(code: int) -> bool {
    return IsKeyDown(code);
}

"""Pressed-this-frame (edge) test for a raylib key code."""
def key_tapped(code: int) -> bool {
    return IsKeyPressed(code);
}

"""Current mouse X in pixels (as a float - see the GetMouseX note above)."""
def mouse_x -> float {
    return float(GetMouseX());
}

"""Current mouse Y in pixels (as a float)."""
def mouse_y -> float {
    return float(GetMouseY());
}

"""Pressed-this-frame test for a mouse button (0 = left)."""
def mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(button);
}

"""Hide and lock the cursor for FPS-style relative mouse-look."""
def lock_mouse {
    DisableCursor();
}

"""Show and release the cursor."""
def unlock_mouse {
    EnableCursor();
}

"""Begin a frame: clear color+depth to (r,g,b) and turn on depth testing."""
def begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(r, g, b, 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

"""Present the frame."""
def end_frame {
    EndDrawing();
}

"""End the 3D pass and switch to a pixel-space 2D overlay mode."""
def end_camera(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
}

"""Draw raylib's built-in FPS counter at (x, y) as a 2D overlay."""
def draw_fps(x: int, y: int) {
    DrawFPS(x, y);
}

"""Install a perspective camera at (px,py,pz) looking with yaw/pitch (degrees)."""
def set_camera(
    px: float, py: float, pz: float, yaw_deg: float, pitch_deg: float, aspect: float
) {
    near = 0.05;
    far_plane = 400.0;
    top = near * 0.57735026;
    right = top * aspect;
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlFrustum(-right, right, -top, top, near, far_plane);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlRotatef(-pitch_deg, 1.0, 0.0, 0.0);
    rlRotatef(-yaw_deg, 0.0, 1.0, 0.0);
    rlTranslatef(-px, -py, -pz);
}

"""Emit one quad (corners 0->1->2->3, CCW) as two triangles."""
def _quad(
    p0: float,
    p1: float,
    p2: float,
    p3: float,
    p4: float,
    p5: float,
    p6: float,
    p7: float,
    p8: float,
    p9: float,
    p10: float,
    p11: float
) {
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p3, p4, p5);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p0, p1, p2);
    rlVertex3f(p6, p7, p8);
    rlVertex3f(p9, p10, p11);
}

"""Scale a 0-255 channel by a percentage (cheap face shading)."""
def _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

"""Draw an axis-aligned colored box centered at (cx,cy,cz) with size (sx,sy,sz)."""
def draw_box(
    cx: float,
    cy: float,
    cz: float,
    sx: float,
    sy: float,
    sz: float,
    r: int,
    g: int,
    b: int
) {
    hx = sx * 0.5;
    hy = sy * 0.5;
    hz = sz * 0.5;
    rlPushMatrix();
    rlTranslatef(cx, cy, cz);
    rlBegin(RL_TRIANGLES);

    rlColor4ub(_shade(r, 100), _shade(g, 100), _shade(b, 100), 255);
    _quad(-hx, hy, hz, hx, hy, hz, hx, hy, -hz, -hx, hy, -hz);
    rlColor4ub(_shade(r, 85), _shade(g, 85), _shade(b, 85), 255);
    _quad(-hx, -hy, hz, hx, -hy, hz, hx, hy, hz, -hx, hy, hz);
    _quad(hx, -hy, -hz, -hx, -hy, -hz, -hx, hy, -hz, hx, hy, -hz);
    rlColor4ub(_shade(r, 70), _shade(g, 70), _shade(b, 70), 255);
    _quad(hx, -hy, hz, hx, -hy, -hz, hx, hy, -hz, hx, hy, hz);
    _quad(-hx, -hy, -hz, -hx, -hy, hz, -hx, hy, hz, -hx, hy, -hz);
    rlColor4ub(_shade(r, 45), _shade(g, 45), _shade(b, 45), 255);
    _quad(-hx, -hy, -hz, hx, -hy, -hz, hx, -hy, hz, -hx, -hy, hz);

    rlEnd();
    rlPopMatrix();
}

"""Draw a flat floor grid of `half*2` lines per axis, spaced `step` apart, on y=0."""
def draw_floor(half: int, step: float) {
    ext = float(half) * step;
    rlSetLineWidth(1.0);
    rlBegin(RL_LINES);
    rlColor4ub(52, 52, 58, 255);
    i = -half;
    while i <= half {
        f = float(i) * step;
        rlVertex3f(f, 0.0, -ext);
        rlVertex3f(f, 0.0, ext);
        rlVertex3f(-ext, 0.0, f);
        rlVertex3f(ext, 0.0, f);
        i += 1;
    }
    rlEnd();
}

"""Seconds elapsed since the window opened (raylib's own clock)."""
def clock -> float {
    return GetTime();
}

"""Benchmark duration in seconds, or 0 for normal (interactive) play."""
def bench_seconds -> float {
    if FileExists(".bench_seconds") {
        return float(TextToInteger(LoadFileText(".bench_seconds")));
    }
    return 0.0;
}

"""Hand the benchmark result back to demo.sh (avg max frames seconds)."""
def write_bench_result(
    avg_fps: float, peak_fps: float, frame_count: int, seconds: float
) {
    SaveFileText(
        ".bench_result",
        f"BENCH_RESULT {avg_fps} {peak_fps} {frame_count} {seconds}"
    );
}

"""Benchmark accumulators (dormant unless `.bench_seconds` exists)."""
glob bench: float = bench_seconds(),
     frames: int = 0,
     max_fps: float = 0.0;

glob KEY_W: int = 87,
     KEY_A: int = 65,
     KEY_S: int = 83,
     KEY_D: int = 68,
     KEY_SPACE: int = 32,
     KEY_RIGHT: int = 262,
     KEY_LEFT: int = 263,
     KEY_DOWN: int = 264,
     KEY_UP: int = 265,
     KEY_TAB: int = 258,
     MOUSE_LEFT: int = 0,
     DEG2RAD: float = 0.017453292519943295,
     px: float = 0.0,
     py: float = 2.0,
     pz: float = 12.0,
     yaw: float = 0.0,
     pitch: float = 0.0,
     fire_cd: float = 0.0,
     world_t: float = 0.0,
     score: int = 0,
     rng: int = 987654321,
     prev_mx: float = 0.0,
     prev_my: float = 0.0,
     mouse_warmup: int = 12,
     mouse_sens: float = 0.12,
     mouse_captured: bool = False;

"""cos via range-reduced Taylor series (good to ~1e-4 on the reduced range)."""
def jcos(a: float) -> float {
    twopi = 6.283185307179586;
    pi = 3.141592653589793;
    while a > pi {
        a -= twopi;
    }
    while a < -pi {
        a += twopi;
    }
    x2 = a * a;
    x4 = x2 * x2;
    x6 = x4 * x2;
    x8 = x4 * x4;
    x10 = x8 * x2;
    x12 = x8 * x4;
    return 1.0 - x2 / 2.0 + x4 / 24.0 - x6 / 720.0 + x8 / 40320.0 - x10 / 3628800.0 + x12 / 479001600.0;
}

"""sin(a) = cos(a - pi/2)."""
def jsin(a: float) -> float {
    return jcos(a - 1.5707963267948796);
}

"""sqrt via Newton's method (plenty for gameplay distances)."""
def jsqrt(v: float) -> float {
    if v <= 0.0 {
        return 0.0;
    }
    g = v if v > 1.0 else 1.0;
    i = 0;
    while i < 9 {
        g = 0.5 * (g + v / g);
        i += 1;
    }
    return g;
}

"""Uniform pseudo-random float in [0, 1) via a 31-bit LCG."""
def rand01 -> float {
    rng = (rng * 1103515245 + 12345) % 2147483648;
    return float(rng) / 2147483648.0;
}

"""Random float in [lo, hi)."""
def rand_range(lo: float, hi: float) -> float {
    return lo + rand01() * (hi - lo);
}

# ─── The cast ────────────────────────────────────────────────────────────────

"""A hovering hunter drone. It strafes, keeps its distance, telegraphs its
shot with a charge glow, and fires back."""
obj Enemy {
    has x: float,
        y: float,
        z: float,
        base_y: float,
        phase: float,
        strafe_dir: float,
        strafe_t: float,
        fire_t: float,
        charge: float,
        respawn_t: float,
        alive: bool;
}

"""A player rocket in flight."""
obj Rocket {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        life: float;
}

"""An enemy plasma bolt."""
obj Shot {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        life: float;
}

"""Debris, sparks, and smoke. `fade` remembers the starting life so the
cube can shrink as it burns out; `grav` lets smoke rise while debris falls."""
obj Particle {
    has x: float,
        y: float,
        z: float,
        vx: float,
        vy: float,
        vz: float,
        life: float,
        fade: float,
        size: float,
        grav: float,
        r: int,
        g: int,
        b: int;
}

glob enemies: list[Enemy] = [],
     rockets: list[Rocket] = [],
     shots: list[Shot] = [],
     sparks: list[Particle] = [];

# ─── Player state ────────────────────────────────────────────────────────────

glob HP_MAX: float = 100.0,
     CHARGE_T: float = 0.95,
     hp: float = 100.0,
     hurt_t: float = 0.0,
     safe_t: float = 10.0,
     invuln_t: float = 0.0,
     deaths: int = 0,
     kick_t: float = 0.0,
     muzzle_t: float = 0.0;

# ─── Particles ───────────────────────────────────────────────────────────────

"""Claim a dead pool slot for one particle (drops it if the pool is full)."""
def spawn_particle(
    x: float, y: float, z: float,
    vx: float, vy: float, vz: float,
    life: float, size: float, grav: float,
    r: int, g: int, b: int
) {
    for i in range(len(sparks)) {
        p = sparks[i];
        if p.life <= 0.0 {
            p.x = x;
            p.y = y;
            p.z = z;
            p.vx = vx;
            p.vy = vy;
            p.vz = vz;
            p.life = life;
            p.fade = life;
            p.size = size;
            p.grav = grav;
            p.r = r;
            p.g = g;
            p.b = b;
            return;
        }
    }
}

"""Radial burst of debris cubes at (x, y, z)."""
def burst(x: float, y: float, z: float, n: int, speed: float, r: int, g: int, b: int) {
    for i in range(n) {
        a = rand_range(0.0, 6.283);
        up = rand_range(0.2, 1.0);
        s = rand_range(0.3, 1.0) * speed;
        spawn_particle(
            x, y, z,
            jcos(a) * s, up * s, jsin(a) * s,
            rand_range(0.35, 0.8), rand_range(0.08, 0.22), 9.0,
            r, g, b
        );
    }
}

"""Advance every live particle: integrate, apply gravity, burn down."""
def update_particles(step: float) {
    for i in range(len(sparks)) {
        p = sparks[i];
        if p.life > 0.0 {
            p.x += p.vx * step;
            p.y += p.vy * step;
            p.z += p.vz * step;
            p.vy -= p.grav * step;
            if p.y < 0.05 and p.grav > 0.0 {
                p.y = 0.05;
                p.vy = -p.vy * 0.35;
                p.vx = p.vx * 0.7;
                p.vz = p.vz * 0.7;
            }
            p.life -= step;
        }
    }
}

# ─── Enemies ─────────────────────────────────────────────────────────────────

"""(Re)place a drone somewhere in the arena in front of the player."""
def respawn_enemy(e: Enemy) {
    e.x = rand_range(-14.0, 14.0);
    e.base_y = rand_range(1.2, 5.0);
    e.z = rand_range(-16.0, 0.0);
    e.phase = rand_range(0.0, 6.28);
    e.y = e.base_y;
    e.strafe_dir = 1.0 if rand01() < 0.5 else -1.0;
    e.strafe_t = rand_range(1.0, 2.6);
    e.fire_t = rand_range(2.0, 5.0);
    e.charge = 0.0;
    e.respawn_t = 0.0;
    e.alive = True;
}

"""Loose a plasma bolt at the player's current position, with a little spread."""
def enemy_fire(e: Enemy) {
    tx = px + rand_range(-1.4, 1.4);
    ty = py + rand_range(-0.7, 0.7);
    tz = pz + rand_range(-1.4, 1.4);
    dx = tx - e.x;
    dy = ty - e.y;
    dz = tz - e.z;
    d = jsqrt(dx * dx + dy * dy + dz * dz);
    if d < 0.01 {
        return;
    }
    v = 12.0;
    for i in range(len(shots)) {
        s = shots[i];
        if s.life <= 0.0 {
            s.x = e.x;
            s.y = e.y;
            s.z = e.z;
            s.vx = dx / d * v;
            s.vy = dy / d * v;
            s.vz = dz / d * v;
            s.life = 4.0;
            return;
        }
    }
}

"""Drone brain: bob, strafe around the player, hold a comfortable range,
telegraph with a charge glow, then shoot. Dead drones wait out respawn_t."""
def update_enemies(step: float) {
    for i in range(len(enemies)) {
        e = enemies[i];
        if e.alive {
            e.y = e.base_y + 0.4 * jsin(world_t * 1.5 + e.phase);

            dx = px - e.x;
            dz = pz - e.z;
            dist = jsqrt(dx * dx + dz * dz);
            if dist > 0.5 {
                nx = dx / dist;
                nz = dz / dist;

                e.strafe_t -= step;
                if e.strafe_t <= 0.0 {
                    e.strafe_dir = 1.0 if rand01() < 0.5 else -1.0;
                    e.strafe_t = rand_range(1.0, 2.6);
                }
                e.x += -nz * e.strafe_dir * 3.0 * step;
                e.z += nx * e.strafe_dir * 3.0 * step;

                if dist > 17.0 {
                    e.x += nx * 2.8 * step;
                    e.z += nz * 2.8 * step;
                } elif dist < 8.0 {
                    e.x -= nx * 3.4 * step;
                    e.z -= nz * 3.4 * step;
                }
            }

            if e.x > 16.0 { e.x = 16.0; }
            if e.x < -16.0 { e.x = -16.0; }
            if e.z > 8.0 { e.z = 8.0; }
            if e.z < -18.0 { e.z = -18.0; }

            e.fire_t -= step;
            if e.fire_t <= 0.0 and dist < 28.0 {
                e.charge += step;
                if e.charge >= CHARGE_T {
                    enemy_fire(e);
                    e.charge = 0.0;
                    e.fire_t = rand_range(2.8, 5.4);
                }
            }
        } else {
            e.respawn_t -= step;
            if e.respawn_t <= 0.0 {
                respawn_enemy(e);
            }
        }
    }
}

"""Kill a drone: score it, scrap it, schedule its replacement."""
def kill_enemy(e: Enemy) {
    e.alive = False;
    e.respawn_t = rand_range(1.2, 2.6);
    score += 1;
    burst(e.x, e.y, e.z, 12, 7.0, 235, 90, 60);
    burst(e.x, e.y, e.z, 5, 4.0, 255, 210, 110);
}

# ─── Player damage ───────────────────────────────────────────────────────────

"""Take a hit: flash, interrupt regen, and respawn on zero."""
def damage_player(amount: float) {
    if invuln_t > 0.0 {
        return;
    }
    hp -= amount;
    hurt_t = 0.45;
    safe_t = 0.0;
    if hp <= 0.0 {
        deaths += 1;
        hp = HP_MAX;
        invuln_t = 2.5;
        px = 0.0;
        py = 2.0;
        pz = 12.0;
    }
}

# ─── Rockets ─────────────────────────────────────────────────────────────────

"""Fire a rocket from the eye along the current aim, reusing a dead pool slot."""
def fire_rocket {
    yaw_r = yaw * DEG2RAD;
    pitch_r = pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 30.0;
    for i in range(len(rockets)) {
        r = rockets[i];
        if r.life <= 0.0 {
            r.x = px + dx * 1.2;
            r.y = py - 0.25 + dy * 1.2;
            r.z = pz + dz * 1.2;
            r.vx = dx * speed;
            r.vy = dy * speed;
            r.vz = dz * speed;
            r.life = 3.0;
            kick_t = 0.22;
            muzzle_t = 0.07;
            return;
        }
    }
}

"""Splash damage: scrap every drone near the blast, then throw debris."""
def explode(x: float, y: float, z: float) {
    for i in range(len(enemies)) {
        e = enemies[i];
        if e.alive {
            ddx = e.x - x;
            ddy = e.y - y;
            ddz = e.z - z;
            if ddx * ddx + ddy * ddy + ddz * ddz < 7.3 {
                kill_enemy(e);
            }
        }
    }
    burst(x, y, z, 10, 6.0, 255, 150, 60);
    burst(x, y, z, 6, 3.5, 255, 220, 120);
    spawn_particle(x, y, z, 0.0, 0.6, 0.0, 0.28, 0.9, -0.5, 255, 235, 160);
}

"""Advance rockets, trail smoke, and detonate on drones or the floor."""
def update_rockets(step: float) {
    for i in range(len(rockets)) {
        r = rockets[i];
        if r.life > 0.0 {
            r.x += r.vx * step;
            r.y += r.vy * step;
            r.z += r.vz * step;
            r.life -= step;
            spawn_particle(
                r.x, r.y, r.z,
                rand_range(-0.4, 0.4), rand_range(0.1, 0.6), rand_range(-0.4, 0.4),
                0.35, 0.1, -0.6, 120, 122, 130
            );
            boom = False;
            if r.y <= 0.1 {
                boom = True;
            }
            for ti in range(len(enemies)) {
                e = enemies[ti];
                if e.alive and not boom {
                    ddx = r.x - e.x;
                    ddy = r.y - e.y;
                    ddz = r.z - e.z;
                    if ddx * ddx + ddy * ddy + ddz * ddz < 2.1 {
                        boom = True;
                    }
                }
            }
            if r.life <= 0.0 {
                boom = True;
            }
            if boom {
                explode(r.x, r.y, r.z);
                r.life = 0.0;
            }
        }
    }
}

"""Advance plasma bolts and resolve hits on the player."""
def update_shots(step: float) {
    for i in range(len(shots)) {
        s = shots[i];
        if s.life > 0.0 {
            s.x += s.vx * step;
            s.y += s.vy * step;
            s.z += s.vz * step;
            s.life -= step;
            if s.y < 0.05 {
                s.life = 0.0;
                burst(s.x, 0.1, s.z, 3, 2.0, 150, 90, 200);
            } else {
                ddx = s.x - px;
                ddy = s.y - py;
                ddz = s.z - pz;
                if ddx * ddx + ddy * ddy + ddz * ddz < 1.2 {
                    s.life = 0.0;
                    damage_player(9.0);
                }
            }
        }
    }
}

# ─── Input (mouse-look, WASD, capture toggle) ────────────────────────────────

"""Read keyboard + mouse and update camera orientation + position this frame."""
def handle_input(step: float) {
    turn = 90.0 * step;

    if key_tapped(KEY_TAB) {
        if mouse_captured {
            unlock_mouse();
            mouse_captured = False;
        } else {
            lock_mouse();
            mouse_captured = True;
            mouse_warmup = 8;
        }
    }
    if not mouse_captured and mouse_pressed(MOUSE_LEFT) {
        lock_mouse();
        mouse_captured = True;
        mouse_warmup = 8;
    }

    if key_held(KEY_LEFT) {
        yaw += turn;
    }
    if key_held(KEY_RIGHT) {
        yaw -= turn;
    }
    if key_held(KEY_UP) {
        pitch += turn;
    }
    if key_held(KEY_DOWN) {
        pitch -= turn;
    }

    if mouse_captured {
        mx = mouse_x();
        my = mouse_y();
        if mouse_warmup > 0 {
            mouse_warmup -= 1;
        } else {
            ddx = mx - prev_mx;
            ddy = my - prev_my;
            if ddx < 150.0 and ddx > -150.0 and ddy < 150.0 and ddy > -150.0 {
                yaw -= ddx * mouse_sens;
                pitch -= ddy * mouse_sens;
            }
        }
        prev_mx = mx;
        prev_my = my;
    }

    if pitch > 85.0 {
        pitch = 85.0;
    }
    if pitch < -85.0 {
        pitch = -85.0;
    }

    yaw_r = yaw * DEG2RAD;
    fwd_x = -jsin(yaw_r);
    fwd_z = -jcos(yaw_r);
    rgt_x = jcos(yaw_r);
    rgt_z = -jsin(yaw_r);
    move = 8.0 * step;
    if key_held(KEY_W) {
        px += fwd_x * move;
        pz += fwd_z * move;
    }
    if key_held(KEY_S) {
        px -= fwd_x * move;
        pz -= fwd_z * move;
    }
    if key_held(KEY_D) {
        px += rgt_x * move;
        pz += rgt_z * move;
    }
    if key_held(KEY_A) {
        px -= rgt_x * move;
        pz -= rgt_z * move;
    }
}

# ─── Drawing ─────────────────────────────────────────────────────────────────

"""Draw one drone: hull, top fin, side pods — glowing through its charge-up."""
def draw_enemy(e: Enemy) {
    k = e.charge / CHARGE_T;
    r = 200;
    g = 60;
    b = 50;
    if k > 0.66 {
        r = 255;
        g = 215;
        b = 90;
    } elif k > 0.33 {
        r = 240;
        g = 140;
        b = 70;
    }
    s = 1.3 + 0.18 * k;
    draw_box(e.x, e.y, e.z, s, s, s, r, g, b);
    draw_box(e.x, e.y + 0.75, e.z, 0.28, 0.42, 0.9, r, g, b);
    draw_box(e.x - 0.85, e.y, e.z, 0.34, 0.34, 0.34, 150, 45, 40);
    draw_box(e.x + 0.85, e.y, e.z, 0.34, 0.34, 0.34, 150, 45, 40);
}

"""Draw the first-person rocket launcher, bobbing, kicking, and flashing.

The trick: translate to the camera and undo its rotations, so every box is
laid out in view space (x right, y up, -z forward) with plain axis-aligned
geometry."""
def draw_weapon {
    rlPushMatrix();
    rlTranslatef(px, py, pz);
    rlRotatef(yaw, 0.0, 1.0, 0.0);
    rlRotatef(pitch, 1.0, 0.0, 0.0);

    wob = jsin(world_t * 2.1) * 0.008;
    kz = kick_t * 0.5;

    draw_box(0.34, -0.27 + wob, -0.94 + kz, 0.10, 0.10, 0.60, 66, 68, 78);
    draw_box(0.34, -0.27 + wob, -1.27 + kz, 0.14, 0.14, 0.08, 42, 43, 50);
    draw_box(0.34, -0.27 + wob, -1.32 + kz, 0.07, 0.07, 0.07, 255, 140, 60);
    draw_box(0.34, -0.37 + wob, -0.74 + kz, 0.045, 0.13, 0.075, 48, 48, 55);
    draw_box(0.34, -0.195 + wob, -1.05 + kz, 0.02, 0.04, 0.028, 90, 92, 102);

    if muzzle_t > 0.0 {
        fs = 0.34 * (muzzle_t / 0.07);
        draw_box(0.34, -0.27 + wob, -1.45 + kz, fs, fs, fs, 255, 235, 140);
    }
    rlPopMatrix();
}

"""Axis-aligned filled rectangle in the 2D overlay (pixel space)."""
def draw_rect2d(x: float, y: float, w: float, h: float, r: int, g: int, b: int) {
    rlBegin(RL_TRIANGLES);
    rlColor4ub(r, g, b, 255);
    rlVertex3f(x, y, 0.0);
    rlVertex3f(x, y + h, 0.0);
    rlVertex3f(x + w, y + h, 0.0);
    rlVertex3f(x, y, 0.0);
    rlVertex3f(x + w, y + h, 0.0);
    rlVertex3f(x + w, y, 0.0);
    rlEnd();
}

"""Crosshair, health bar, hit flash — the pixel-space HUD pass."""
def draw_hud {
    gap = 6.0 + kick_t * 40.0;
    draw_rect2d(480.0 - gap - 10.0, 299.0, 10.0, 2.0, 215, 220, 230);
    draw_rect2d(480.0 + gap, 299.0, 10.0, 2.0, 215, 220, 230);
    draw_rect2d(479.0, 300.0 - gap - 10.0, 2.0, 10.0, 215, 220, 230);
    draw_rect2d(479.0, 300.0 + gap, 2.0, 10.0, 215, 220, 230);

    if fire_cd > 0.0 {
        draw_rect2d(460.0, 318.0, 40.0 * (1.0 - fire_cd / 0.55), 3.0, 255, 150, 60);
    }

    draw_rect2d(24.0, 560.0, 244.0, 20.0, 26, 28, 34);
    hpk = hp / HP_MAX;
    fr = 90;
    fg = 220;
    fb = 120;
    if hpk < 0.25 {
        fr = 240;
        fg = 80;
        fb = 70;
    } elif hpk < 0.5 {
        fr = 250;
        fg = 200;
        fb = 80;
    }
    if invuln_t > 0.0 and jsin(world_t * 18.0) > 0.0 {
        fr = 160;
        fg = 170;
        fb = 190;
    }
    draw_rect2d(27.0, 563.0, 238.0 * hpk, 14.0, fr, fg, fb);

    if hurt_t > 0.0 {
        draw_rect2d(0.0, 0.0, 960.0, 6.0, 205, 60, 50);
        draw_rect2d(0.0, 594.0, 960.0, 6.0, 205, 60, 50);
        draw_rect2d(0.0, 0.0, 6.0, 600.0, 205, 60, 50);
        draw_rect2d(954.0, 0.0, 6.0, 600.0, 205, 60, 50);
    }
}

# ─── Browser entry points (replace the native `with entry` loop) ─────────────

"""Set up the window and object pools. Call once before the first frame()."""
def init {
    open_window(960, 600, "Jac Rocket Arena");
    for n in range(8) {
        e = Enemy(
            x=0.0, y=0.0, z=0.0, base_y=0.0, phase=0.0,
            strafe_dir=1.0, strafe_t=0.0, fire_t=0.0, charge=0.0,
            respawn_t=0.0, alive=False
        );
        respawn_enemy(e);
        enemies.append(e);
    }
    for n in range(10) {
        rockets.append(
            Rocket(x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0, life=0.0)
        );
    }
    for n in range(24) {
        shots.append(
            Shot(x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0, life=0.0)
        );
    }
    for n in range(90) {
        sparks.append(
            Particle(
                x=0.0, y=0.0, z=0.0, vx=0.0, vy=0.0, vz=0.0,
                life=0.0, fade=1.0, size=0.1, grav=9.0, r=255, g=255, b=255
            )
        );
    }
}

"""Advance and render one frame. Returns True when the game wants to close."""
def frame -> bool {
    step = dt();
    world_t += step;

    if hurt_t > 0.0 { hurt_t -= step; }
    if invuln_t > 0.0 { invuln_t -= step; }
    if kick_t > 0.0 { kick_t -= step; }
    if muzzle_t > 0.0 { muzzle_t -= step; }
    safe_t += step;
    if safe_t > 4.0 and hp < HP_MAX {
        hp += 7.0 * step;
        if hp > HP_MAX { hp = HP_MAX; }
    }

    handle_input(step);
    fire_cd -= step;
    want_fire = key_held(KEY_SPACE) or (mouse_captured and mouse_pressed(MOUSE_LEFT));
    if want_fire and fire_cd <= 0.0 {
        fire_rocket();
        fire_cd = 0.55;
    }

    update_enemies(step);
    update_rockets(step);
    update_shots(step);
    update_particles(step);

    begin_frame(16, 16, 18);
    set_camera(px, py, pz, yaw, pitch, 1.6);
    draw_floor(20, 1.5);

    for i in range(len(enemies)) {
        e = enemies[i];
        if e.alive {
            draw_enemy(e);
        }
    }
    for i in range(len(rockets)) {
        r = rockets[i];
        if r.life > 0.0 {
            draw_box(r.x, r.y, r.z, 0.16, 0.16, 0.42, 205, 206, 212);
            draw_box(r.x, r.y, r.z - 0.26, 0.11, 0.11, 0.12, 255, 140, 60);
        }
    }
    for i in range(len(shots)) {
        s = shots[i];
        if s.life > 0.0 {
            w = 0.26 + 0.06 * jsin(world_t * 22.0 + float(i));
            draw_box(s.x, s.y, s.z, w, w, w, 190, 90, 255);
        }
    }
    for i in range(len(sparks)) {
        p = sparks[i];
        if p.life > 0.0 {
            ps = p.size * (p.life / p.fade);
            draw_box(p.x, p.y, p.z, ps, ps, ps, p.r, p.g, p.b);
        }
    }
    draw_weapon();

    end_camera(960.0, 600.0);
    rlDisableDepthTest();
    draw_hud();
    draw_fps(10, 10);
    end_frame();
    return should_close();
}

"""Current score (drones destroyed) - for the HTML HUD."""
def get_score -> int {
    return score;
}

"""Current health in [0, 100] - for the HTML HUD."""
def get_hp -> float {
    return hp;
}

"""Times the player has been destroyed - for the HTML HUD."""
def get_deaths -> int {
    return deaths;
}
