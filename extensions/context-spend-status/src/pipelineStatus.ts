import { execFile } from "node:child_process";
import path from "node:path";

export type PipelineOrientation = {
  route: string;
  stage: string;
  hasPipeline: boolean;
};

type ReadFile = (filePath: string) => string | null;

export function resolvePipelineStatusHelper(
  root: string,
  homedir: string,
  readFile: ReadFile
): string | null {
  const workspaceHelper = path.join(root, "scripts", "pipeline-status.sh");
  if (readFile(workspaceHelper) !== null) {
    return workspaceHelper;
  }

  const markerPaths = [
    path.join(root, ".cursor", "cursor-spells-kit-path"),
    path.join(homedir, ".cursor", "cursor-spells-kit-path"),
  ];

  for (const markerPath of markerPaths) {
    const kitRoot = readFile(markerPath)?.trim();
    if (!kitRoot) {
      continue;
    }

    const helperPath = path.join(kitRoot, "scripts", "pipeline-status.sh");
    if (readFile(helperPath) !== null) {
      return helperPath;
    }
  }

  return null;
}

export async function fetchPipelineOrientation(
  root: string,
  opts: { timeoutMs?: number; homedir: string; readFile: ReadFile }
): Promise<PipelineOrientation | { error: string }> {
  const helper = resolvePipelineStatusHelper(root, opts.homedir, opts.readFile);
  if (helper === null) {
    return { error: "pipeline-status helper not found" };
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), opts.timeoutMs ?? 1500);

  try {
    const stdout = await runHelper(helper, root, controller.signal);
    return parseOrientation(stdout);
  } catch (error) {
    return { error: errorMessage(error) };
  } finally {
    clearTimeout(timeout);
  }
}

function runHelper(
  helper: string,
  root: string,
  signal: AbortSignal
): Promise<string> {
  return new Promise((resolve, reject) => {
    execFile(
      "bash",
      [helper, "--json", "--root", root],
      { encoding: "utf8", signal },
      (error, stdout) => {
        if (error) {
          reject(error);
        } else {
          resolve(stdout);
        }
      }
    );
  });
}

function parseOrientation(json: string): PipelineOrientation {
  const parsed: unknown = JSON.parse(json);
  if (typeof parsed !== "object" || parsed === null) {
    throw new Error("pipeline-status returned invalid JSON");
  }

  const record = parsed as Record<string, unknown>;
  const route = typeof record.route === "string" ? record.route : "unknown";
  const stage = typeof record.stage === "string" ? record.stage : "idle";
  const pendingGates = Array.isArray(record.pending_gates)
    ? record.pending_gates
    : [];
  const stagesEntered = Array.isArray(record.stages_entered)
    ? record.stages_entered
    : [];

  return {
    route,
    stage,
    hasPipeline:
      pendingGates.length > 0 ||
      stagesEntered.length > 0 ||
      (route !== "unknown" && stage !== "idle"),
  };
}

function errorMessage(error: unknown): string {
  return error instanceof Error ? error.message : String(error);
}
