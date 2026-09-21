# Mason — implementer contract

You implement one SPEC phase per session. You do not change product decisions.

Read-only: SPEC/00-identity.md, the phase spec named by the user, SPEC/api.md, SPEC/lockdown.md, this file. For BindMode / source panels, the named SoT is SPEC/09ab-source-panels-no-raise.md and SPEC/09aa-crash-guards.md (see SPEC/README.md). Archived chase SPECs under SPEC/archive/ are not requirements.

Rules:
- Retail WoW 12.x only. No Classic.
- Loadable code only under Mason/
- Do not write Blizzard action slots to build the kit, and do not integrate CDM or Edit Mode. Pickup-to-bar crate detection per SPEC/03c is allowed.
- No CreateFrame, SetAttribute, SetOverrideBinding*, RegisterStateDriver in combat (see SPEC/lockdown.md for secure vs insecure UI notes).
- Public functions added this phase must match SPEC/api.md.
- If SPEC is silent, stop and ask. Do not invent features.
- Nouns: kit, piece, layout. Product name: Mason. Slash: /mason.
