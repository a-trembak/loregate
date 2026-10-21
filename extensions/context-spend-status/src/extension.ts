import * as vscode from "vscode";
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { formatOutput, formatStatusText } from "./format";
import { hintForStage } from "./hints";
import { fetchPipelineOrientation } from "./pipelineStatus";
import { pickWorkspaceFolder } from "./resolveFolder";
import {
  latestSessionSnapshots,
  loadSnapshots,
  metricsForSession,
} from "./snapshots";

const COMMAND = "loregate.contextSpend.show";
const REFRESH_INTERVAL_MS = 3000;

let refreshTimer: NodeJS.Timeout | undefined;
let statusItem: vscode.StatusBarItem | undefined;
let outputChannel: vscode.OutputChannel | undefined;
let registeredDisposables: vscode.Disposable[] = [];

export function activate(context: vscode.ExtensionContext): void {
  statusItem = vscode.window.createStatusBarItem(
    vscode.StatusBarAlignment.Right,
    100
  );
  outputChannel = vscode.window.createOutputChannel("Loregate Context Spend");

  let lastOutput = unavailableOutput("");
  let refreshInFlight = false;

  const showOutput = vscode.commands.registerCommand(COMMAND, () => {
    outputChannel?.replace(lastOutput);
    outputChannel?.show(true);
  });

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
    } finally {
      refreshInFlight = false;
    }
  };

  const workspaceListener = vscode.workspace.onDidChangeWorkspaceFolders(() => {
    void refresh();
  });

  statusItem.command = COMMAND;
  statusItem.text = "$(dashboard) pipe — (no gates)";
  statusItem.tooltip = "Loregate context spend is loading.";
  statusItem.show();

  refreshTimer = setInterval(() => {
    void refresh();
  }, REFRESH_INTERVAL_MS);

  registeredDisposables = [statusItem, outputChannel, showOutput, workspaceListener];
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
    "Select to open Loregate Context Spend output.",
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
