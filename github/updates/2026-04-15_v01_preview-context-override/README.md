# 2026-04-15 v01 Preview Context Override

This update pack adds the preview-safe architecture proposal for dual-mode selected-context validation.

Included:

- `DOCS/architecture/preview-context-override-v1.md`

Intent:

- keep first-party selected-context cookie flow unchanged
- add a preview-only request-scoped context override proposal
- force preview override into read-only mode
- document which routes may support preview override and which must explicitly reject it

GitHub target mapping:

- `DOCS/architecture/preview-context-override-v1.md` -> `docs/architecture/preview-context-override-v1.md`
