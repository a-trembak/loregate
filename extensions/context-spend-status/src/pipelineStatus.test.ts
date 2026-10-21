import test from "node:test";
import assert from "node:assert/strict";
import path from "node:path";
import { resolvePipelineStatusHelper } from "./pipelineStatus";

test("prefers the workspace helper", () => {
  const root = "/workspace/project";
  const home = "/home/tester";
  const files = new Map<string, string>([
    [path.join(root, "scripts", "pipeline-status.sh"), "#!/bin/bash"],
    [
      path.join(root, ".cursor", "cursor-spells-kit-path"),
      "/opt/loregate\n",
    ],
    [path.join("/opt/loregate", "scripts", "pipeline-status.sh"), "#!/bin/bash"],
  ]);

  assert.equal(
    resolvePipelineStatusHelper(root, home, (filePath) => files.get(filePath) ?? null),
    path.join(root, "scripts", "pipeline-status.sh")
  );
});

test("uses the workspace kit marker before the home marker", () => {
  const root = "/workspace/project";
  const home = "/home/tester";
  const files = new Map<string, string>([
    [
      path.join(root, ".cursor", "cursor-spells-kit-path"),
      " /workspace-kit \n",
    ],
    [
      path.join(home, ".cursor", "cursor-spells-kit-path"),
      "/home-kit\n",
    ],
    [
      path.join("/workspace-kit", "scripts", "pipeline-status.sh"),
      "#!/bin/bash",
    ],
    [path.join("/home-kit", "scripts", "pipeline-status.sh"), "#!/bin/bash"],
  ]);

  assert.equal(
    resolvePipelineStatusHelper(root, home, (filePath) => files.get(filePath) ?? null),
    path.join("/workspace-kit", "scripts", "pipeline-status.sh")
  );
});

test("uses the home kit marker when the project has no helper", () => {
  const root = "/workspace/project";
  const home = "/home/tester";
  const files = new Map<string, string>([
    [
      path.join(home, ".cursor", "cursor-spells-kit-path"),
      "/home-kit\n",
    ],
    [path.join("/home-kit", "scripts", "pipeline-status.sh"), "#!/bin/bash"],
  ]);

  assert.equal(
    resolvePipelineStatusHelper(root, home, (filePath) => files.get(filePath) ?? null),
    path.join("/home-kit", "scripts", "pipeline-status.sh")
  );
});

test("returns null when no helper can be resolved", () => {
  assert.equal(
    resolvePipelineStatusHelper("/workspace/project", "/home/tester", () => null),
    null
  );
});
