# Mason public API

Architect-owned list. Implementers append only what Phase 1 spec requires.

## Phase 1

```
Mason:QueueIfCombat(fn)
Mason:GetCurrentSpecID()
Mason:GetKit(specID?)
Mason:CreatePiece(fields)
Mason:SetPieceKey(id, key)
Mason:ClearPieceKey(id)
Mason:DeletePiece(id)
Mason:ApplyOverrides()
```

Slash: `/mason`, `/mason bind`, `/mason unbind`, `/mason list`, `/mason clear`, `/mason debug`.
