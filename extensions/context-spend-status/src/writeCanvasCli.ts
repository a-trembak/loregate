/**
 * CLI: node out/writeCanvasCli.js --root <workspace>
 * Writes loregate-pipeline-status.canvas.tsx for Agent Window (no tokens).
 */
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { fetchPipelineOrientation } from "./pipelineStatus";
import { buildPipelineTree } from "./treeModel";
import {
  sealLegacyPipelineMapCanvas,
  writePipelineMapCanvas,
} from "./writePipelineMapCanvas";

function argValue(flag: string): string | null {
  const idx = process.argv.indexOf(flag);
  if (idx < 0 || idx + 1 >= process.argv.length) {
    return null;
  }
  return process.argv[idx + 1] ?? null;
}

function readFile(filePath: string): string | null {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return null;
  }
}

async function main(): Promise<void> {
  const root = path.resolve(argValue("--root") ?? process.cwd());
  const orientation = await fetchPipelineOrientation(root, {
    homedir: os.homedir(),
    readFile,
  });

  const tree =
    "error" in orientation
      ? buildPipelineTree({
          route: "unknown",
          layer: "idle",
          stage: "idle",
          stagesEntered: [],
          pendingGates: [],
          hasPipeline: false,
          error: orientation.error,
        })
      : buildPipelineTree({
          route: orientation.route,
          layer: orientation.layer,
          stage: orientation.stage,
          stagesEntered: orientation.stagesEntered,
          pendingGates: orientation.pendingGates,
          hasPipeline: orientation.hasPipeline,
        });

  sealLegacyPipelineMapCanvas(root, os.homedir());
  const dest = writePipelineMapCanvas(root, os.homedir(), tree, { force: true });
  if (dest === null) {
    console.error("failed to write pipeline map canvas");
    process.exit(1);
  }
  console.log(dest);
}

void main();
