import from raylib {
    def InitWindow(width: i32, height: i32, title: str) -> None;  def WindowShouldClose -> bool;  def BeginDrawing -> None;  def EndDrawing -> None;  def rlClearColor(
        r: u8, g: u8, b: u8, a: u8
    ) -> None;  def rlClearScreenBuffers -> None;  def DrawFPS(
        pos_x: i32, pos_y: i32
    ) -> None;  def IsKeyDown(key: i32) -> bool;  def IsKeyPressed(key: i32) -> bool;  def GetFrameTime -> f32;  def GetMouseX -> i32;  def GetMouseY -> i32;  def IsMouseButtonPressed(
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
    ) -> None;  def EndMode3D -> None;
}

glob RL_MODELVIEW: int = 0x1700,
     RL_PROJECTION: int = 0x1701,
     RL_LINES: int = 0x0001,
     RL_TRIANGLES: int = 0x0004;

def should_close -> bool {
    return WindowShouldClose();
}

def dt -> float {
    return GetFrameTime();
}

def key_held(code: int) -> bool {
    return IsKeyDown(code);
}

def key_tapped(code: int) -> bool {
    return IsKeyPressed(code);
}

def mouse_x -> float {
    return float(GetMouseX());
}

def mouse_y -> float {
    return float(GetMouseY());
}

def mouse_pressed(button: int) -> bool {
    return IsMouseButtonPressed(button);
}

def lock_mouse {
    DisableCursor();
}

def unlock_mouse {
    EnableCursor();
}

def begin_frame(r: int, g: int, b: int) {
    BeginDrawing();
    rlClearColor(r, g, b, 255);
    rlClearScreenBuffers();
    rlEnableDepthTest();
}

def end_frame {
    EndDrawing();
}

def end_camera(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
}

def draw_fps(x: int, y: int) {
    DrawFPS(x, y);
}

def set_camera(
    px_: float, py_: float, pz_: float, yaw_deg: float, pitch_deg: float, aspect: float
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
    rlTranslatef(-px_, -py_, -pz_);
}

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

def _shade(c: int, pct: int) -> int {
    v = c * pct // 100;
    return v if v < 255 else 255;
}

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

glob HP_MAX: float = 100.0,
     CHARGE_T: float = 0.95,
     hp: float = 100.0,
     hurt_t: float = 0.0,
     safe_t: float = 10.0,
     invuln_t: float = 0.0,
     deaths: int = 0,
     kick_t: float = 0.0,
     muzzle_t: float = 0.0;

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

def jsin(a: float) -> float {
    return jcos(a - 1.5707963267948796);
}

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

def rand01 -> float {
    rng = (rng * 1103515245 + 12345) % 2147483648;
    return float(rng) / 2147483648.0;
}

def rand_range(lo: float, hi: float) -> float {
    return lo + rand01() * (hi - lo);
}

obj EnemyPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        base_y: list[float] = [],
        phase: list[float] = [],
        strafe_dir: list[float] = [],
        strafe_t: list[float] = [],
        fire_t: list[float] = [],
        charge: list[float] = [],
        respawn_t: list[float] = [],
        alive: list[int] = [];
}

obj RocketPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [];
}

obj ShotPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [];
}

obj SparkPool {
    has x: list[float] = [],
        y: list[float] = [],
        z: list[float] = [],
        vx: list[float] = [],
        vy: list[float] = [],
        vz: list[float] = [],
        life: list[float] = [],
        fade: list[float] = [],
        size: list[float] = [],
        grav: list[float] = [],
        r: list[int] = [],
        g: list[int] = [],
        b: list[int] = [];
}

obj Game {
    has enemies: EnemyPool = EnemyPool(),
        rockets: RocketPool = RocketPool(),
        shots: ShotPool = ShotPool(),
        sparks: SparkPool = SparkPool();
}

def spawn_particle(
    sp: &mut SparkPool,
    x: float,
    y: float,
    z: float,
    vx: float,
    vy: float,
    vz: float,
    life: float,
    size: float,
    grav: float,
    r: int,
    g: int,
    b: int
) {
    n = len(sp.life);
    for i in range(n) {
        if sp.life[i] <= 0.0 {
            sp.x[i] = x;
            sp.y[i] = y;
            sp.z[i] = z;
            sp.vx[i] = vx;
            sp.vy[i] = vy;
            sp.vz[i] = vz;
            sp.life[i] = life;
            sp.fade[i] = life;
            sp.size[i] = size;
            sp.grav[i] = grav;
            sp.r[i] = r;
            sp.g[i] = g;
            sp.b[i] = b;
            return;
        }
    }
}

def burst(
    sp: &mut SparkPool,
    x: float,
    y: float,
    z: float,
    n: int,
    speed: float,
    r: int,
    g: int,
    b: int
) {
    for i in range(n) {
        a = rand_range(0.0, 6.283);
        up = rand_range(0.2, 1.0);
        s = rand_range(0.3, 1.0) * speed;
        spawn_particle(
            sp,
            x,
            y,
            z,
            jcos(a) * s,
            up * s,
            jsin(a) * s,
            rand_range(0.35, 0.8),
            rand_range(0.08, 0.22),
            9.0,
            r,
            g,
            b
        );
    }
}

def update_particles(sp: &mut SparkPool, step: float) {
    n = len(sp.life);
    for i in range(n) {
        if sp.life[i] > 0.0 {
            sp.x[i] += sp.vx[i] * step;
            sp.y[i] += sp.vy[i] * step;
            sp.z[i] += sp.vz[i] * step;
            sp.vy[i] -= sp.grav[i] * step;
            if sp.y[i] < 0.05 and sp.grav[i] > 0.0 {
                sp.y[i] = 0.05;
                sp.vy[i] = -sp.vy[i] * 0.35;
                sp.vx[i] = sp.vx[i] * 0.7;
                sp.vz[i] = sp.vz[i] * 0.7;
            }
            sp.life[i] -= step;
        }
    }
}

def respawn_enemy(en: &mut EnemyPool, i: int) {
    en.x[i] = rand_range(-14.0, 14.0);
    en.base_y[i] = rand_range(1.2, 5.0);
    en.z[i] = rand_range(-16.0, 0.0);
    en.phase[i] = rand_range(0.0, 6.28);
    en.y[i] = en.base_y[i];
    en.strafe_dir[i] = 1.0 if rand01() < 0.5 else -1.0;
    en.strafe_t[i] = rand_range(1.0, 2.6);
    en.fire_t[i] = rand_range(2.0, 5.0);
    en.charge[i] = 0.0;
    en.respawn_t[i] = 0.0;
    en.alive[i] = 1;
}

def enemy_fire(sh: &mut ShotPool, ex: float, ey: float, ez: float) {
    tx = px + rand_range(-1.4, 1.4);
    ty = py + rand_range(-0.7, 0.7);
    tz = pz + rand_range(-1.4, 1.4);
    dx = tx - ex;
    dy = ty - ey;
    dz = tz - ez;
    d = jsqrt(dx * dx + dy * dy + dz * dz);
    if d < 0.01 {
        return;
    }
    v = 12.0;
    n = len(sh.life);
    for i in range(n) {
        if sh.life[i] <= 0.0 {
            sh.x[i] = ex;
            sh.y[i] = ey;
            sh.z[i] = ez;
            sh.vx[i] = dx / d * v;
            sh.vy[i] = dy / d * v;
            sh.vz[i] = dz / d * v;
            sh.life[i] = 4.0;
            return;
        }
    }
}

def update_enemies(g: &mut Game, step: float) {
    n = len(g.enemies.x);
    for i in range(n) {
        if g.enemies.alive[i] == 1 {
            g.enemies.y[i] = g.enemies.base_y[i] + 0.4 * jsin(
                world_t * 1.5 + g.enemies.phase[i]
            );

            dx = px - g.enemies.x[i];
            dz = pz - g.enemies.z[i];
            dist = jsqrt(dx * dx + dz * dz);
            if dist > 0.5 {
                nx = dx / dist;
                nz = dz / dist;

                g.enemies.strafe_t[i] -= step;
                if g.enemies.strafe_t[i] <= 0.0 {
                    g.enemies.strafe_dir[i] = 1.0 if rand01() < 0.5 else -1.0;
                    g.enemies.strafe_t[i] = rand_range(1.0, 2.6);
                }
                g.enemies.x[i] += -nz * g.enemies.strafe_dir[i] * 3.0 * step;
                g.enemies.z[i] += nx * g.enemies.strafe_dir[i] * 3.0 * step;

                if dist > 17.0 {
                    g.enemies.x[i] += nx * 2.8 * step;
                    g.enemies.z[i] += nz * 2.8 * step;
                } elif dist < 8.0 {
                    g.enemies.x[i] -= nx * 3.4 * step;
                    g.enemies.z[i] -= nz * 3.4 * step;
                }
            }

            if g.enemies.x[i] > 16.0 {
                g.enemies.x[i] = 16.0;
            }
            if g.enemies.x[i] < -16.0 {
                g.enemies.x[i] = -16.0;
            }
            if g.enemies.z[i] > 8.0 {
                g.enemies.z[i] = 8.0;
            }
            if g.enemies.z[i] < -18.0 {
                g.enemies.z[i] = -18.0;
            }

            g.enemies.fire_t[i] -= step;
            if g.enemies.fire_t[i] <= 0.0 and dist < 28.0 {
                g.enemies.charge[i] += step;
                if g.enemies.charge[i] >= CHARGE_T {
                    enemy_fire(
                        &mut g.shots, g.enemies.x[i], g.enemies.y[i], g.enemies.z[i]
                    );
                    g.enemies.charge[i] = 0.0;
                    g.enemies.fire_t[i] = rand_range(2.8, 5.4);
                }
            }
        } else {
            g.enemies.respawn_t[i] -= step;
            if g.enemies.respawn_t[i] <= 0.0 {
                respawn_enemy(&mut g.enemies, i);
            }
        }
    }
}

def kill_enemy(g: &mut Game, i: int) {
    g.enemies.alive[i] = 0;
    g.enemies.respawn_t[i] = rand_range(1.2, 2.6);
    score += 1;
    ex = g.enemies.x[i];
    ey = g.enemies.y[i];
    ez = g.enemies.z[i];
    burst(&mut g.sparks, ex, ey, ez, 12, 7.0, 235, 90, 60);
    burst(&mut g.sparks, ex, ey, ez, 5, 4.0, 255, 210, 110);
}

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

def fire_rocket(rk: &mut RocketPool) {
    yaw_r = yaw * DEG2RAD;
    pitch_r = pitch * DEG2RAD;
    cp = jcos(pitch_r);
    dx = -jsin(yaw_r) * cp;
    dy = jsin(pitch_r);
    dz = -jcos(yaw_r) * cp;
    speed = 30.0;
    n = len(rk.life);
    for i in range(n) {
        if rk.life[i] <= 0.0 {
            rk.x[i] = px + dx * 1.2;
            rk.y[i] = py - 0.25 + dy * 1.2;
            rk.z[i] = pz + dz * 1.2;
            rk.vx[i] = dx * speed;
            rk.vy[i] = dy * speed;
            rk.vz[i] = dz * speed;
            rk.life[i] = 3.0;
            kick_t = 0.22;
            muzzle_t = 0.07;
            return;
        }
    }
}

def explode(g: &mut Game, x: float, y: float, z: float) {
    n = len(g.enemies.x);
    for i in range(n) {
        if g.enemies.alive[i] == 1 {
            ddx = g.enemies.x[i] - x;
            ddy = g.enemies.y[i] - y;
            ddz = g.enemies.z[i] - z;
            if ddx * ddx + ddy * ddy + ddz * ddz < 7.3 {
                kill_enemy(g, i);
            }
        }
    }
    burst(&mut g.sparks, x, y, z, 10, 6.0, 255, 150, 60);
    burst(&mut g.sparks, x, y, z, 6, 3.5, 255, 220, 120);
    spawn_particle(
        &mut g.sparks, x, y, z, 0.0, 0.6, 0.0, 0.28, 0.9, -0.5, 255, 235, 160
    );
}

def update_rockets(g: &mut Game, step: float) {
    n = len(g.rockets.life);
    en_count = len(g.enemies.x);
    for i in range(n) {
        if g.rockets.life[i] > 0.0 {
            g.rockets.x[i] += g.rockets.vx[i] * step;
            g.rockets.y[i] += g.rockets.vy[i] * step;
            g.rockets.z[i] += g.rockets.vz[i] * step;
            g.rockets.life[i] -= step;
            rx = g.rockets.x[i];
            ry = g.rockets.y[i];
            rz = g.rockets.z[i];
            spawn_particle(
                &mut g.sparks,
                rx,
                ry,
                rz,
                rand_range(-0.4, 0.4),
                rand_range(0.1, 0.6),
                rand_range(-0.4, 0.4),
                0.35,
                0.1,
                -0.6,
                120,
                122,
                130
            );
            boom = False;
            if ry <= 0.1 {
                boom = True;
            }
            for ti in range(en_count) {
                if g.enemies.alive[ti] == 1 and not boom {
                    ddx = rx - g.enemies.x[ti];
                    ddy = ry - g.enemies.y[ti];
                    ddz = rz - g.enemies.z[ti];
                    if ddx * ddx + ddy * ddy + ddz * ddz < 2.1 {
                        boom = True;
                    }
                }
            }
            if g.rockets.life[i] <= 0.0 {
                boom = True;
            }
            if boom {
                explode(g, rx, ry, rz);
                g.rockets.life[i] = 0.0;
            }
        }
    }
}

def update_shots(g: &mut Game, step: float) {
    n = len(g.shots.life);
    for i in range(n) {
        if g.shots.life[i] > 0.0 {
            g.shots.x[i] += g.shots.vx[i] * step;
            g.shots.y[i] += g.shots.vy[i] * step;
            g.shots.z[i] += g.shots.vz[i] * step;
            g.shots.life[i] -= step;
            if g.shots.y[i] < 0.05 {
                g.shots.life[i] = 0.0;
                burst(
                    &mut g.sparks, g.shots.x[i], 0.1, g.shots.z[i], 3, 2.0, 150, 90, 200
                );
            } else {
                ddx = g.shots.x[i] - px;
                ddy = g.shots.y[i] - py;
                ddz = g.shots.z[i] - pz;
                if ddx * ddx + ddy * ddy + ddz * ddz < 1.2 {
                    g.shots.life[i] = 0.0;
                    damage_player(9.0);
                }
            }
        }
    }
}

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

def draw_enemy(ex: float, ey: float, ez: float, k: float) {
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
    draw_box(ex, ey, ez, s, s, s, r, g, b);
    draw_box(ex, ey + 0.75, ez, 0.28, 0.42, 0.9, r, g, b);
    draw_box(ex - 0.85, ey, ez, 0.34, 0.34, 0.34, 150, 45, 40);
    draw_box(ex + 0.85, ey, ez, 0.34, 0.34, 0.34, 150, 45, 40);
}

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

def init -> Game {
    InitWindow(960, 600, "Jac Rocket Arena");
    g: own Game = Game();
    for n in range(8) {
        g.enemies.x.append(0.0);
        g.enemies.y.append(0.0);
        g.enemies.z.append(0.0);
        g.enemies.base_y.append(0.0);
        g.enemies.phase.append(0.0);
        g.enemies.strafe_dir.append(1.0);
        g.enemies.strafe_t.append(0.0);
        g.enemies.fire_t.append(0.0);
        g.enemies.charge.append(0.0);
        g.enemies.respawn_t.append(0.0);
        g.enemies.alive.append(0);
        respawn_enemy(&mut g.enemies, n);
    }
    for n in range(10) {
        g.rockets.x.append(0.0);
        g.rockets.y.append(0.0);
        g.rockets.z.append(0.0);
        g.rockets.vx.append(0.0);
        g.rockets.vy.append(0.0);
        g.rockets.vz.append(0.0);
        g.rockets.life.append(0.0);
    }
    for n in range(24) {
        g.shots.x.append(0.0);
        g.shots.y.append(0.0);
        g.shots.z.append(0.0);
        g.shots.vx.append(0.0);
        g.shots.vy.append(0.0);
        g.shots.vz.append(0.0);
        g.shots.life.append(0.0);
    }
    for n in range(90) {
        g.sparks.x.append(0.0);
        g.sparks.y.append(0.0);
        g.sparks.z.append(0.0);
        g.sparks.vx.append(0.0);
        g.sparks.vy.append(0.0);
        g.sparks.vz.append(0.0);
        g.sparks.life.append(0.0);
        g.sparks.fade.append(1.0);
        g.sparks.size.append(0.1);
        g.sparks.grav.append(9.0);
        g.sparks.r.append(255);
        g.sparks.g.append(255);
        g.sparks.b.append(255);
    }
    return g;
}

def frame(g: &mut Game) -> bool {
    step = dt();
    world_t += step;

    if hurt_t > 0.0 {
        hurt_t -= step;
    }
    if invuln_t > 0.0 {
        invuln_t -= step;
    }
    if kick_t > 0.0 {
        kick_t -= step;
    }
    if muzzle_t > 0.0 {
        muzzle_t -= step;
    }
    safe_t += step;
    if safe_t > 4.0 and hp < HP_MAX {
        hp += 7.0 * step;
        if hp > HP_MAX {
            hp = HP_MAX;
        }
    }

    handle_input(step);
    fire_cd -= step;
    want_fire = key_held(KEY_SPACE) or (mouse_captured and mouse_pressed(MOUSE_LEFT));
    if want_fire and fire_cd <= 0.0 {
        fire_rocket(&mut g.rockets);
        fire_cd = 0.55;
    }

    update_enemies(g, step);
    update_rockets(g, step);
    update_shots(g, step);
    update_particles(&mut g.sparks, step);

    begin_frame(16, 16, 18);
    set_camera(px, py, pz, yaw, pitch, 1.6);
    draw_floor(20, 1.5);

    en_count = len(g.enemies.x);
    for i in range(en_count) {
        if g.enemies.alive[i] == 1 {
            draw_enemy(
                g.enemies.x[i],
                g.enemies.y[i],
                g.enemies.z[i],
                g.enemies.charge[i] / CHARGE_T
            );
        }
    }
    rk_count = len(g.rockets.life);
    for i in range(rk_count) {
        if g.rockets.life[i] > 0.0 {
            draw_box(
                g.rockets.x[i],
                g.rockets.y[i],
                g.rockets.z[i],
                0.16,
                0.16,
                0.42,
                205,
                206,
                212
            );
            draw_box(
                g.rockets.x[i],
                g.rockets.y[i],
                g.rockets.z[i] - 0.26,
                0.11,
                0.11,
                0.12,
                255,
                140,
                60
            );
        }
    }
    sh_count = len(g.shots.life);
    for i in range(sh_count) {
        if g.shots.life[i] > 0.0 {
            w = 0.26 + 0.06 * jsin(world_t * 22.0 + float(i));
            draw_box(g.shots.x[i], g.shots.y[i], g.shots.z[i], w, w, w, 190, 90, 255);
        }
    }
    pt_count = len(g.sparks.life);
    for i in range(pt_count) {
        if g.sparks.life[i] > 0.0 {
            ps = g.sparks.size[i] * (g.sparks.life[i] / g.sparks.fade[i]);
            draw_box(
                g.sparks.x[i],
                g.sparks.y[i],
                g.sparks.z[i],
                ps,
                ps,
                ps,
                g.sparks.r[i],
                g.sparks.g[i],
                g.sparks.b[i]
            );
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

def get_score -> int {
    return score;
}

def get_hp -> float {
    return hp;
}

def get_deaths -> int {
    return deaths;
}
