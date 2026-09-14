# Mason lockdown matrix

If `InCombatLockdown()` is true:

| Action | Policy |
|---|---|
| CreateFrame (secure) | Forbidden now; QueueIfCombat |
| SetAttribute | Forbidden now; queue |
| SetOverrideBindingClick / ClearOverrideBindings | Forbidden now; queue |
| RegisterStateDriver | Forbidden now; queue (later phases) |
| SetPoint / Show / Hide / EnableMouse on executor | Forbidden now; queue |
| Drop catcher EnableMouse / Show | Allowed (not protected) |
| Writing db.char.views | Allowed |
| print / toast / SavedVariables write | Allowed |
| Reading GetSpellInfo / CVar | Allowed |

Owner frame for overrides: one frame, clear-then-reapply as a single queued function, not per-key calls from combat.
