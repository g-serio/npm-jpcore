# Todo: Next public page JSON (Local / Static / Live)

Plan: `docs/plans/next-public-page-json.md`  
Status: **implement complete — awaiting human review**

## Phase 1: Local parity

- [x] **Task A:** `resolvePublicPageJson` in `@olonjs/next/server` + unit tests
- [x] **Task B:** Slice-filter helper parity with Vite plugin (dynamic params)
- [x] **Task C:** `GET /api/public-page/[...slug]` + rewrites for `/*.json` and `/pages/*.json`
- [x] **Task D:** Wire Local source into handler; smoke `/home.json`

### Checkpoint: Local

- [x] `/home.json` works like Vite local
- [x] Visitor HTML routes still work
- [ ] Human review

## Phase 2: Static + Live

- [x] **Task E:** Static published content source adapter
- [x] **Task F:** Live cloud content source adapter
- [x] **Task G:** Source selection from cloud policy / bootSource + smoke matrix

### Checkpoint: Complete

- [x] Three modes OK (unit matrix + Local curl smoke)
- [x] No public JSON files required to serve
- [ ] Human review
