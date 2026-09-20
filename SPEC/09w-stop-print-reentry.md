# Mason 9w — Stop print re-entry

The 9v `print("Mason: live …")` calls from bag/book Show recurse through chat `AddMessage` and `ContainerFrame_GenerateFrame` → C stack overflow.

Do not add painters. Do not edit macros except if a print was added there — remove it.

## End goal

`/mason kb` + bags + book + toys: **no** C stack overflow, **no** `8x C stack overflow`. Binding UI still works as before 9v (macros still perfect).

## Fix

1. Delete every `print("Mason: live` / `print('Mason: live` added in 9v.
2. Do not print from bag Show, item OnShow, ContainerFrame generate, SpellBook OnShow, or ToyBox OnShow.
3. If you still need a probe: set `self._live[fn] = true` once, and print **once** from a later insecure tick (`C_Timer.After(0, …)`), never from Show.
4. Preferred: no prints at all this pass. Restore pre-9v behavior.

## Done when

Reload → `/mason kb` → open bags, book, macros, toys — no stack overflow. Macros still work.
