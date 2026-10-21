export type Snapshot = {
  ts: string;
  session_id: string;
  ctx_pct: number;
  stage: string;
  route: string;
  invocation_id?: string;
};

export type SpendMetrics = {
  deltaStagePp: number | null;
  peakStage: string | null;
  peakPp: number | null;
  alert: boolean;
};

type StageRun = {
  stage: string;
  firstCtx: number;
  lastCtx: number;
};

export function loadSnapshots(jsonl: string): Snapshot[] {
  const snapshots: Snapshot[] = [];

  for (const line of jsonl.split(/\r?\n/)) {
    if (line.trim() === "") {
      continue;
    }

    try {
      const value: unknown = JSON.parse(line);
      if (isSnapshot(value)) {
        snapshots.push(value);
      }
    } catch {
      // Ignore a partial or malformed JSONL line.
    }
  }

  return snapshots;
}

export function metricsForSession(
  snapshots: Snapshot[],
  sessionId: string,
  currentStage: string,
  currentCtx: number | null
): SpendMetrics {
  const sessionSnapshots = snapshots.filter(
    (snapshot) => snapshot.session_id === sessionId
  );

  if (sessionSnapshots.length === 0) {
    return emptyMetrics();
  }

  const runs = stageRuns(sessionSnapshots);
  let peakStage: string | null = null;
  let peakPp: number | null = null;

  for (const run of runs) {
    const delta = run.lastCtx - run.firstCtx;
    if (delta > 0 && (peakPp === null || delta > peakPp)) {
      peakStage = run.stage;
      peakPp = delta;
    }
  }

  if (currentCtx === null) {
    return {
      deltaStagePp: null,
      peakStage,
      peakPp,
      alert: false,
    };
  }

  const currentRun = runs.at(-1);
  const deltaStagePp =
    currentRun?.stage === currentStage
      ? currentCtx - currentRun.firstCtx
      : null;

  return {
    deltaStagePp,
    peakStage,
    peakPp,
    alert: deltaStagePp !== null && deltaStagePp >= 15,
  };
}

function isSnapshot(value: unknown): value is Snapshot {
  if (typeof value !== "object" || value === null) {
    return false;
  }

  const record = value as Record<string, unknown>;
  return (
    typeof record.ts === "string" &&
    typeof record.session_id === "string" &&
    typeof record.ctx_pct === "number" &&
    Number.isFinite(record.ctx_pct) &&
    typeof record.stage === "string" &&
    typeof record.route === "string" &&
    (record.invocation_id === undefined ||
      typeof record.invocation_id === "string")
  );
}

function stageRuns(snapshots: Snapshot[]): StageRun[] {
  const runs: StageRun[] = [];

  for (const snapshot of snapshots) {
    const current = runs.at(-1);
    if (current?.stage === snapshot.stage) {
      current.lastCtx = snapshot.ctx_pct;
    } else {
      runs.push({
        stage: snapshot.stage,
        firstCtx: snapshot.ctx_pct,
        lastCtx: snapshot.ctx_pct,
      });
    }
  }

  return runs;
}

function emptyMetrics(): SpendMetrics {
  return {
    deltaStagePp: null,
    peakStage: null,
    peakPp: null,
    alert: false,
  };
}
