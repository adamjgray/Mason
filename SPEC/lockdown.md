# Mason lockdown matrix

If `InCombatLockdown()` is true:

| Action | Policy |
|---|---|
| CreateFrame (secure) | Forbidden now; QueueIfCombat |
| SetAttribute | Forbidden now; queue |
| SetOverrideBindingClick / ClearOverrideBindings | Forbidden now; queue |
| RegisterStateDriver | Forbidden now; queue (later phases) |
| SetPoint on executor | Avoid; queue if it is a protected frame |
| print / toast / SavedVariables write | Allowed |
| Hide/Show/SetAlpha on non-protected art (later views) | Prefer state drivers later; Phase 1 executors stay hidden |
| Reading GetSpellInfo / CVar | Allowed |

Owner frame for overrides: one frame, clear-then-reapply as a single queued function, not per-key calls from combat.
