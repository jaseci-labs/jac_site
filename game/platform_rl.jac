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
     MOUSE_LEFT: int = 0;

glob SCREEN_W: float = 960.0,
     SCREEN_H: float = 600.0;

def open_window {
    InitWindow(960, 600, "Jac Rocket Arena");
}

def should_close -> bool {
    return WindowShouldClose();
}

def frame_dt -> float {
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

def begin_overlay(width: float, height: float) {
    EndMode3D();
    rlMatrixMode(RL_PROJECTION);
    rlLoadIdentity();
    rlOrtho(0.0, width, height, 0.0, -1.0, 1.0);
    rlMatrixMode(RL_MODELVIEW);
    rlLoadIdentity();
    rlDisableDepthTest();
}

def begin_model(x: float, y: float, z: float, yaw_deg: float, pitch_deg: float) {
    rlPushMatrix();
    rlTranslatef(x, y, z);
    rlRotatef(yaw_deg, 0.0, 1.0, 0.0);
    rlRotatef(pitch_deg, 1.0, 0.0, 0.0);
}

def end_model {
    rlPopMatrix();
}

def draw_fps(x: int, y: int) {
    DrawFPS(x, y);
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
