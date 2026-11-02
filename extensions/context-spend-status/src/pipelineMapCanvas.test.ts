import test from "node:test";
import assert from "node:assert/strict";
import {
  pipelineMapCanvasFileName,
  renderPipelineMapCanvasSource,
} from "./pipelineMapCanvas";
import type { PipelineTree } from "./treeModel";

const sample: PipelineTree = {
  hasPipeline: true,
  route: "full",
  layer: "L3",
  stage: "engineer-review",
  layers: [
    {
      id: "L1",
      label: "L1 Planning",
      state: "done",
      nodes: [
        { id: "brainstorm", label: "Brainstorm", state: "done" },
        { id: "tech-spec", label: "Tech spec", state: "done" },
      ],
    },
    {
      id: "L3",
      label: "L3 Implementation",
      state: "here",
      nodes: [
        { id: "engineer-review", label: "Engineer review", state: "here" },
        { id: "local-diff", label: "Local Diff", state: "waiting" },
      ],
    },
  ],
};

test("canvas file name is stable for Agent Window open", () => {
  assert.equal(
    pipelineMapCanvasFileName(),
    "loregate-pipeline-status.canvas.tsx"
  );
});

test("renders cursor/canvas import and embedded STATE", () => {
  const src = renderPipelineMapCanvasSource(sample);
  assert.match(src, /from "cursor\/canvas"/);
  assert.match(src, /export default function LoregatePipelineMap/);
  assert.match(src, /"route": "full"/);
  assert.match(src, /"stage": "engineer-review"/);
  assert.match(src, /Engineer review/);
  assert.match(src, /\/lgt-engineer-review/);
  assert.match(src, /navigator\.clipboard\.writeText/);
  assert.match(src, /CopyKeyButton/);
  assert.match(src, /<Table/);
  assert.match(src, /rowTone=/);
  assert.doesNotMatch(src, /<Stat/);
  assert.doesNotMatch(src, /\bfetch\s*\(/);
});

test("idle tree still produces a valid canvas", () => {
  const idle: PipelineTree = {
    hasPipeline: false,
    route: "none",
    layer: "",
    stage: "",
    layers: [],
  };
  const src = renderPipelineMapCanvasSource(idle);
  assert.match(src, /No active Loregate gates/);
});
