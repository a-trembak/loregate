# Nested WebView scroll (React Native)

Canonical gate for `csp-review-logic` when a React Native diff mounts `WebView` (`react-native-webview` or equivalent) as a full-screen or document surface.

Do **not** hardcode product names or ticket ids. Apply the rule; examples are illustration only.

---

## W1 — Full-screen WebView must be the only vertical scroller

**Trigger:** stack is `react-native` (or Expo) **and** the diff adds or changes a `WebView` / `react-native-webview` usage, **or** a `ScrollView` / `FlatList` / `SectionList` that wraps a `WebView`.

**Required check:**

1. If the WebView shows a long document or fills the screen (`flex: 1` on the WebView or its wrapper), it must be the **only** vertical pan target. Flag a parent `ScrollView` (or another vertical scroller) around that WebView — especially when both use `flex: 1` or the ScrollView `contentContainerStyle` also uses `flex: 1`.
2. Do not accept `nestedScrollEnabled` (or similar) as the fix while the parent scroller remains. Remove the extra scroller; keep padding on a non-scrolling `View`.
3. Require a regression that would fail on the nested tree: the WebView has no `ScrollView` ancestor, or an equivalent structural assertion. Native pan tests are not required; Jest cannot drive the gesture.

**Do not flag:**

- A WebView used as a small non-scrolling preview (`scrollEnabled={false}`, fixed height) inside a list
- A horizontal pager that does not compete for the vertical pan of a document WebView

**Anti-pattern:** wrapping `WebView` in `ScrollView` with both `flex: 1`, so the outer scroller steals the pan gesture and long HTML cannot scroll.

**Illustration only:** a terms or privacy HTML page inside `ScrollView` + `WebView` looks laid out but never moves when the user pans.

## Evidence

Every finding needs `path`, `start_line`, `end_line`, `snippet`, and `context` per `phase-protocol.md`.
