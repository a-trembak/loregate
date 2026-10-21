const HINTS = new Map<string, string>([
  ["tech-spec", "thin-spec"],
  ["spec", "thin-spec"],
  ["plan", "thin-plan"],
  ["approve-plan", "thin-plan"],
  ["writing-plans", "thin-plan"],
  ["critic", "compact-critic"],
  ["implementation-critic", "compact-critic"],
  ["critique", "compact-critic"],
  ["build", "slim-handoff"],
  ["start-build", "slim-handoff"],
  ["software-developer", "slim-handoff"],
  ["csp-software-developer", "slim-handoff"],
  ["eng-review", "cut-clarify"],
  ["engineer-review", "cut-clarify"],
  ["review-gate", "cut-clarify"],
  ["clarify", "cut-clarify"],
  ["finish-plan", "less-diff-paste"],
  ["local-diff", "less-diff-paste"],
  ["docs", "short-docs"],
  ["update-docs", "short-docs"],
  ["docs-gate", "short-docs"],
  ["create-pr", "short-pr"],
  ["finale", "short-pr"],
]);

const TOKENS_BY_LENGTH = [...HINTS.keys()].sort(
  (left, right) => right.length - left.length
);

export function hintForStage(stage: string): string | undefined {
  const exact = HINTS.get(stage);
  if (exact !== undefined) {
    return exact;
  }

  const token = TOKENS_BY_LENGTH.find((candidate) => stage.includes(candidate));
  return token === undefined ? undefined : HINTS.get(token);
}
