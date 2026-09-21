# GearDisplay - World of Warcraft Addon

**GearDisplay** adds a clean, native-styled button to your Character Sheet that displays all of your equipped gear tooltips simultaneously surrounding your character frame.

---

## Features

- **One-Click Showcase:** Click the **"Show Gear"** button on your Character Sheet (or type `/gd`) to immediately see all equipped items displayed around your character.
- **Full Item Tooltip Fidelity:** Shows the complete, authentic hover info for every item:
  - Base stats & primary attributes
  - Current item level & quality color borders
  - Actual enchants & socketed gems
  - Current durability and repair status
  - Soulbound / equip status
  - Set bonuses and proc / on-use descriptions
- **Smart Symmetrical Layout:**
  - **Left Side:** 2 columns featuring your upper armor & accessories (Head, Neck, Shoulders, Back, Chest, Wrist).
  - **Right Side:** 2 columns featuring your lower armor & jewelry (Hands, Waist, Legs, Feet, Rings, Trinkets).
  - **Bottom Row:** Weapons, off-hands, shields, and ranged relics centered right below your character model.
- **Bi-Directional Hover Highlighting:**
  - Hovering a slot on your character sheet lights up the corresponding surrounding tooltip with a bright gold glow.
  - Hovering a tooltip lights up the corresponding equipment slot button on your character sheet.
- **Live Updates:** Changes to your gear (swapping weapons, equipping new drops, changing specs) update the surrounding tooltips in real-time.
- **Smart Auto-Centering:** When activated, automatically centers your character sheet so tooltips have plenty of room on both the left and right screen margins, and snaps it right back when closed or toggled off.
- **Header Summary Bar:** Displays a sleek header banner above your character sheet with:
  - Total equipped items (e.g. `16/16`)
  - Average Item Level (e.g. `68.4`)
  - Overall gear durability percentage (color-coded green/yellow/red)
- **Interactive Controls:**
  - **Shift-Click** any tooltip to insert its item link into your chat box.
  - **Ctrl-Click** any tooltip to preview the item in the Dressing Room.
- **Inspect Support:** When inspecting other players (`InspectFrame`), the "Show Gear" button appears on the inspect window to showcase their full gear setup as well!
- **In-Game Settings Window:** Fully customizable tooltip scale (60% to 120%), layout modes (Compact Grid or Single Column), quality borders, cosmetic slots, and auto-centering.

---

## Slash Commands

| Command | Action |
|---|---|
| `/gd` or `/geardisplay` | Toggle Gear Display on/off |
| `/gd config` or `/gd options` | Open the Graphical Settings Window |
| `/gd scale <0.6 - 1.2>` | Set tooltip scale (e.g. `/gd scale 0.9` or `/gd scale 0.85`) |
| `/gd autocenter` | Toggle auto-centering of Character Frame |
| `/gd quality` | Toggle rarity color borders on tooltips |
| `/gd layout` | Switch between Compact Grid and Single Column modes |
| `/gd reset` | Reset all settings to default |

---

## Compatibility

- **Classic Beta (Camelot / Build 16001)**
- **Classic Era & Season of Discovery (1.15.x)**
- **Cataclysm Classic (4.4.x)**
- **Wrath of the Lich King Classic (3.4.x)**
- **Modern / The War Within (11.x)**
