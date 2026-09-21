# Mason SPEC index

Architect-owned. Implementers read the **one** phase SPEC named for the session, plus `00-identity.md`, `api.md`, `lockdown.md`, and `AGENTS.md`.

## Source of truth — BindMode / source panels

Score and implement against **only**:

1. [`09ab-source-panels-no-raise.md`](09ab-source-panels-no-raise.md) — veil dim-only; no Blizzard Raise/strata undim; store-driven always-on hotkeys
2. [`09aa-crash-guards.md`](09aa-crash-guards.md) — no bag Show→raise; no item-button raise; no window tree-walk; no print-from-Show; one painter/adapters
3. Project `preferences.md` (when present) — always-on store hotkeys; never tree-walk; never raise from bag Show; **accept current veil dim**; **profile-owned layouts**

**Do not** treat pre-09ab fight SPECs as requirements. They live under [`archive/kb-chase/`](archive/kb-chase/) with stubs at the old paths.

Before writing any new `09*` kb / undim / hotkey SPEC: grep this index and the archive; cite 09ab Forbidden + pass [`review-gates-kb.md`](review-gates-kb.md).

## Living SPECs (keep)

| Area | Files |
|------|--------|
| Identity / contracts | `00-identity.md`, `api.md`, `lockdown.md`, `MASON-ARCHITECT-HANDOFF.md` |
| Phases 1–8 | `01` … `08-*` |
| Options / chrome (non-raise) | `09-aceconfig.md`, `09c-options-layout.md`, `09b` / `09d` / `09e` / `09f` / `09h` / `09i` (**raise/undim Acceptance struck** — see banners in those files) |
| Source panels SoT | **`09ab`**, **`09aa`** |
| Process | `review-gates-kb.md`, `qa-kb-source-panels.md` |

## Archived kb-chase (not SoT)

Moved to `archive/kb-chase/`:

`09g`, `09j`, `09k`, `09l`, `09m`, `09n`, `09o`, `09p`, `09q`, `09r`, `09s`, `09t`, `09u`, `09v`, `09w`, `09x`, `09y`, `09z`

Durable rules from `09w`/`09x`/`09y`/`09z`/`09r` were folded into **09aa** (+ painter rules in **09ab**) before archive.

## Frozen product decisions (remediation Track A)

- **Veil dim:** accept current bind-mode veil dim. No Raise undim; no cutouts unless a later product SPEC asks.
- **Layouts:** profile-owned (`db.profile.views` / 09i). Character-scoped layout wording in older SPECs is historical.

## Handoff tip

See `MASON-ARCHITECT-HANDOFF.md` — Landed **09ab** (+ **09aa** guards) on `main`. Next SPECs must not reopen Blizzard raise.
