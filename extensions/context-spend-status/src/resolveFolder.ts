export function pickWorkspaceFolder(
  folders: readonly { uri: { fsPath: string } }[],
  gatesExists: (folderPath: string) => boolean
): string | null {
  if (folders.length === 0) {
    return null;
  }

  return (
    folders.find((folder) => gatesExists(folder.uri.fsPath))?.uri.fsPath ??
    folders[0].uri.fsPath
  );
}
