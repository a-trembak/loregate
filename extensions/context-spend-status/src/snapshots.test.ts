import test from "node:test";
import assert from "node:assert/strict";
import {
  latestSessionSnapshots,
  loadSnapshots,
  metricsForSession,
  type Snapshot,
} from "./snapshots";

test("loads valid snapshots and ignores malformed lines", () => {
  const snapshots = loadSnapshots(
    [
      '{"ts":"2026-10-21T10:00:00Z","session_id":"s1","ctx_pct":10,"stage":"plan","route":"full"}',
      "not json",
      '{"ts":"2026-10-21T10:01:00Z","session_id":"s1","ctx_pct":"bad","stage":"plan","route":"full"}',
      "",
    ].join("\n")
  );

  assert.deepEqual(snapshots, [
    {
      ts: "2026-10-21T10:00:00Z",
      session_id: "s1",
      ctx_pct: 10,
      stage: "plan",
      route: "full",
    },
  ]);
});

test("computes peak across contiguous stage runs and current alert", () => {
  const snapshots: Snapshot[] = [
    snapshot("other", 1, "build"),
    snapshot("s1", 10, "plan"),
    snapshot("s1", 14, "plan"),
    snapshot("s1", 20, "build"),
    snapshot("s1", 42, "build"),
    snapshot("s1", 45, "review-gate"),
    snapshot("s1", 48, "review-gate"),
    snapshot("s1", 50, "build"),
    snapshot("s1", 51, "build"),
  ];

  assert.deepEqual(metricsForSession(snapshots, "s1", "build", 66), {
    deltaStagePp: 16,
    peakStage: "build",
    peakPp: 22,
    alert: true,
  });
});

test("does not compute current delta when session ends in another stage", () => {
  const snapshots: Snapshot[] = [
    snapshot("s1", 10, "build"),
    snapshot("s1", 20, "build"),
    snapshot("s1", 45, "review-gate"),
    snapshot("s1", 48, "review-gate"),
  ];

  assert.deepEqual(metricsForSession(snapshots, "s1", "build", 66), {
    deltaStagePp: null,
    peakStage: "build",
    peakPp: 10,
    alert: false,
  });
});

test("keeps only the latest recent session", () => {
  const now = Date.parse("2026-10-21T12:00:00Z");
  const snapshots: Snapshot[] = [
    snapshotAt("old", 5, "plan", "2026-10-19T12:00:00Z"),
    snapshotAt("s1", 10, "plan", "2026-10-21T10:00:00Z"),
    snapshotAt("s2", 20, "build", "2026-10-21T11:00:00Z"),
    snapshotAt("s1", 30, "plan", "2026-10-21T11:30:00Z"),
  ];

  assert.deepEqual(latestSessionSnapshots(snapshots, now), [
    snapshots[1],
    snapshots[3],
  ]);
});

test("ignores snapshots when none are newer than twenty-four hours", () => {
  const now = Date.parse("2026-10-21T12:00:00Z");

  assert.deepEqual(
    latestSessionSnapshots(
      [snapshotAt("old", 5, "plan", "2026-10-20T11:59:59Z")],
      now
    ),
    []
  );
});

test("uses the latest contiguous run for the current stage", () => {
  const snapshots: Snapshot[] = [
    snapshot("s1", 10, "build"),
    snapshot("s1", 20, "review-gate"),
    snapshot("s1", 30, "build"),
  ];

  assert.deepEqual(metricsForSession(snapshots, "s1", "build", 35), {
    deltaStagePp: 5,
    peakStage: null,
    peakPp: null,
    alert: false,
  });
});

test("returns null deltas and no alert when current context is unavailable", () => {
  assert.deepEqual(
    metricsForSession(
      [snapshot("s1", 10, "plan"), snapshot("s1", 20, "plan")],
      "s1",
      "plan",
      null
    ),
    {
      deltaStagePp: null,
      peakStage: "plan",
      peakPp: 10,
      alert: false,
    }
  );
});

test("alerts at the fifteen percentage-point threshold", () => {
  assert.deepEqual(
    metricsForSession(
      [snapshot("s1", 10, "review-gate")],
      "s1",
      "review-gate",
      25
    ),
    {
      deltaStagePp: 15,
      peakStage: null,
      peakPp: null,
      alert: true,
    }
  );
});

test("returns empty metrics when the session has no snapshots", () => {
  assert.deepEqual(metricsForSession([], "missing", "plan", 20), {
    deltaStagePp: null,
    peakStage: null,
    peakPp: null,
    alert: false,
  });
});

function snapshot(session_id: string, ctx_pct: number, stage: string): Snapshot {
  return snapshotAt(
    session_id,
    ctx_pct,
    stage,
    "2026-10-21T10:00:00Z"
  );
}

function snapshotAt(
  session_id: string,
  ctx_pct: number,
  stage: string,
  ts: string
): Snapshot {
  return {
    ts,
    session_id,
    ctx_pct,
    stage,
    route: "full",
  };
}
