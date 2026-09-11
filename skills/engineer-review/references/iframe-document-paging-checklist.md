# Iframe-hosted document paging (D1–D2)

Canonical gates for `csp-review-logic` when a native in-app browser (`WebView` / `react-native-webview` or equivalent) loads a URL whose document body can be a **PDF (or other paginated file) inside an iframe**, or when that body is produced by a related/sibling codebase rather than the native wrapper in the diff.

This is **not** the nested native `ScrollView` + `WebView` class (outer scroller steals the pan). Here the host WebView may already be the only native scroller; the miss is **page count, iframe height, and document-shape variants** of the embedded file.

Do **not** hardcode product names, ticket ids, or legal-page titles. Apply the rules; examples are illustration only.

---

## D1 — Multi-page PDF in an iframe, not a single-page snapshot

**Trigger:** stack includes a native WebView (or equivalent) **and** the diff adds or changes a screen that loads a remote/local HTML URL, **or** the hosted page (in this repo or a related/sibling renderer) embeds a PDF or other paginated document in an `iframe`.

**Required check:**

1. Determine how the hosted page puts the document on screen: inline HTML, or an `iframe`/`embed`/`object` pointing at a PDF (or other paginated MIME). Do not assume the fixture in the diff is the only shape.
2. If a PDF (or paginated file) can appear in an iframe, review it as a **multi-page** document:
   - iframe height versus the full document height (a `100vh` / `100%` iframe does not make later pages reachable if the iframe itself cannot scroll or page);
   - in-iframe scroll, PDF viewer paging controls, or native WebView scrolling through the iframe;
   - whether the WebView viewport clips page 2+ or traps the pan gesture so later pages cannot be reached.
3. A single-page screenshot, a short HTML fixture, or “the iframe loaded” is not evidence that a long PDF is readable.

**Do not flag:**

- A WebView that can only ever serve non-paginated HTML (no PDF iframe path exists in the hosted URL handler)
- A PDF opened in the OS viewer or share sheet, not inside an iframe in the WebView
- Nested native `ScrollView` wrapping a WebView — that is a separate gate when that checklist is loaded; do not treat D1 as a substitute

**Anti-pattern:** approving after a single-page iframe or short HTML render while the hosted page can show a multi-page PDF whose later pages are clipped or unscrollable.

**Illustration only:** a legal HTML page looks fine in the WebView; the same URL on another locale or brand injects a PDF iframe, and only the first page is visible.

---

## D2 — Related-codebase document variants, not only the diff fixture

**Trigger:** D1 fired, **or** the native screen loads a document URL whose HTML/PDF body is rendered by a related or sibling repository (web frontend, CMS template, or shared legal/help renderer).

**Required check:**

1. Open the related/sibling renderer that actually chooses HTML versus PDF iframe (and locale/brand copies). Do not stop at the native WebView wrapper in the diff.
2. List the shapes that renderer can serve to this hosted URL: translated HTML vs PDF iframe; short vs long / multi-page documents; other document families the same route can return.
3. Run D1 against **each** shape the product page can actually serve. One fixture or one network recording is not coverage.
4. Do **not** start a full multi-repository review solely for this gate. Read enough of the related renderer (sibling checkout, shared template, or documented URL handler) to list the live shapes. Skip variants the hosted URL cannot select (dead code).

**Anti-pattern:** reviewing only the HTML fixture or the one PDF seen in the native diff while a sibling web renderer can still serve a different iframe PDF (or a much longer document) on the same route.

**Illustration only:** native review uses a short translated HTML document; the web renderer for the same path still embeds a multi-page PDF in an iframe for other locales.

---

## Coverage

When D1 or D2 fired, engineer-review Coverage **must** include:

```text
iframe_document_paging: paging+variants | one-shape | skipped | n/a
```

- `paging+variants` — iframe/PDF paging checked **and** related-renderer shapes listed
- `one-shape` — only the fixture or one document body in the diff (incomplete when other shapes exist)
- `skipped` — trigger in scope but neither paging nor variants checked (incomplete review; prefer clarify)
- `n/a` — D1/D2 not in scope

## Evidence

Every finding needs `path`, `start_line`, `end_line`, `snippet`, and `context` per `phase-protocol.md`.
