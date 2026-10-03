# Wick's Seals and Things

The paladin kit for **World of Warcraft: Forever**, built on
[WickCore](https://github.com/Wicksmods/WickCore).

A paladin's loadout is a seal, a blessing, an aura and the weapon in
hand, and half the fight is keeping the first one on and the last one
right. This kit puts every seal you know in a row, lights the one that
is on you, puts the Crusader opener on one key, and gives you two keys
to swap between your two-hander and your shield.

## What it does

**Seal strip.** One 30px row: a key per seal you know, Judgement, the
seal cycle, a blessing key, two lines saying which seal and aura are up,
and the two weapon swap keys. The seal that is on you is ringed in fel green.
Shift-drag moves it even when locked.

Nothing on the strip is a list written down from Classic. Which seals,
blessings and auras exist comes from your spellbook, so a seal Forever
renames or retunes shows up as itself.

**Judgement.** A plain key. On Forever a judgement leaves the seal on
you, so there is nothing to put back.

**Seal cycle.** The seal dance on one key, the way Totems and Things
twists totems: Seal of the Crusader, judge it onto the target, then
Seal of Righteousness for the thirty seconds that judgement lasts, and
the next press starts over. One step per press, resetting on a new
target or after thirty quiet seconds. The fighting seal follows the one you had on, or the one
you name with `/wsl seal <name>`. `/wsl cycle <spell, spell, ...>` sets your own steps,
`/wsl cycle reset <seconds>` the quiet time, `/wsl cycle off` removes
it.

**Blessing key.** Casts your blessing on a friendly target, or on you
with none. It follows the blessing that is on you, or the one you name
with `/wsl bless <name>`; a Greater Blessing works if that is what you
name. Lit while that blessing is on you.

**Weapon swap keys.** Two keys, tied to nothing. One puts your
two-hander in your hands, the other your one-hander and shield. They
remember what you last wore, so a new weapon needs nothing done to it
beyond putting it on once, and they name every piece by item id so two
maces called the same thing cannot pick the wrong one. With nothing
remembered they take the best piece you carry; `/wsl pin 2h` with an
item link makes a key reach for one piece and no other. Each macro
names where the set should end up rather than describing a move, so
pressing a key twice does nothing the second time. The strip shows the
piece each key puts on, with a mark on the set you are already wearing.

Worth knowing before you bind them: swapping resets your swing timer.

**Pre-pull checklist.** A seal on, a blessing on you, an aura up,
Symbols of Kings once you know a Greater Blessing, a Symbol of Divinity
once you know Divine Intervention, and Righteous Fury when you say you
tank (`/wsl fury on`). Read out of combat, from your own auras and bags.

**Talents, racials and a cooldown bar** through WickCore, the same as
every other kit.

## Commands

| | |
|---|---|
| `/wsl` | show or hide the seal strip |
| `/wsl kit` | talents and the pre-pull checklist |
| `/wsl seal <name>` | the seal the cycle ends on; `auto` follows what you had on |
| `/wsl bless <name>` | the blessing key's spell; `auto` follows what you had on |
| `/wsl cycle ...` | the cycle key's steps, `auto`, `off`, or `reset <seconds>` |
| `/wsl swap on|off` | keep the swap keys loaded |
| `/wsl pin <2h|1h|shield> [link|clear]` | choose a piece by hand |
| `/wsl fury on|off` | Righteous Fury on the checklist |
| `/wsl lock` / `/wsl unlock` | the strip's position |
| `/wsl cd` | the cooldown bar |
| `/wsl options` | everything above, with switches |
| `/wsl status` | what the kit can see, and what each key will do |

Every key on the strip is also bindable under Key Bindings, Wick's
Seals and Things.

## Why it is not a combat tracker

Forever's addon rules make health, power and most combat state secret,
and withhold your auras while you fight. Everything this kit reads is
readable out of combat, and nothing of Blizzard's is written to. While
the client withholds auras the strip keeps showing the last thing it
knew rather than going blank. The keys are secure buttons whose text is
written out of combat; pressed mid-fight they do what they were last
told, which is the right answer since a seal is a seal.

## The suite

Wick's Bags, Wick's Comforts, Wick's Gear, and one kit per class: Seals
(paladin), Stances (warrior), Totems (shaman), Demons (warlock), Forms
(druid), Beasts (hunter), Poisons (rogue), Conjures (mage).
<https://wicksmods.com>

## Compatibility

World of Warcraft: Forever, 1.60.x, Interface 16001. Requires WickCore.

## License

MIT for code (see [LICENSE](LICENSE)). Brand chrome and the "Wick's" wordmark are trademarked, see [TRADEMARK.md](https://github.com/Wicksmods/WickSuite/blob/main/TRADEMARK.md). Racial data from [talentsforever.com](https://talentsforever.com) (CC BY 4.0) via WickCore.
