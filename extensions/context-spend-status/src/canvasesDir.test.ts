import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import {
  cursorProjectIdFromRoot,
  pipelineMapCanvasPath,
  resolveCanvasesDir,
} from "./canvasesDir";

test("sanitizes absolute unix paths to Cursor project ids", () => {
  assert.equal(
    cursorProjectIdFromRoot("/Users/ukad/Projects/EnergySave/escloud-web-frontend"),
    "Users-ukad-Projects-EnergySave-escloud-web-frontend"
  );
  assert.equal(cursorProjectIdFromRoot("/Users/ukad/loregate"), "Users-ukad-loregate");
});

test("builds canvases path under ~/.cursor/projects", () => {
  const home = "/Users/ukad";
  const root = "/Users/ukad/loregate";
  assert.equal(
    resolveCanvasesDir(root, home),
    path.join(home, ".cursor", "projects", "Users-ukad-loregate", "canvases")
  );
  assert.equal(
    pipelineMapCanvasPath(root, home),
    path.join(
      home,
      ".cursor",
      "projects",
      "Users-ukad-loregate",
      "canvases",
      "loregate-pipeline-status.canvas.tsx"
    )
  );
});
