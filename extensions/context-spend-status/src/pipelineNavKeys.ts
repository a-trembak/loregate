/**
 * Pasteable chat keys for pipeline map navigation.
 * Prefer slash commands when the kit ships one; otherwise the skill / stage id.
 */
export const STAGE_CHAT_KEYS: Record<string, string> = {
  "jira-fetch": "/lgt-start-task",
  "csp-tech-spec": "/lgt-write-tech-spec",
  "writing-plans": "writing-plans",
  "approve-plan": "/lgt-approve-plan",
  "start-build": "/lgt-start-build",
  "csp-software-developer": "csp-software-developer",
  "review-gate": "/lgt-finish-plan",
  "engineer-review": "/lgt-engineer-review",
  "local-diff-review-gate": "local-diff-review-gate",
  "propose-commit": "propose-commit",
  "update-docs": "/lgt-update-docs",
  "create-pr": "create-pr",
};

export function chatKeyForStage(stageId: string): string {
  return STAGE_CHAT_KEYS[stageId] ?? stageId;
}
