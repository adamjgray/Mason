# Mason

Retail World of Warcraft addon (Midnight / 12.x). An **additive** action layer: you place **pieces**, not bars.

Working title and slash: **Mason** / `/mason`. A possible public name later is Speakeasy. The folder and TOC stay `Mason` until that rename is an explicit release decision.

Requires a Midnight client (`Interface` 120100). Classic and older Retail are not supported.

## Why

Default (and most bar addons) start with *N* grids and ask you to hide empty slots. Mason starts empty. If you want a button, you drag a spell, item, macro, toy, or flyout onto the UI. That drop creates a **piece**: one secure executor, an optional on-screen face, an optional key, and layout data.

- **Binds follow specialization.**
- **Layout follows the AceDB profile** (`db.profile.views` — 09i). Switching profiles loads binds and layout together.
- Default bars stay visible in v1. Mason coexists; it does not hide Blizzard bars.

## What a piece is

| Layer | Role |
|---|---|
| Executor `MasonExec_<id>` | `SecureActionButton` / LibActionButton face. Click and key both cast. |
| Key | `SetOverrideBindingClick` on `MasonBindOwner`. Stealing a key toasts what was unbound. |
| View | Position, size in pixels, dock, visibility rule. Saved on the AceDB **profile** (`db.profile.views`). |
| Face | Cooldown swipe/numbers, charges or item stacks, OOR/OOM, hotkey text, tooltips, optional Masque group `Mason`. |

Pieces are created from the cursor (`GetCursorInfo`: spell, item, macro, flyout). Combat-sensitive work is queued (`QueueIfCombat`) and applied on regen.

## Features (current tree)

**Placement and edit mode**

- Drop onto empty UI while out of combat to create or move the current-spec piece.
- `/mason lock` toggles edit mode (default **locked** on login).
- Unlocked: dim veil + grid, drag without casting, right-click or × hides the view (kit and key stay).
- Combat force-locks. You cannot unlock in combat.
- `/mason snap`, `/mason grid <8-128>`, centered grid. Snap is 9-point on the piece box; it does not change piece size.
- Select, Shift-select, arrow nudge (1px; Shift+arrow snaps to the next grid line), `/mason align`, mouse-wheel size, dock courses with a green edge hint.

**Binds and bind mode**

- `/mason bind`, `/mason unbind`, `/mason list`, `/mason hide` / `show`.
- `/mason kb` — hover a source cell (macros are the reference path) and press a key. Overlay text is `piece.key` for that cell’s **identity** (spellID / itemID / toyID / macro name), never a slot index.

**Rules and flyouts**

- `/mason rule <token> <preset|clear>` with presets: `always`, `combat`, `ooc`, `target`, `harm`, `help`, `stealth`.
- Mason course flyouts (up to 12 children, one open, no nesting).
- Blizzard flyouts (Warband, portals, skyriding, …) drop as a parent plus course children. Native `SpellFlyout` is not used for the popup (taint).

**Not in v1**

- Hiding default action bars.
- Cooldown Manager integration.
- A full AceConfig “theme studio.”
- Classic / Era / SoD.

## Install

1. Clone or copy this repository so the **addon folder** is named `Mason` and contains `Mason.toc`.

   ```
   Interface/AddOns/Mason/Mason.toc
   Interface/AddOns/Mason/Mason.lua
   ```

   If you develop from `src/Mason`, junction or copy the inner `Mason/` folder into `Interface/AddOns/Mason`. Do not junction the outer repo root if that root is only a git wrapper.

2. Enable **Mason** on the character select addon list. Optional: **Masque** for the `Mason` skin group.

3. `/reload`. `/mason` should print usage. `/mason bind Fireball Q` (use a spell you know) should toast and cast on Q with no icon until you drop the spell onto the UI.

Embedded: Ace3 (Addon, DB, Console), LibStub, CallbackHandler, LibActionButton-1.0. Masque is optional and not vendored.

## Slash

| Command | What it does |
|---|---|
| `/mason` | Usage |
| `/mason lock` | Toggle edit mode |
| `/mason kb` | Bind mode (source UI hover + key) |
| `/mason bind <spell\|token> <key>` | Override bind |
| `/mason unbind <token>` | Clear that key |
| `/mason list` | Pieces in the current spec kit |
| `/mason hide` / `show <key\|id\|name>` | Crate or restore a view |
| `/mason grid <8-128>` | Grid spacing (placement only) |
| `/mason snap` | Toggle snap |
| `/mason size [token] [px\|reset]` | Default or per-piece size |
| `/mason align left\|right\|top\|bottom\|hcenter\|vcenter` | Align selection to last-clicked |
| `/mason undock [token]` | Clear dock |
| `/mason rule <token> <preset\|clear>` | State driver |
| `/mason rules` | List presets |
| `/mason flyout …` | Course flyout add/remove/side/close |
| `/mason debug [token]` | Face / bind diagnostics |
| `/mason clear` | Dangerous: kit clear (see in-game text) |

Notifications use `Mason:Notify` (chat plus `UIErrorsFrame` when present).

## Saved data

AceDB. Kits (piece type, spell/item/macro/flyout id, key) are **per spec** inside the profile. Views (x, y, size, dock, rule, visible) and UI settings (`defaultSize`, `snap`, `gridSize`, `debug`) are **profile-owned** (`db.profile.views`, …). A one-time migration copies legacy `db.char.views` into the current profile when profile views are empty.

Import/export (schema version on the blob; refuse a newer major, migrate an older one) is available via `/mason export` / `/mason import`.

## Development

Retail only. Secure attributes and override binds must stay on the combat-safe path. Do not use `SetBinding` or action slots for Mason keys. Do not `Show` secure frames in combat from insecure code.

Layout math is in `UIParent` space. Piece size is stored in **pixels** (`views[id].size`, default `db.char.defaultSize`). `/mason grid` must not change piece size.

**Bind mode / source panels** — SoT is `SPEC/09ab-source-panels-no-raise.md` + `SPEC/09aa-crash-guards.md`:

- Hotkey **display** is always-on from binding store data (not gated on `/mason kb`).
- Veil is dim-only; **do not** undim Blizzard panels via Raise/strata (product: accept current dim).
- No window `GetChildren` walks; no raise from bag `Show`; no item-button raise; no `print` from Blizzard `Show`.
- One store painter: `RepaintSourceHotkeys`. Legacy `Raise*` symbol names are historical (paint/hooks only).
- Review/QA: `SPEC/review-gates-kb.md`, `SPEC/qa-kb-source-panels.md`. Index: `SPEC/README.md`.

Architecture notes and phase specs live in `SPEC/`. `SPEC/MASON-ARCHITECT-HANDOFF.md` is the brief for a manager agent.

### Suggested agent split

- **Manager / coordinator** — writes one spec, reviews diffs, does not implement.
- **Implementer** — applies that spec on this tree.
- **Human** — `/reload` and in-game QA. Cloud agents cannot see the running client.

One concern per spec. Stability before overlays.

## License

Addon code in this repository: see the license file if one is committed; otherwise all rights reserved by the author until a license is added.

Vendored libraries keep their own licenses under `Mason/libs/`.
