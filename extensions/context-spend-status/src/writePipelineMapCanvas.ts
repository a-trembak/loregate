import fs from "node:fs";
import path from "node:path";
import { pipelineMapCanvasPath } from "./canvasesDir";
import {
  pipelineMapCanvasFingerprint,
  renderPipelineMapCanvasSource,
} from "./pipelineMapCanvas";
import type { PipelineTree } from "./treeModel";

/** Rewrite at least this often so the canvas "Updated" line proves the poll is alive. */
export const CANVAS_HEARTBEAT_MS = 30_000;

const lastFingerprintByPath = new Map<string, string>();
const lastWriteAtByPath = new Map<string, number>();

/**
 * Write canvas source to an absolute path (create parent dirs).
 * Returns the path written, or null when skipped / failed.
 */
export function writePipelineMapCanvasTo(
  dest: string,
  tree: PipelineTree,
  opts?: { force?: boolean; nowMs?: number }
): string | null {
  const fingerprint = pipelineMapCanvasFingerprint(tree);
  const now = opts?.nowMs ?? Date.now();
  const lastFp = lastFingerprintByPath.get(dest);
  const lastAt = lastWriteAtByPath.get(dest) ?? 0;
  const heartbeatDue = now - lastAt >= CANVAS_HEARTBEAT_MS;

  if (
    !opts?.force &&
    lastFp === fingerprint &&
    !heartbeatDue
  ) {
    return null;
  }

  try {
    const next = renderPipelineMapCanvasSource(tree);
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.writeFileSync(dest, next, "utf8");
    lastFingerprintByPath.set(dest, fingerprint);
    lastWriteAtByPath.set(dest, now);
    return dest;
  } catch {
    return null;
  }
}

/**
 * Write (or skip) Agent Window canvas under ~/.cursor/projects/.../canvases/.
 * Returns the absolute path written, or null when skipped / failed.
 */
export function writePipelineMapCanvas(
  workspaceRoot: string,
  homedir: string,
  tree: PipelineTree,
  opts?: { force?: boolean; nowMs?: number }
): string | null {
  return writePipelineMapCanvasTo(
    pipelineMapCanvasPath(workspaceRoot, homedir),
    tree,
    opts
  );
}

/**
 * Replace the legacy Stat-era filename with a read-only stub so a stale
 * extension host cannot keep overwriting it with the old UI.
 */
export function sealLegacyPipelineMapCanvas(
  workspaceRoot: string,
  homedir: string
): void {
  const dest = path.join(
    path.dirname(pipelineMapCanvasPath(workspaceRoot, homedir)),
    "loregate-pipeline-map.canvas.tsx"
  );
  const stub = `/* sealed: open loregate-pipeline-status.canvas.tsx instead */
import { Callout, H1, Stack, Text } from "cursor/canvas";

export default function LegacyPipelineMapStub() {
  return (
    <Stack gap={12}>
      <H1>Loregate pipeline (moved)</H1>
      <Callout tone="warning" title="Wrong canvas file">
        This file is legacy. Open{" "}
        <Text weight="semibold">loregate-pipeline-status</Text> in the Canvas
        list (tables + Copy buttons). Then run Developer: Reload Window so the
        Loregate extension stops rewriting this stub.
      </Callout>
    </Stack>
  );
}
`;
  try {
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    try {
      fs.chmodSync(dest, 0o644);
    } catch {
      // create path below
    }
    fs.writeFileSync(dest, stub, "utf8");
    fs.chmodSync(dest, 0o444);
  } catch {
    // best-effort
  }
}

/** Clear in-memory skip cache (tests). */
export function resetPipelineMapCanvasWriteCache(): void {
  lastFingerprintByPath.clear();
  lastWriteAtByPath.clear();
}
