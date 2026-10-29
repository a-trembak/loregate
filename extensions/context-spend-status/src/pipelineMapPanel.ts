import * as vscode from "vscode";
import { renderPipelineMapHtml } from "./pipelineMapHtml";
import type { PipelineTree } from "./treeModel";

const VIEW_TYPE = "loregate.pipelineMap";
const PANEL_TITLE = "Loregate Pipeline";

let editorPanel: vscode.WebviewPanel | undefined;

export function getPipelineMapViewType(): string {
  return VIEW_TYPE;
}

export function revealOrCreatePipelineMapPanel(
  tree: PipelineTree,
  extensionUri: vscode.Uri
): void {
  if (editorPanel !== undefined) {
    editorPanel.reveal(vscode.ViewColumn.Beside, true);
    editorPanel.webview.html = renderPipelineMapHtml(tree);
    return;
  }

  editorPanel = vscode.window.createWebviewPanel(
    VIEW_TYPE,
    PANEL_TITLE,
    { viewColumn: vscode.ViewColumn.Beside, preserveFocus: true },
    {
      enableScripts: true,
      retainContextWhenHidden: true,
      localResourceRoots: [extensionUri],
    }
  );

  editorPanel.webview.html = renderPipelineMapHtml(tree);
  editorPanel.onDidDispose(() => {
    editorPanel = undefined;
  });
}

export function updatePipelineMapSurfaces(tree: PipelineTree): void {
  if (editorPanel !== undefined) {
    editorPanel.webview.html = renderPipelineMapHtml(tree);
  }
  PipelineMapViewProvider.current?.update(tree);
}

export class PipelineMapViewProvider implements vscode.WebviewViewProvider {
  public static current: PipelineMapViewProvider | undefined;

  private view?: vscode.WebviewView;
  private latest: PipelineTree;

  constructor(
    private readonly extensionUri: vscode.Uri,
    initial: PipelineTree
  ) {
    this.latest = initial;
    PipelineMapViewProvider.current = this;
  }

  resolveWebviewView(
    webviewView: vscode.WebviewView,
    _context: vscode.WebviewViewResolveContext,
    _token: vscode.CancellationToken
  ): void {
    this.view = webviewView;
    webviewView.webview.options = {
      enableScripts: true,
      localResourceRoots: [this.extensionUri],
    };
    webviewView.webview.html = renderPipelineMapHtml(this.latest);
  }

  update(tree: PipelineTree): void {
    this.latest = tree;
    if (this.view !== undefined) {
      this.view.webview.html = renderPipelineMapHtml(tree);
    }
  }
}

export async function focusPipelineMapView(): Promise<void> {
  try {
    await vscode.commands.executeCommand("workbench.view.extension.loregate");
  } catch {
    // Activity Bar container may be unavailable in some layouts.
  }
  try {
    await vscode.commands.executeCommand(`${VIEW_TYPE}.focus`);
  } catch {
    // Focus is best-effort when the view is not registered yet.
  }
}
