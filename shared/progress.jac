import from .timefmt { now_iso }

glob LOG_DEPTH: int = 6;

obj JobStep {
    has label: str = "",
        state: str = "wait",
        detail: str = "";
}

obj JobProgress {
    has active: bool = False,
        phase: str = "idle",
        detail: str = "",
        steps: list[JobStep] = [],
        log: list[str] = [],
        updated_at: str = "";

    def begin(phase: str) {
        self.active = True;
        self.phase = phase;
        self.detail = "";
        self.steps = [];
        self.log = [];
        self.updated_at = now_iso();
    }

    def note(detail: str) {
        self.detail = detail;
        self.log.append(detail);
        if len(self.log) > LOG_DEPTH {
            self.log = self.log[-LOG_DEPTH:];
        }
        self.updated_at = now_iso();
    }

    def mark(label: str, state: str, detail: str) {
        for s in self.steps {
            if s.label == label {
                s.state = state;
                s.detail = detail;
                self.updated_at = now_iso();
                return;
            }
        }
        self.steps.append(JobStep(label=label, state=state, detail=detail));
        self.updated_at = now_iso();
    }

    def finish {
        self.phase = "done";
        self.active = False;
        self.updated_at = now_iso();
    }

    def fail(detail: str) {
        self.phase = "error";
        self.active = False;
        self.note(detail);
    }
}
