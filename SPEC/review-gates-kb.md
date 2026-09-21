# Mason — review gates (kb / source panels)

**Audience:** reviewers of `SPEC/09ab-source-panels-no-raise.md` implementations and any BindMode undim/hover/hotkey PR that claims to fix source panels.

**SoT:** `09ab` + `09aa-crash-guards.md` + Project `preferences.md`. Pre-09ab chase SPECs under `archive/kb-chase/` are **not** requirements.

Static “machinery exists” is not enough. Prior TOOLTIP raise + still-gray bags already falsified strata-as-undim. Rubber-stamping another raise/timer pass is a process failure.

---

## Verdict vocabulary

| Verdict | When |
|---------|------|
| **APPROVE** | Every open QA failure maps to a concrete mechanism in the diff **and** no gate below fires REJECT/HOLD. |
| **HOLD** | Spec/architecture unclear, or open QA failures are not mapped. Do not APPROVE. |
| **REQUEST CHANGES / REJECT** | A claim hits a hard falsification gate below, or crash hard rules are violated. |

Do **not** APPROVE solely because hard-rule checklist items are present in code. Do **not** APPROVE before human QA on surfaces that already failed multiple rounds — at most HOLD pending QA, and only if the architecture gates pass on paper.

---

## Gate 1 — Undim via strata

**If the claim is** “undim bags/book/toys/macros by `SetFrameStrata` / `Raise` / level bump on Blizzard frames”:

- Author **must** explain why prior **TOOLTIP** raise (above HIGH veil) still left bags gray in QA, **or**
- **REJECT**.

“Veil lowered to LOW” or “raise once per kb” is not an explanation. Strata undim without that accounting is **REJECT**.

Preferred shape (09ab): zero Blizzard strata mutation; veil dims only.

**Product (frozen):** accept current veil dim — no Raise undim, no cutouts unless a later product SPEC asks.

---

## Gate 2 — MacroFrame / Selector raise

**If the claim touches** `Raise` / strata on `MacroFrame`, `MacroSelector`, or their ScrollBox to undim or “fix” blank grid:

- **REJECT** unless the author provides proof that ScrollBox **cannot** blank from that raise (and addresses flash-then-blank history).
- “Raise less often” / “once per kb session” is **not** proof.

Preferred shape (09ab): never raise MacroFrame/Selector for undim.

---

## Gate 3 — Hotkey paint path

**If the claim is** “source hotkeys fixed”:

- Diff must show **store clear + paint** (`RepaintSourceHotkeys` or successor ← binding state / `AfterBindChange` / deferred panel Show / page Update).
- Paint from **bind keypress success alone** → **REJECT** (preferences + 09ab).
- Presence of FontStrings without a store reconcile path → **HOLD** or **REJECT**, not APPROVE.

Always-on: hotkey **display** is not gated on `/mason kb`.

---

## Gate 4 — Map every open QA failure

**No APPROVE** unless the review maps **each** still-open human QA failure to a **specific mechanism** in the change set.

- Unmapped failure → **HOLD**.
- “Code for X exists” without tying X to the failure mode → insufficient.

---

## Gate 5 — Crash hard rules checklist (must still pass)

Any APPROVE or HOLD-for-QA still requires all of these intact (`09aa`):

- [ ] No raise from bag `Show` (paint/attach schedule only).
- [ ] No item-button raise (`RaiseBindItemButtons` no-op or gone).
- [ ] No BindMode **window** tree-walk (`GetChildren` / `GetRegions` on source windows).
- [ ] No `HookBindUndimShow` → raise loop.
- [ ] No `print` from bag/book/toy/macro `Show`.

Cell-local `GetChildren` on a known button to find an icon host is **not** a window tree-walk (09aa).

Violation of any → **REJECT** regardless of undim claims.

---

## Gate 6 — Compensatory timers / pulse

**If the claim adds or keeps:**

- `WatchLazyBindFrames`-style multi-second OnUpdate pulse that re-raises or re-paints Blizzard chrome, or
- Multi-delay raise followup waves for undim,

→ **REJECT** under 09ab (delete, don’t retune). Deferred `After(0)` **once** per panel Show for paint/attach is allowed.

---

## Gate 7 — No revive archived SPECs

**If the PR implements Acceptance from** `SPEC/archive/kb-chase/` (raise bags above veil, SoftFill/Rebuild theater, TOOLTIP undim, etc.) **to “finish” an old SPEC:**

→ **REJECT**. Obsolete-SPEC debt is delete/rename material only (Track B).

---

## Quick reject cheat-sheet

| Claim / diff smell | Verdict |
|--------------------|---------|
| Undim via Blizzard strata without explaining TOOLTIP failure | REJECT |
| MacroFrame/Selector raise without ScrollBox blanking proof | REJECT |
| Hotkeys painted on bind keypress only | REJECT |
| Open QA failures not mapped to mechanisms | HOLD (no APPROVE) |
| Crash hard rule broken | REJECT |
| WatchLazy / multi-delay raise spam retained as “fix” | REJECT |
| Implements archived raise SPEC | REJECT |
| Machinery present + hard rules OK, no failure mapping | HOLD / REQUEST CHANGES — not APPROVE |

---

## Evidence to demand from implementer

1. Pointer to single painter entry and its triggers (kb on / AfterBindChange / Show once deferred / page Update).
2. Confirmation: zero Blizzard `SetFrameStrata`/`Raise` in kb undim path (or only Mason-owned frames).
3. Hover: one mixin install per source kind; no per-open Raise.
4. Human QA paste for first-open bags / book / toy / macros (hover + bind + store hotkeys) — see `qa-kb-source-panels.md`.
