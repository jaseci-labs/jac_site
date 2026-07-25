import datetime;

def now_dt -> datetime.datetime {
    return datetime.datetime.now(datetime.UTC).replace(tzinfo=None);
}

def now_iso -> str {
    return now_dt().isoformat() + "Z";
}

def seconds_since(stamp: str) -> float {
    if stamp == "" {
        return -1.0;
    }
    try {
        then = datetime.datetime.fromisoformat(stamp.rstrip("Z"));
        return (now_dt() - then).total_seconds();
    } except ValueError {
        return -1.0;
    }
}

def days_since(stamp: str) -> float {
    secs = seconds_since(stamp);
    return 9999.0 if secs < 0.0 else secs / 86400.0;
}
