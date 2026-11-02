import { chatKeyForStage } from "./pipelineNavKeys";
import type { NodeState, PipelineTree } from "./treeModel";

/** Distinct from legacy `loregate-pipeline-map.canvas.tsx` (Stat UI) so stale
 * extension hosts that still poll the old filename cannot clobber this file. */
const CANVAS_NAME = "loregate-pipeline-status.canvas.tsx";

/** Bump when canvas markup changes so writers rewrite even if pipeline state is unchanged. */
export const PIPELINE_MAP_UI_VERSION = "v2-tables-copy";

export function pipelineMapCanvasFileName(): string {
  return CANVAS_NAME;
}

function rowTone(
  state: NodeState
): "success" | "warning" | "danger" | "info" | "neutral" {
  switch (state) {
    case "done":
      return "success";
    case "here":
      return "warning";
    case "blocked":
      return "danger";
    case "waiting":
      return "neutral";
    default:
      return "info";
  }
}

function statusLabel(state: NodeState): string {
  switch (state) {
    case "done":
      return "done";
    case "here":
      return "here";
    case "blocked":
      return "blocked";
    default:
      return "waiting";
  }
}

/** Stable fingerprint so ~3s polls do not rewrite when the tree is unchanged. */
export function pipelineMapCanvasFingerprint(tree: PipelineTree): string {
  return JSON.stringify({
    route: tree.route,
    layer: tree.layer,
    stage: tree.stage,
    hasPipeline: tree.hasPipeline,
    error: tree.error ?? null,
    layers: tree.layers.map((layer) => ({
      id: layer.id,
      state: layer.state,
      nodes: layer.nodes.map((node) => ({
        id: node.id,
        state: node.state,
      })),
    })),
    ui: PIPELINE_MAP_UI_VERSION,
  });
}

/** Build Agent Window canvas source with embedded STATE (hot-reloads on disk write). */
export function renderPipelineMapCanvasSource(tree: PipelineTree): string {
  const stateJson = JSON.stringify(
    {
      route: tree.route,
      layer: tree.layer,
      stage: tree.stage,
      hasPipeline: tree.hasPipeline,
      error: tree.error ?? null,
      updatedAt: new Date().toISOString(),
      layers: tree.layers.map((layer) => ({
        id: layer.id,
        label: layer.label,
        state: layer.state,
        tone: rowTone(layer.state),
        status: statusLabel(layer.state),
        nodes: layer.nodes.map((node) => ({
          id: node.id,
          label: node.label,
          state: node.state,
          tone: rowTone(node.state),
          status: statusLabel(node.state),
          chatKey: chatKeyForStage(node.id),
        })),
      })),
    },
    null,
    2
  );

  return `/* lgt-pipeline-map-ui:${PIPELINE_MAP_UI_VERSION} */
import {
  Button,
  Callout,
  Code,
  Divider,
  H1,
  H2,
  Row,
  Stack,
  Table,
  Text,
  useCanvasState,
} from "cursor/canvas";

type NodeState = "done" | "here" | "waiting" | "blocked";
type Tone = "success" | "warning" | "danger" | "info" | "neutral";

type MapNode = {
  id: string;
  label: string;
  state: NodeState;
  tone: Tone;
  status: string;
  chatKey: string;
};

type MapLayer = {
  id: string;
  label: string;
  state: NodeState;
  tone: Tone;
  status: string;
  nodes: MapNode[];
};

type MapState = {
  route: string;
  layer: string;
  stage: string;
  hasPipeline: boolean;
  error: string | null;
  updatedAt: string;
  layers: MapLayer[];
};

const STATE: MapState = ${stateJson};

function shortTime(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) {
    return iso;
  }
  return d.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
}

function CopyKeyButton({ chatKey }: { chatKey: string }) {
  const [copiedKey, setCopiedKey] = useCanvasState<string | null>(
    "copiedKey",
    null
  );
  const copied = copiedKey === chatKey;
  return (
    <Button
      variant={copied ? "primary" : "secondary"}
      onClick={() => {
        void navigator.clipboard.writeText(chatKey).then(() => {
          setCopiedKey(chatKey);
        });
      }}
    >
      {copied ? "Copied" : "Copy"}
    </Button>
  );
}

export default function LoregatePipelineMap() {
  const [lastCopied, setLastCopied] = useCanvasState<string | null>(
    "copiedKey",
    null
  );

  if (STATE.error) {
    return (
      <Stack gap={12}>
        <H1>Loregate pipeline</H1>
        <Callout tone="danger" title="Unavailable">
          {STATE.error}
        </Callout>
      </Stack>
    );
  }

  return (
    <Stack gap={14}>
      <Stack gap={4}>
        <H1>Loregate pipeline</H1>
        <Text tone="secondary" size="small">
          {STATE.route} · {STATE.layer} · {STATE.stage}
        </Text>
        <Text tone="tertiary" size="small">
          Updated {shortTime(STATE.updatedAt)} · live from disk
        </Text>
      </Stack>

      <Callout tone="info" title="Navigate from here">
        Press Copy on a stage. The key lands in your clipboard — paste it into
        chat (⌘V / Ctrl+V). Canvas cannot type into the current chat for you.
      </Callout>

      {lastCopied ? (
        <Row gap={8} align="center">
          <Text tone="secondary" size="small">
            Clipboard:
          </Text>
          <Code>{lastCopied}</Code>
          <Button variant="ghost" onClick={() => setLastCopied(null)}>
            Clear
          </Button>
        </Row>
      ) : null}

      {!STATE.hasPipeline ? (
        <Callout tone="neutral" title="Idle">
          No active Loregate gates or ledger in this workspace yet. You can still
          copy a stage key to jump the pipeline from chat.
        </Callout>
      ) : null}

      {STATE.layers.map((layer) => (
        <Stack key={layer.id} gap={6}>
          <H2>
            {layer.label}
            <Text tone="tertiary" size="small">
              {" "}
              · {layer.status}
            </Text>
          </H2>
          <Table
            framed={false}
            headers={["Stage", "Status", "Paste key", ""]}
            columnAlign={["left", "left", "left", "left"]}
            rows={layer.nodes.map((node) => [
              <Text
                key={node.id + "-label"}
                weight={node.state === "here" ? "semibold" : "normal"}
              >
                {node.label}
              </Text>,
              node.status,
              <Code key={node.id + "-key"}>{node.chatKey}</Code>,
              <CopyKeyButton key={node.id + "-copy"} chatKey={node.chatKey} />,
            ])}
            rowTone={layer.nodes.map((node) => node.tone)}
          />
        </Stack>
      ))}

      <Divider />
      <Text tone="tertiary" size="small">
        Green done · amber here · grey waiting · red blocked (human gate)
      </Text>
    </Stack>
  );
}
`;
}
