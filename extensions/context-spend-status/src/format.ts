export function formatStatusText(input: {
  hasPipeline: boolean;
  route: string;
  stage: string;
  alertPp: number | null;
}): string {
  if (!input.hasPipeline) {
    return "pipe — (no gates)";
  }

  const alert = input.alertPp === null ? "" : ` ⚠+${input.alertPp}`;
  return `pipe ${input.route}·${input.stage}${alert}`;
}

export function formatOutput(input: {
  route: string;
  stage: string;
  deltaStagePp: number | null;
  peakStage: string | null;
  peakPp: number | null;
  hint: string | null;
  snapshotsPath: string;
}): string {
  const stageSpend =
    input.deltaStagePp === null
      ? "—"
      : `${signed(input.deltaStagePp)}pp/stage`;
  const peak =
    input.peakStage === null || input.peakPp === null
      ? "—"
      : `${input.peakStage}(${signed(input.peakPp)})`;

  return [
    "Loregate context spend (proxies — not billing)",
    `route: ${input.route}`,
    `stage: ${input.stage}`,
    stageSpend,
    `peak: ${peak}`,
    `hint: ${input.hint ?? "—"}`,
    `snapshots: ${input.snapshotsPath}`,
    "ring %: n/a in IDE (use Agent CLI statusLine)",
  ].join("\n");
}

function signed(value: number): string {
  return value >= 0 ? `+${value}` : String(value);
}
