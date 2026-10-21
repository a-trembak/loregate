import test from "node:test";
import assert from "node:assert/strict";
import { hintForStage } from "./hints";

test("maps every exact stage token to its hint", () => {
  const cases: Array<[string, string]> = [
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
  ];

  for (const [stage, hint] of cases) {
    assert.equal(hintForStage(stage), hint);
  }
});

test("prefers an exact stage match before substring matches", () => {
  assert.equal(hintForStage("approve-plan"), "thin-plan");
});

test("matches stage tokens embedded in a larger stage name", () => {
  assert.equal(hintForStage("pre-review-gate-check"), "cut-clarify");
});

test("returns undefined when no stage token matches", () => {
  assert.equal(hintForStage("idle"), undefined);
});
