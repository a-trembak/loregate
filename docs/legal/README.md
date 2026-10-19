# Legal documents — Loregate

![Loregate LGT logo](lgt-logo.png)

Formal English policy documents for this pipeline kit authored by **Andrey Trembak** (`a-trembak`).

**Product name:** **Loregate** (short mark **LGT**). Tagline: *From lore to merge through gates.* GitHub: [`a-trembak/loregate`](https://github.com/a-trembak/loregate) (formerly `cursor-spells`). Details: [NAME-OPTIONS.md](NAME-OPTIONS.md). Do not use third-party marks such as “Cursor” in the product title.

| Document | Purpose |
|----------|---------|
| [PRIVACY.md](PRIVACY.md) | Privacy Policy — data use for a local agent kit; honest limits of author control |
| [TERMS.md](TERMS.md) | Terms of use / rights notice — MIT consistency, reserved names, acceptable use |
| [DISCLAIMER.md](DISCLAIMER.md) | Disclaimer of warranty and limitation of liability (AS IS / use at own risk) |
| [NOTICE.md](NOTICE.md) | Trademark / rights protection mark — displayable “Rights reserved” block + logo |
| [NAME-OPTIONS.md](NAME-OPTIONS.md) | Chosen name **Loregate** / **LGT**, deferred options; manual GitHub rename only |
| [SOURCES.md](SOURCES.md) | Research sources (including Context7 libraries/topics consulted) |

## Install agreement

`lgt install` / `lgt update` require agreement to Privacy, Terms, Disclaimer, and NOTICE before continuing. Non-interactive runs need `--agree-policy` or `--i-agree` (or `LGT_AGREE_POLICY=1`; alias `CSP_AGREE_POLICY=1`). A successful agreement writes `.cursor/lgt-policy-accepted` and legacy `.cursor/csp-policy-accepted` (or under `~/.cursor/` for `--user-only`) with `accepted_at`, `agree_via`, `policy_hash`, `policy_docs`, and `kit_commit`.

Deprecated CLI `csp` still forwards to `lgt` with a warning.

## Quick points

- **Software copyright:** MIT as stated in the root `README.md` (Software Package Data Exchange: `MIT`). No root `LICENSE` file was present when these docs were written — see TERMS for the consistency note.  
- **Names / identity:** reserved; MIT does not grant trademark or endorsement rights.  
- **Warranty:** none; pipeline use can cause bugs and regressions; see DISCLAIMER.  
- **Russian language:** forbidden inside this pipeline under the kit’s sanctions-based language policy; use tools outside the pipeline if needed. Runtime enforcement is documented in [`docs/superpowers/pipeline-language.md`](../superpowers/pipeline-language.md).

These documents are informational policy text. They are not a substitute for advice from a lawyer admitted in your jurisdiction.
