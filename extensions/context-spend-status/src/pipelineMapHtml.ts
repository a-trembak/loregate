import type { PipelineTree } from "./treeModel";

export function renderPipelineMapHtml(tree: PipelineTree): string {
  const body = tree.error
    ? `<p class="error">${escapeHtml(tree.error)}</p>`
    : !tree.hasPipeline
      ? `<p class="muted">No active Loregate pipeline in this workspace (no gates / ledger yet).</p>${renderLayers(tree)}`
      : renderLayers(tree);

  return `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    :root {
      color-scheme: light dark;
      --fg: var(--vscode-foreground, #ccc);
      --muted: var(--vscode-descriptionForeground, #888);
      --bg: var(--vscode-sideBar-background, transparent);
      --done: #3fa66b;
      --here: #d4a017;
      --waiting: #6b7280;
      --blocked: #d94c4c;
    }
    body {
      margin: 0;
      padding: 12px;
      font: 13px/1.4 var(--vscode-font-family, system-ui, sans-serif);
      color: var(--fg);
      background: var(--bg);
    }
    h1 { font-size: 14px; margin: 0 0 8px; font-weight: 600; }
    .meta { color: var(--muted); margin-bottom: 12px; font-size: 12px; }
    .layer { margin: 0 0 12px; padding-left: 0; list-style: none; }
    .layer-title {
      display: flex; align-items: center; gap: 8px;
      font-weight: 600; margin-bottom: 4px;
    }
    .nodes { list-style: none; margin: 0; padding: 0 0 0 14px; }
    .node {
      display: flex; align-items: center; gap: 8px;
      padding: 3px 0;
    }
    .dot {
      width: 10px; height: 10px; border-radius: 50%;
      flex: 0 0 auto;
      background: var(--waiting);
    }
    .dot.done { background: var(--done); }
    .dot.here { background: var(--here); box-shadow: 0 0 0 2px color-mix(in srgb, var(--here) 35%, transparent); }
    .dot.blocked { background: var(--blocked); }
    .dot.waiting { background: var(--waiting); opacity: 0.7; }
    .label.here { font-weight: 600; }
    .error { color: var(--blocked); }
    .muted { color: var(--muted); }
    .legend { margin-top: 16px; color: var(--muted); font-size: 11px; }
    .legend span { margin-right: 10px; }
  </style>
</head>
<body>
  <h1>Loregate pipeline</h1>
  <div class="meta">Route: ${escapeHtml(tree.route)} · Layer: ${escapeHtml(tree.layer)} · Stage: ${escapeHtml(tree.stage)}</div>
  ${body}
  <div class="legend">
    <span>● done</span>
    <span>● here</span>
    <span>● waiting</span>
    <span>● blocked (human gate)</span>
  </div>
  <script>
    const vscode = acquireVsCodeApi();
    window.addEventListener('message', (event) => {
      if (event.data && event.data.type === 'reload') {
        // Host replaces full HTML on refresh; no-op hook for future partial updates.
      }
    });
  </script>
</body>
</html>`;
}

function renderLayers(tree: PipelineTree): string {
  if (tree.layers.length === 0) {
    return "";
  }
  return `<ul class="layer-list" style="list-style:none;padding:0;margin:0">
${tree.layers
  .map(
    (layer) => `<li class="layer">
  <div class="layer-title"><span class="dot ${layer.state}"></span>${escapeHtml(layer.label)}</div>
  <ul class="nodes">
${layer.nodes
  .map(
    (node) => `    <li class="node"><span class="dot ${node.state}"></span><span class="label ${node.state}">${escapeHtml(node.label)}</span></li>`
  )
  .join("\n")}
  </ul>
</li>`
  )
  .join("\n")}
</ul>`;
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}
