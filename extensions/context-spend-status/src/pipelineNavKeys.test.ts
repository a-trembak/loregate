import test from "node:test";
import assert from "node:assert/strict";
import { chatKeyForStage, STAGE_CHAT_KEYS } from "./pipelineNavKeys";
import { CANONICAL_LAYERS } from "./treeModel";

test("every canonical stage has a pasteable chat key", () => {
  for (const layer of CANONICAL_LAYERS) {
    for (const node of layer.nodes) {
      assert.ok(
        STAGE_CHAT_KEYS[node.id],
        `missing chat key for ${node.id}`
      );
      assert.match(chatKeyForStage(node.id), /\S/);
    }
  }
});

test("slash-command stages use /lgt- prefix", () => {
  assert.equal(chatKeyForStage("engineer-review"), "/lgt-engineer-review");
  assert.equal(chatKeyForStage("review-gate"), "/lgt-finish-plan");
  assert.equal(chatKeyForStage("approve-plan"), "/lgt-approve-plan");
});
