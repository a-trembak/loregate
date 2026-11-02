import * as vscode from "vscode";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { formatOutput, formatStatusText } from "./format";
import { hintForStage } from "./hints";
import {
  focusPipelineMapView,
  getPipelineMapViewType,
  PipelineMapViewProvider,
  revealOrCreatePipelineMapPanel,
  updatePipelineMapSurfaces,
} from "./pipelineMapPanel";
import { fetchPipelineOrientation } from "./pipelineStatus";
import { pickWorkspaceFolder } from "./resolveFolder";
import {
  latestSessionSnapshots,
  loadSnapshots,
  metricsForSession,
} from "./snapshots";
import { buildPipelineTree, type PipelineTree } from "./treeModel";
import {
  sealLegacyPipelineMapCanvas,
  writePipelineMapCanvas,
} from "./writePipelineMapCanvas";

const SHOW_SPEND_COMMAND = "loregate.contextSpend.show";
const SHOW_MAP_COMMAND = "loregate.pipelineMap.show";
const REFRESH_INTERVAL_MS = 3000;

let refreshTimer: NodeJS.Timeout | undefined;
let statusItem: vscode.StatusBarItem | undefined;
let outputChannel: vscode.OutputChannel | undefined;
let registeredDisposables: vscode.Disposable[] = [];
let lastTree: PipelineTree = emptyTree();
let lastCanvasPath: string | undefined;

function syncPipelineMapCanvas(root: string, tree: PipelineTree): void {
  sealLegacyPipelineMapCanvas(root, os.homedir());
  const written = writePipelineMapCanvas(root, os.homedir(), tree);
  if (written !== null) {
    lastCanvasPath = written;
  }
}

export function activate(context: vscode.ExtensionContext): void {
  statusItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  outputChannel = vscode.window.createOutputChannel("Loregate Context Spend");

  let lastOutput = unavailableOutput("");
  let refreshInFlight = false;

  const mapProvider = new PipelineMapViewProvider(
    context.extensionUri,
    lastTree
  );

  const showOutput = vscode.commands.registerCommand(SHOW_SPEND_COMMAND, () => {
    outputChannel?.replace(lastOutput);
    outputChannel?.show(true);
  });

  const showMap = vscode.commands.registerCommand(
    SHOW_MAP_COMMAND,
    async () => {
      await refresh();
      revealOrCreatePipelineMapPanel(lastTree, context.extensionUri);
      await focusPipelineMapView();
      if (lastCanvasPath !== undefined) {
        try {
          const doc = await vscode.workspace.openTextDocument(
            vscode.Uri.file(lastCanvasPath)
          );
          await vscode.window.showTextDocument(doc, { preview: true });
        } catch {
          // Canvas open is best-effort; Webview panel remains available.
        }
      }
    }
  );

  const refresh = async (): Promise<void> => {
    if (refreshInFlight || statusItem === undefined) {
      return;
    }

    refreshInFlight = true;
    try {
      const root = pickWorkspaceFolder(
        vscode.workspace.workspaceFolders ?? [],
        (folderPath) =>
          fs.existsSync(path.join(folderPath, ".cursor", "gates"))
      );

      if (root === null) {
        statusItem.text = `$(dashboard) ${formatStatusText({
          hasPipeline: false,
          route: "unknown",
          stage: "idle",
          alertPp: null,
        })}`;
        statusItem.tooltip = "No workspace folder with Loregate gates is open.";
        lastOutput = unavailableOutput("");
        lastTree = emptyTree("No workspace folder with Loregate gates is open.");
        updatePipelineMapSurfaces(lastTree);
        const fallbackRoot =
          vscode.workspace.workspaceFolders?.[0]?.uri.fsPath;
        if (fallbackRoot !== undefined) {
          syncPipelineMapCanvas(fallbackRoot, lastTree);
        }
        return;
      }

      const snapshotsPath = path.join(
        root,
        ".cursor",
        "gates",
        "context-spend",
        "snapshots.jsonl"
      );
      const orientation = await fetchPipelineOrientation(root, {
        homedir: os.homedir(),
        readFile,
      });

      if ("error" in orientation) {
        statusItem.text = "$(dashboard) pipe — (unavailable)";
        statusItem.tooltip = `Loregate pipeline status is unavailable: ${orientation.error}`;
        lastOutput = unavailableOutput(snapshotsPath);
        lastTree = emptyTree(orientation.error);
        updatePipelineMapSurfaces(lastTree);
        syncPipelineMapCanvas(root, lastTree);
        return;
      }

      const snapshots = latestSessionSnapshots(
        loadSnapshots(readFile(snapshotsPath) ?? "")
      );
      const latestSnapshot = snapshots.at(-1);
      const metrics =
        latestSnapshot === undefined
          ? metricsForSession([], "", orientation.stage, null)
          : metricsForSession(
              snapshots,
              latestSnapshot.session_id,
              orientation.stage,
              latestSnapshot.stage === orientation.stage
                ? latestSnapshot.ctx_pct
                : null
            );
      const hint = hintForStage(orientation.stage) ?? null;

      statusItem.text = `$(dashboard) ${formatStatusText({
        hasPipeline: orientation.hasPipeline,
        route: orientation.route,
        stage: orientation.stage,
        alertPp: metrics.alert ? metrics.deltaStagePp : null,
      })}`;
      statusItem.tooltip = tooltip(
        metrics.peakStage,
        metrics.peakPp,
        hint
      );
      lastOutput = formatOutput({
        route: orientation.route,
        stage: orientation.stage,
        deltaStagePp: metrics.deltaStagePp,
        peakStage: metrics.peakStage,
        peakPp: metrics.peakPp,
        hint,
        snapshotsPath,
      });

      lastTree = buildPipelineTree({
        route: orientation.route,
        layer: orientation.layer,
        stage: orientation.stage,
        stagesEntered: orientation.stagesEntered,
        pendingGates: orientation.pendingGates,
        hasPipeline: orientation.hasPipeline,
      });
      updatePipelineMapSurfaces(lastTree);
      syncPipelineMapCanvas(root, lastTree);
    } finally {
      refreshInFlight = false;
    }
  };

  const workspaceListener = vscode.workspace.onDidChangeWorkspaceFolders(() => {
    void refresh();
  });

  const viewRegistration = vscode.window.registerWebviewViewProvider(
    getPipelineMapViewType(),
    mapProvider
  );

  statusItem.command = SHOW_MAP_COMMAND;
  statusItem.text = "$(dashboard) pipe — (no gates)";
  statusItem.tooltip = "Loregate pipeline map is loading. Select to open the map.";
  statusItem.show();

  refreshTimer = setInterval(() => {
    void refresh();
  }, REFRESH_INTERVAL_MS);

  registeredDisposables = [
    statusItem,
    outputChannel,
    showOutput,
    showMap,
    workspaceListener,
    viewRegistration,
  ];
  context.subscriptions.push(...registeredDisposables);
  void refresh();
}

export function deactivate(): void {
  if (refreshTimer !== undefined) {
    clearInterval(refreshTimer);
    refreshTimer = undefined;
  }

  for (const disposable of registeredDisposables) {
    disposable.dispose();
  }
  registeredDisposables = [];
  statusItem = undefined;
  outputChannel = undefined;
}

function readFile(filePath: string): string | null {
  try {
    return fs.readFileSync(filePath, "utf8");
  } catch {
    return null;
  }
}

function tooltip(
  peakStage: string | null,
  peakPp: number | null,
  hint: string | null
): string {
  const peak =
    peakStage === null || peakPp === null ? "—" : `${peakStage} (+${peakPp})`;
  return [
    `Peak context spend: ${peak}`,
    `Hint: ${hint ?? "—"}`,
    "Select to open Loregate Pipeline Map.",
  ].join("\n");
}

function unavailableOutput(snapshotsPath: string): string {
  return formatOutput({
    route: "unknown",
    stage: "idle",
    deltaStagePp: null,
    peakStage: null,
    peakPp: null,
    hint: null,
    snapshotsPath,
  });
}

function emptyTree(error?: string): PipelineTree {
  return buildPipelineTree({
    route: "unknown",
    layer: "idle",
    stage: "idle",
    stagesEntered: [],
    pendingGates: [],
    hasPipeline: false,
    error,
  });
}
