import test from "node:test";
import assert from "node:assert/strict";
import { pickWorkspaceFolder } from "./resolveFolder";

test("prefers the first workspace folder with pipeline gates", () => {
  const folders = [
    { uri: { fsPath: "/workspace/first" } },
    { uri: { fsPath: "/workspace/second" } },
    { uri: { fsPath: "/workspace/third" } },
  ];

  assert.equal(
    pickWorkspaceFolder(
      folders,
      (folderPath) => folderPath === "/workspace/second"
    ),
    "/workspace/second"
  );
});

test("falls back to the first workspace folder", () => {
  const folders = [
    { uri: { fsPath: "/workspace/first" } },
    { uri: { fsPath: "/workspace/second" } },
  ];

  assert.equal(pickWorkspaceFolder(folders, () => false), "/workspace/first");
});

test("returns null when no workspace folder is open", () => {
  assert.equal(pickWorkspaceFolder([], () => false), null);
});
