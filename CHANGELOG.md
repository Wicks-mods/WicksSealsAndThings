# Wick's Seals and Things - Changelog

## 0.9.0

One version across the suite for the Forever beta. Every addon carries the
same number so the suite goes to 1.0.0 together at launch. Nothing changed
from 0.1.0 beyond the number.

## 0.1.0 - 2026-10-03

First build. The paladin kit for World of Warcraft: Forever.

- Seal strip: a key per seal you know, Judgement, the seal cycle, which
  seal and aura are up, and the two weapon swap keys in one 30px row.
  The seal on you is lit. Seals, blessings and auras are read from the
  spellbook rather than from a Classic list.
- Judgement key with the fighting seal as its fallback line: a press
  with no seal on you puts one on, a press while Judgement is on
  cooldown recasts it. `/wsl seal <name>` chooses the seal, `/wsl
  reseal off` judges alone.
- Seal cycle key: Seal of the Crusader, judge it, then the fighting seal
  for the thirty seconds that judgement lasts, one step per press, as a
  castsequence. `/wsl seal <name>` chooses the
  fighting seal, `/wsl cycle` sets your own steps.
- Blessing key: your blessing on a friendly target, or on you with none.
  Follows the blessing on you; `/wsl bless <name>` chooses one.
- Weapon swap keys: two-hander, and one-hander with shield. They
  remember what you last wore, name pieces by item id, and fall back to
  the best piece carried. `/wsl pin` chooses by hand.
- Pre-pull checklist: seal, blessing, aura, Symbols of Kings, Symbol of
  Divinity, and Righteous Fury when you say you tank.
- Talents, racials and a cooldown bar through WickCore, the same as
  every other kit.
