# Mason lockdown matrix

If `InCombatLockdown()` is true:

| Action | Policy |
|---|---|
| CreateFrame (**secure** button / secure template) | Forbidden now; `QueueIfCombat` |
| CreateFrame (**insecure** UI: veil, catcher, panels, FontStrings on Mason-owned frames) | Forbidden in practice while lockdown — BindMode Ensure* early-returns on `InCombatLockdown()`; queue paint via `QueueIfCombat` / `RepaintSourceHotkeys` |
| `CreateFontString` / `HookScript` on **Blizzard** cells | Same combat sensitivity as BindMode Ensure*: do not create from combat; prefer OOC install + deferred paint. Accepted taint budget is a product/architecture topic (Track D) — do not “fix” by Raise undim |
| SetAttribute | Forbidden now; queue |
| SetOverrideBindingClick / ClearOverrideBindings | Forbidden now; queue |
| RegisterStateDriver | Forbidden now; queue (Phase 4+ applies OOC via `QueueIfCombat`) |
| SetPoint / Show / Hide / EnableMouse on **executor** | Forbidden now; queue |
| Drop catcher EnableMouse / Show | Allowed (not protected) |
| Bind catcher keyboard / veil Show path | Catcher may exist; do not CreateFrame/SetAttribute in combat. Paint schedules queue |
| Writing `db.profile.views` (layout) | Allowed |
| Writing kit / SavedVariables / print / toast | Allowed |
| Reading GetSpellInfo / CVar | Allowed |

Owner frame for overrides: one frame, clear-then-reapply as a single queued function, not per-key calls from combat.

## AGENTS alignment

- AGENTS bans CreateFrame / SetAttribute / SetOverrideBinding* / RegisterStateDriver **in combat** — matches this matrix (secure and BindMode insecure Ensure* alike).
- **Action slots:** do not write Blizzard action slots to **build the kit**. Locked pickup → default-bar **crate detection** (`03c`) is allowed (read/poll slots; crate Mason view) — not kit-building PlaceAction.
- Source-panel crash guards (`09aa`) and no-raise undim (`09ab`) are orthogonal to lockdown but still apply OOC.
