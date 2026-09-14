# Mason — implementer contract

You implement one SPEC phase per session. You do not change product decisions.

Read-only: SPEC/00-identity.md, the phase spec named by the user, SPEC/api.md, SPEC/lockdown.md, this file.

Rules:
- Retail WoW 12.x only. No Classic.
- Loadable code only under Mason/
- Do not write Blizzard action slots, CDM, or Edit Mode integration.
- No CreateFrame, SetAttribute, SetOverrideBinding*, RegisterStateDriver in combat.
- Public functions added this phase must be listed at the end of the session.
- If SPEC is silent, stop and ask. Do not invent features.
- Nouns: kit, piece, layout. Product name: Mason. Slash: /mason.