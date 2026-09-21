# Mason 9b — Edit slash, bind dim, ghosts UI, config chrome

Do not change scale host, flyout populate, or dock candidate rules.

> **Supersession (source panels):** §2 “Raise those frames above the veil” / Acceptance #2 “stay undimmed” are **superseded by [`09ab`](09ab-source-panels-no-raise.md) + [`09aa`](09aa-crash-guards.md)**. Do **not** Raise Blizzard chrome to undim. Veil is dim-only; product accepts current dim. Keep `/mason edit`, ghosts, and config chrome Acceptance.

## 1. `/mason edit`

- `/mason edit` toggles edit mode (what `/mason lock` does now).
- Notify `edit on` / `edit off` (or keep locked/unlocked if that is already what testers see — pick one pair and use it everywhere).
- `/mason lock` remains as an **alias** for one beta cycle.
- Edit panel primary button label: **Done** (exits edit). Cancel unchanged.

## 2. Bind-mode dim

~~While `/mason kb` is on: Raise spellbook/bags/macros above the veil.~~ **Superseded by 09ab** — veil dim-only; zero Blizzard strata mutation; hotkeys always-on from store.

Historical intent (kept for context only):

- Show a dim veil (same family as edit veil) **under** bindable UI.
- Veil `EnableMouse(false)` always.
- Gold hover outline on the current bind target stays.
- Exit kb: hide veil.

Do **not** implement the struck “raise Blizzard frames above veil” / “stay undimmed” clauses.

## 3. Ghosts in AceConfig

New **Ghosts** tab (or a group under Layout):

- Rows for every `views[id]` that `/mason debug ghosts` would print.
- Each row: icon (spell/item/flyout/macro), `id`, type + name.
- Button **Clear view** on the row — deletes that `views[id]` only (does not unbind the kit piece if it still exists).
- Button **Clear all ghosts** — all leftover views.
- Empty state: `No leftover views.`

Keep `/mason debug ghosts` as the slash dump.

## 4. Config window chrome

AceConfigDialog stock look is wrong next to Mason edit/bind panels.

After `AceConfigDialog:Open("Mason")` (and on refresh):

- Apply the same backdrop as MasonBindPanel (gold-edge, same bg, padding, title font).
- Title **Mason**.
- Close button same template as Done on the bind panel.

If AceConfigDialog cannot be skinned cleanly, host the AceGUI tree inside a Mason dialog frame (copy BindPanel chrome) instead of the default Ace dialog. Do not rewrite the option table.

## Acceptance

1. `/mason edit` toggles the grid; `/mason lock` still works.
2. `/mason kb` shows a dim veil (`EnableMouse(false)`). Blizzard panels are **not** Raise-undimmed (09ab). Store hotkeys + hover-bind still work; gray-under-dim is accepted.
3. Ghosts tab shows leftover views with icon + id + name; Clear view removes one.
4. Config window matches edit/bind panels.
