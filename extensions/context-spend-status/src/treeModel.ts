export type NodeState = "done" | "here" | "waiting" | "blocked";

export type TreeNode = {
  id: string;
  label: string;
  state: NodeState;
};

export type TreeLayer = {
  id: string;
  label: string;
  state: NodeState;
  nodes: TreeNode[];
};

export type PipelineTree = {
  route: string;
  layer: string;
  stage: string;
  hasPipeline: boolean;
  layers: TreeLayer[];
  error?: string;
};

/** Canonical full-path spine for the map (labels are English; kit UI). */
export const CANONICAL_LAYERS: {
  id: string;
  label: string;
  nodes: { id: string; label: string }[];
}[] = [
  {
    id: "fetch",
    label: "Fetch",
    nodes: [{ id: "jira-fetch", label: "Fetch / route" }],
  },
  {
    id: "plan",
    label: "Plan",
    nodes: [
      { id: "csp-tech-spec", label: "Tech spec" },
      { id: "writing-plans", label: "Writing plans" },
      { id: "approve-plan", label: "Approve plan / critic" },
    ],
  },
  {
    id: "build",
    label: "Build",
    nodes: [
      { id: "start-build", label: "Start build" },
      { id: "csp-software-developer", label: "Software developer" },
    ],
  },
  {
    id: "review",
    label: "Review",
    nodes: [
      { id: "review-gate", label: "Review gate" },
      { id: "engineer-review", label: "Engineer review" },
      { id: "local-diff-review-gate", label: "Local Diff Review" },
    ],
  },
  {
    id: "ship",
    label: "Ship",
    nodes: [
      { id: "propose-commit", label: "Propose commit" },
      { id: "update-docs", label: "Update docs" },
      { id: "create-pr", label: "Create pull request" },
    ],
  },
];

const STAGE_ALIASES: Record<string, string> = {
  idle: "idle",
  fetch: "jira-fetch",
  "pipeline-route-hitl": "jira-fetch",
  "jira-transition": "jira-fetch",
  "jira-transition-in-progress": "jira-fetch",
  "csp-tech-spec": "csp-tech-spec",
  "tech-spec": "csp-tech-spec",
  "writing-plans": "writing-plans",
  "approve-plan": "approve-plan",
  "plan-gate": "approve-plan",
  "critique-gate": "approve-plan",
  "csp-implementation-critic": "approve-plan",
  "clean-decision-docs": "writing-plans",
  "issue-fix-plan": "writing-plans",
  "start-build": "start-build",
  "csp-software-developer": "csp-software-developer",
  "csp-bug-fixer": "csp-software-developer",
  "executing-plans": "csp-software-developer",
  "review-gate": "review-gate",
  "engineer-review": "engineer-review",
  "csp-engineer-reviewer": "engineer-review",
  "csp-multi-repo-supervisor": "engineer-review",
  "local-diff-review-gate": "local-diff-review-gate",
  "local-diff-review": "local-diff-review-gate",
  "propose-commit": "propose-commit",
  "update-docs": "update-docs",
  "docs-gate": "update-docs",
  "create-pr": "create-pr",
  "pipeline-finale-hitl": "create-pr",
};

function normalizeStage(stage: string): string {
  if (STAGE_ALIASES[stage]) {
    return STAGE_ALIASES[stage];
  }
  if (stage.includes("local-diff")) {
    return "local-diff-review-gate";
  }
  if (stage.includes("engineer") || stage.includes("multi-repo")) {
    return "engineer-review";
  }
  if (stage.includes("review-gate") || stage === "review-gate") {
    return "review-gate";
  }
  return stage;
}

function flattenOrder(): string[] {
  return CANONICAL_LAYERS.flatMap((layer) => layer.nodes.map((n) => n.id));
}

function indexOfStage(stageId: string): number {
  const order = flattenOrder();
  const idx = order.indexOf(normalizeStage(stageId));
  return idx;
}

function maxReachedIndex(stagesEntered: string[], current: string): number {
  let max = -1;
  for (const raw of stagesEntered) {
    const idx = indexOfStage(raw);
    if (idx > max) {
      max = idx;
    }
  }
  const cur = indexOfStage(current);
  if (cur > max) {
    max = cur;
  }
  return max;
}

function pendingBlockedIds(pendingGates: unknown[]): Set<string> {
  const blocked = new Set<string>();
  for (const gate of pendingGates) {
    if (typeof gate !== "object" || gate === null) {
      continue;
    }
    const kind = (gate as { kind?: unknown }).kind;
    if (typeof kind !== "string") {
      continue;
    }
    if (kind === "plan-gate" || kind === "critique-gate") {
      blocked.add("approve-plan");
    } else if (kind === "review-gate") {
      blocked.add("review-gate");
    } else if (kind === "docs-gate") {
      blocked.add("update-docs");
    } else if (kind.includes("local-diff")) {
      blocked.add("local-diff-review-gate");
    }
  }
  return blocked;
}

export function buildPipelineTree(input: {
  route: string;
  layer: string;
  stage: string;
  stagesEntered: string[];
  pendingGates: unknown[];
  hasPipeline: boolean;
  error?: string;
}): PipelineTree {
  if (input.error) {
    return {
      route: input.route,
      layer: input.layer,
      stage: input.stage,
      hasPipeline: false,
      layers: [],
      error: input.error,
    };
  }

  const currentId = normalizeStage(input.stage);
  const currentIdx = indexOfStage(currentId);
  const reached = maxReachedIndex(input.stagesEntered, input.stage);
  const blocked = pendingBlockedIds(input.pendingGates);

  const layers: TreeLayer[] = CANONICAL_LAYERS.map((layer) => {
    const nodes: TreeNode[] = layer.nodes.map((node) => {
      const idx = indexOfStage(node.id);
      let state: NodeState = "waiting";
      if (currentIdx >= 0 && node.id === currentId) {
        state = blocked.has(node.id) ? "blocked" : "here";
      } else if (blocked.has(node.id) && idx <= Math.max(reached, currentIdx)) {
        state = "blocked";
      } else if (idx >= 0 && idx < currentIdx) {
        state = "done";
      } else if (idx >= 0 && idx <= reached && currentIdx < 0) {
        state = "done";
      } else if (
        currentIdx < 0 &&
        idx >= 0 &&
        normalizeStage(input.stage) === node.id
      ) {
        state = "here";
      }
      return { id: node.id, label: node.label, state };
    });

    const layerState: NodeState = nodes.some((n) => n.state === "blocked")
      ? "blocked"
      : nodes.some((n) => n.state === "here")
        ? "here"
        : nodes.every((n) => n.state === "done")
          ? "done"
          : nodes.some((n) => n.state === "done")
            ? "here"
            : "waiting";

    return {
      id: layer.id,
      label: layer.label,
      state: layerState,
      nodes,
    };
  });

  return {
    route: input.route || "unknown",
    layer: input.layer || "idle",
    stage: input.stage || "idle",
    hasPipeline: input.hasPipeline,
    layers,
  };
}
