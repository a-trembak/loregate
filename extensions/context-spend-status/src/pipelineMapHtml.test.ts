import test from "node:test";
import assert from "node:assert/strict";
import { renderPipelineMapHtml } from "./pipelineMapHtml";
import { buildPipelineTree } from "./treeModel";

test("escapes HTML in stage labels", () => {
  const tree = buildPipelineTree({
    route: "full",
    layer: "review",
    stage: "engineer-review",
    stagesEntered: [],
    pendingGates: [],
    hasPipeline: true,
  });
  tree.stage = "<script>alert(1)</script>";
  const html = renderPipelineMapHtml(tree);
  assert.equal(html.includes("<script>alert(1)</script>"), false);
  assert.equal(html.includes("&lt;script&gt;"), true);
});
