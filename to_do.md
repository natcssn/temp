# EZFOODZ Implementation Tracker

Last updated: 2026-05-28
Owner: GitHub Copilot + project owner
Execution style: phased delivery

## Phase Checklist

- [x] Phase 0: Documentation baseline and tracking setup
- [x] Phase 1: Required student profile fields (college + ID CARD upload)
- [x] Phase 2: Free OCR/CV verification (college name extraction + match)
- [x] Phase 3: Google OAuth gate (blocked until required fields + verification pass)
- [x] Phase 4: Razorpay payment reliability in TEST mode
- [x] Phase 5: Order-status misclick-safe UX improvements
- [x] Phase 6: Add-item redirect fixes (React + legacy dashboard resilience)
- [x] Phase 7: Delivery partner backend end-to-end
- [x] Phase 8: Delivery partner Flutter flow end-to-end (final image order)
- [x] Phase 9: Full app flow testing and final docs reconciliation
- [x] Phase 11: Razorpay Payment Validation Hardening and Recovery
- [x] Phase 12: Restored Registration and Verification Endpoints
- [x] Phase 13: Google Sign-in Dependency Alignment
- [x] Phase 14: Dynamic Onboarding, College Admins Dashboard & APK Hardening

Phase 9 status note:
- Automated verification batch completed in this workspace.
- Full in-process backend E2E smoke (14 checkpoints) now passes.
- Cross-stack rerun completed: backend compile + React build pass; Flutter analyzer hard errors fixed.
- Runtime UX patch cycle (2026-04-19) applied: friendly checkout error text, top app-bar Order Status shortcut, delivery-aware ready-order status guard in both dashboards, and web OAuth popup path update.
- Manual app runtime checks are still pending for final close.

## Active Implementation Decisions

1. Use Razorpay TEST mode now; LIVE rollout later.
2. Use free OCR/CV model path now; improve with more samples later.
3. Mismatch/failure response message should stay simple:
   - `idcard and college chosen doesnt match`
4. Delivery flow screen order is fixed from provided image sequence.
5. Customer app UI can be modernized heavily, but core functional flow must not break.

## Pending Inputs From Project Owner

- [ ] Razorpay test keys confirmed in backend `.env`
- [ ] Manual test-card E2E run pending (`6527 6589 0000 1005`)
- [ ] More ID-card samples to improve OCR/CV robustness
  - Reminder: friend ID cards to be uploaded later
  - Current OCR path implemented with local rapidocr + Hugging Face fallback
- [ ] Optional: `HF_TOKEN` if Hugging Face fallback usage is desired
- [ ] Final live deployment API URL (post-deploy)

## Testing Targets (Phase 9)

- [x] Auth flow: required fields + upload + verification gate (automated backend E2E)
- [ ] OAuth gate: blocked before verification, allowed after verification (manual Flutter UI runtime pending)
- [x] Payment flow: create-order -> verify-and-place-order idempotency (automated backend E2E with safe payment stub)
- [ ] Order-status UX: avoid accidental irreversible actions
- [ ] Restaurant add-item navigation and session-expiry resilience
- [x] Delivery partner backend path: available -> accept -> pickup -> complete -> earnings (automated E2E)
- [ ] Delivery partner full app path from CTA to earnings confirmation (manual Flutter runtime pending)

## Phase 9 Validation Snapshot (2026-04-18)

- [x] Backend compile check (`python3 -m compileall -q .`)
- [x] Delivery router smoke check (all `/delivery/*` routes mounted)
- [x] In-process delivery API smoke (`/delivery/register`, `/me`, `/orders/available`, `/earnings/summary` returned 200)
- [x] Full in-process backend E2E smoke (14/14 checkpoints passed)
- [x] React dashboard build (`npm run build`)
- [x] Flutter analyze run completed (changed files have no blocking errors)
- [x] Flutter analyzer hard errors resolved in this cycle (`lib/razorpay_web_checkout_web.dart`, `test/widget_test.dart`)
- [x] Flutter widget smoke test (`flutter test test/widget_test.dart`)
- [x] Dashboard delivery-aware ready-order action guard (React + legacy now hide direct `Mark Given` for delivery-mode ready orders)
- [x] Runtime UX file diagnostics clean for this patch (`cart_page.dart`, `login.dart`, `restaurants_page.dart`, `order_status_page.dart`, dashboard order pages)
- [ ] Manual browser observation pending: verify repeated GSI `different origin` log spam is reduced after popup-flow update
- [ ] Flutter analyzer still reports non-blocking lint/info diagnostics (1 warning, info-level items)
- [ ] Manual Razorpay TEST card checkout (`6527 6589 0000 1005`)
- [ ] Manual OCR verification run with additional real ID-card samples
- [ ] Manual delivery partner runtime E2E confirmation on running app

## Notes

- Update this file at the end of every phase.
- Update `README.md`, `deploy.md`, and `currentstate.md` in the same phase commit.
