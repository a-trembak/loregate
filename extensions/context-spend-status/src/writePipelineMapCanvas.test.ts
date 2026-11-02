import test from "node:test";
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import {
  CANVAS_HEARTBEAT_MS,
  resetPipelineMapCanvasWriteCache,
  writePipelineMapCanvasTo,
} from "./writePipelineMapCanvas";
import type { PipelineTree } from "./treeModel";

const sample: PipelineTree = {
  hasPipeline: true,
  route: "full",
  layer: "review",
  stage: "engineer-review",
  layers: [
    {
      id: "review",
      label: "Review",
      state: "here",
      nodes: [
        { id: "engineer-review", label: "Engineer review", state: "here" },
      ],
    },
  ],
};

function makeDestUnderWorkspace(): string {
  const base = path.join(__dirname, "..", ".tmp-canvas-tests");
  fs.mkdirSync(base, { recursive: true });
  const dir = fs.mkdtempSync(path.join(base, "dest-"));
  return path.join(dir, "loregate-pipeline-status.canvas.tsx");
}

test("writes canvas source to a destination path", () => {
  resetPipelineMapCanvasWriteCache();
  const dest = makeDestUnderWorkspace();
  const written = writePipelineMapCanvasTo(dest, sample, { force: true });
  assert.equal(written, dest);
  assert.ok(fs.existsSync(dest));
  const body = fs.readFileSync(dest, "utf8");
  assert.match(body, /from "cursor\/canvas"/);
  assert.match(body, /Engineer review/);
  fs.rmSync(path.dirname(dest), { recursive: true, force: true });
});

test("skips rewrite when fingerprint is unchanged before heartbeat", () => {
  resetPipelineMapCanvasWriteCache();
  const dest = makeDestUnderWorkspace();
  const t0 = 1_000_000;
  const first = writePipelineMapCanvasTo(dest, sample, {
    force: true,
    nowMs: t0,
  });
  assert.equal(first, dest);
  const mtime1 = fs.statSync(dest).mtimeMs;
  const second = writePipelineMapCanvasTo(dest, sample, { nowMs: t0 + 1000 });
  assert.equal(second, null);
  assert.equal(fs.statSync(dest).mtimeMs, mtime1);
  fs.rmSync(path.dirname(dest), { recursive: true, force: true });
});

test("rewrites on heartbeat even when fingerprint is unchanged", () => {
  resetPipelineMapCanvasWriteCache();
  const dest = makeDestUnderWorkspace();
  const t0 = 2_000_000;
  writePipelineMapCanvasTo(dest, sample, { force: true, nowMs: t0 });
  const again = writePipelineMapCanvasTo(dest, sample, {
    nowMs: t0 + CANVAS_HEARTBEAT_MS,
  });
  assert.equal(again, dest);
  fs.rmSync(path.dirname(dest), { recursive: true, force: true });
});
