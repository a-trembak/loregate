import test from "node:test";
import assert from "node:assert/strict";
import { buildPipelineTree } from "./treeModel";

test("marks prior stages done and current as here", () => {
  const tree = buildPipelineTree({
    route: "full",
    layer: "review",
    stage: "local-diff-review-gate",
    stagesEntered: ["csp-tech-spec", "writing-plans", "csp-software-developer", "engineer-review"],
    pendingGates: [],
    hasPipeline: true,
  });

  const review = tree.layers.find((l) => l.id === "review");
  assert.ok(review);
  const localDiff = review.nodes.find((n) => n.id === "local-diff-review-gate");
  const engineer = review.nodes.find((n) => n.id === "engineer-review");
  assert.equal(localDiff?.state, "here");
  assert.equal(engineer?.state, "done");
  const ship = tree.layers.find((l) => l.id === "ship");
  assert.equal(ship?.nodes[0]?.state, "waiting");
});

test("pending review-gate marks review-gate blocked when current", () => {
  const tree = buildPipelineTree({
    route: "full",
    layer: "review",
    stage: "review-gate",
    stagesEntered: ["csp-software-developer"],
    pendingGates: [{ kind: "review-gate" }],
    hasPipeline: true,
  });

  const reviewGate = tree.layers
    .find((l) => l.id === "review")
    ?.nodes.find((n) => n.id === "review-gate");
  assert.equal(reviewGate?.state, "blocked");
});

test("error payload returns empty layers", () => {
  const tree = buildPipelineTree({
    route: "unknown",
    layer: "idle",
    stage: "idle",
    stagesEntered: [],
    pendingGates: [],
    hasPipeline: false,
    error: "helper missing",
  });
  assert.equal(tree.layers.length, 0);
  assert.equal(tree.error, "helper missing");
});
