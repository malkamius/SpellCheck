# SpellCheck

SpellCheck is a powerful utility addon for World of Warcraft that helps you keep your action bars clean, updated, and optimized. It automatically scans your action bars and spellbook to identify downranked spells and any max-level abilities you've forgotten to bind.

## Features

- **Downranked Spell Detection:** Automatically scans your active action bars and warns you if you are using a lower-ranked version of a spell when a higher rank is available in your spellbook.
- **Unbound Spell Tracking:** Identifies max-level spells that you have learned but have not yet placed on any of your action bars.
- **Smart Stance & Form Filtering:** Intelligently filters your unbound spells based on your current state. If a spell requires a specific stance or form (like a Druid's Bear Form or a Warrior's Battle Stance) and you are not currently in it, SpellCheck will hide it from the unbound list to reduce clutter. The UI updates dynamically the moment you shapeshift!
- **Reagent & Ammo Intelligence:** Despite the strict stance filtering, SpellCheck maintains a comprehensive whitelist of reagent- and ammo-dependent skills (like portals, buffs, hunter shots, and soul shard abilities). These will *always* show up as unbound if they aren't on your bars, ensuring they don't vanish just because you ran out of an item.
- **Macro Support:** SpellCheck scans the contents of your macros to accurately identify which ranks of spells you have bound inside them.
- **Addon Compartment Integration:** Easily toggle the interface from the minimap Addon Compartment menu on supported clients.

## Usage

SpellCheck works silently in the background and updates dynamically as you change your action bars, learn new spells, or change stances.

### Slash Commands

- `/sc` or `/spellcheck` - Toggles the main SpellCheck UI pane.
- `/sc minimap` - Toggles the visibility of the SpellCheck minimap icon.

## Installation

1. Download the latest version of the addon.
2. Extract the `SpellCheck` folder into your World of Warcraft `_classic_/Interface/AddOns/` or `_retail_/Interface/AddOns/` directory depending on your client version.
3. Enable **SpellCheck** in your addon list when logging in.
