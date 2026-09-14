# Mason public API

Architect-owned. Implementers add only what the current phase spec lists.

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
Mason:Notify(msg)
```

Slash: `/mason`, `/mason bind`, `/mason unbind`, `/mason list`, `/mason clear`, `/mason debug`.

## Phase 2

```
Mason:PlaceView(id, x, y)
Mason:ClearView(id)
Mason:ApplyLayout()
Mason:SetLocked(bool)
Mason:IsLocked()
```

Slash: `/mason lock`, `/mason hide <key|id>`.
