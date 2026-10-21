import test from "node:test";
import assert from "node:assert/strict";
import { formatOutput, formatStatusText } from "./format";

test("no gates", () => {
  assert.equal(
    formatStatusText({
      hasPipeline: false,
      route: "unknown",
      stage: "idle",
      alertPp: null,
    }),
    "pipe — (no gates)"
  );
});

test("with alert", () => {
  assert.equal(
    formatStatusText({
      hasPipeline: true,
      route: "full",
      stage: "review-gate",
      alertPp: 17,
    }),
    "pipe full·review-gate ⚠+17"
  );
});

test("without alert", () => {
  assert.equal(
    formatStatusText({
      hasPipeline: true,
      route: "fast",
      stage: "build",
      alertPp: null,
    }),
    "pipe fast·build"
  );
});

test("formats detailed output", () => {
  assert.equal(
    formatOutput({
      route: "full",
      stage: "review-gate",
      deltaStagePp: 17,
      peakStage: "build",
      peakPp: 21,
      hint: "cut-clarify",
      snapshotsPath: "/tmp/snapshots.jsonl",
    }),
    [
      "Loregate context spend (proxies — not billing)",
      "route: full",
      "stage: review-gate",
      "+17pp/stage",
      "peak: build(+21)",
      "hint: cut-clarify",
      "snapshots: /tmp/snapshots.jsonl",
      "ring %: n/a in IDE (use Agent CLI statusLine)",
    ].join("\n")
  );
});

test("formats unavailable metrics and hint", () => {
  assert.equal(
    formatOutput({
      route: "unknown",
      stage: "idle",
      deltaStagePp: null,
      peakStage: null,
      peakPp: null,
      hint: null,
      snapshotsPath: "/tmp/snapshots.jsonl",
    }),
    [
      "Loregate context spend (proxies — not billing)",
      "route: unknown",
      "stage: idle",
      "—",
      "peak: —",
      "hint: —",
      "snapshots: /tmp/snapshots.jsonl",
      "ring %: n/a in IDE (use Agent CLI statusLine)",
    ].join("\n")
  );
});
