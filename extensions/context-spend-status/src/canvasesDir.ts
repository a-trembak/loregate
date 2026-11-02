import path from "node:path";

/**
 * Cursor stores Agent Window canvases under:
 *   ~/.cursor/projects/<sanitized-absolute-path>/canvases/
 * Example: /Users/ukad/loregate → Users-ukad-loregate
 */
export function cursorProjectIdFromRoot(workspaceRoot: string): string {
  const resolved = path.resolve(workspaceRoot);
  const withoutDrive = resolved.replace(/^[A-Za-z]:/, "");
  return withoutDrive
    .replace(/^\/+/, "")
    .split(/[/\\]+/)
    .filter(Boolean)
    .join("-");
}

export function resolveCanvasesDir(
  workspaceRoot: string,
  homedir: string
): string {
  const projectId = cursorProjectIdFromRoot(workspaceRoot);
  return path.join(homedir, ".cursor", "projects", projectId, "canvases");
}

export function pipelineMapCanvasPath(
  workspaceRoot: string,
  homedir: string
): string {
  return path.join(
    resolveCanvasesDir(workspaceRoot, homedir),
    "loregate-pipeline-status.canvas.tsx"
  );
}
