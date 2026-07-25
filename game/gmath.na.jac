glob PI: float = 3.141592653589793,
     TWO_PI: float = 6.283185307179586,
     HALF_PI: float = 1.5707963267948796,
     DEG2RAD: float = 0.017453292519943295;

def jcos(a: float) -> float {
    while a > PI {
        a -= TWO_PI;
    }
    while a < -PI {
        a += TWO_PI;
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
    return jcos(a - HALF_PI);
}

def jsqrt(v: float) -> float {
    if v <= 0.0 {
        return 0.0;
    }
    guess = v if v > 1.0 else 1.0;
    i = 0;
    while i < 9 {
        guess = 0.5 * (guess + v / guess);
        i += 1;
    }
    return guess;
}

def lerp(a: float, b: float, t: float) -> float {
    return a + (b - a) * t;
}

def clampf(v: float, lo: float, hi: float) -> float {
    if v < lo {
        return lo;
    }
    if v > hi {
        return hi;
    }
    return v;
}

obj Rng {
    has state: int = 987654321;
}

def rand01(r: &mut Rng) -> float {
    r.state = (r.state * 1103515245 + 12345) % 2147483648;
    return float(r.state) / 2147483648.0;
}

def rand_range(r: &mut Rng, lo: float, hi: float) -> float {
    return lo + rand01(r) * (hi - lo);
}

def rand_sign(r: &mut Rng) -> float {
    return 1.0 if rand01(r) < 0.5 else -1.0;
}
