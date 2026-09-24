# GearDisplay - World of Warcraft Addon

**GearDisplay** seamlessly integrates a dedicated tab into your Character Sheet that displays all of your equipped gear tooltips simultaneously surrounding your character model.

---

## Features

- **Native Character Sheet Tab:**
  - **Modern & Camelot Clients:** Integrated as a native sidebar icon tab directly alongside Blizzard's Character Stats, Equipment Manager, and Pet tabs. Automatically anchors to the right of the visible tabs and synchronizes its active/selected gold border.
  - **Classic Era Clients:** Automatically adds an integrated bottom tab (`CharacterFrameTab4`) to the Character Frame.
  - **Clean Tab Navigation:** Fully synchronized with native tabs—clicking Character Stats, Equipment Manager, or Pet automatically hides GearDisplay and surrounding tooltips. Clicking the GearDisplay tab toggles between gear display mode and your stats pane.
- **Embedded, Centered Options Pane:**
  - Directly embedded in the Character Sheet sidebar area without floating window clutter or unnecessary scrollbars.
  - **Layout Mode Toggle:** Switch seamlessly between **Compact Grid** and **Single Column** modes with widened, easy-to-click buttons.
  - **Tooltip Scale Slider:** Fine-tune gear tooltip dimensions from 60% to 120% with real-time percentage feedback.
  - **Preference Checkboxes:** Centered, vertically aligned toggles for:
    - *Auto-Center Character Sheet*
    - *Item Quality Borders*
    - *Show Shirt & Tabard*
    - *Suppress Slot Hover*
  - **Reset Defaults:** One-click restoration of all addon settings.
- **Full Item Tooltip Fidelity:**
  - Authentic, complete hover information for every equipped slot:
    - Base stats & primary attributes
    - Current item level & quality-colored borders
    - Socketed gems & enchantments
    - Current durability and repair status
    - Soulbound / equip binding status
    - Set bonuses and proc / on-use descriptions
- **Target Inspect Support:**
  - Inspect any player and click the native **"Show Gear"** button on the `InspectFrame` to display their complete gear layout with full tooltip fidelity.
  - Automatically updates as inspected item details stream from the server.
- **Dual Symmetrical Layouts:**
  - **Compact Grid Mode (Default):**
    - *Left Side:* 2 columns featuring upper armor & accessories (Head, Neck, Shoulders, Back, Chest, Wrist).
    - *Right Side:* 2 columns featuring lower armor & jewelry (Hands, Waist, Legs, Feet, Rings, Trinkets).
    - *Bottom Row:* Weapons, off-hands, shields, and ranged relics centered directly below your character model.
  - **Single Column Mode:**
    - Clean single-column layout flanking each side of the Character Sheet, ideal for narrower displays or ultra-wide setups.
- **Bi-Directional Hover Highlighting:**
  - Hovering a slot button on your character sheet illuminates the corresponding surrounding tooltip with a bright gold glow.
  - Hovering a surrounding gear tooltip illuminates the corresponding equipment slot button on the character sheet.
  - *Suppress Slot Hover* option hides redundant default slot tooltips while GearDisplay is open to prevent visual clutter.
- **Interactive Controls:**
  - **Shift + Click** any gear tooltip to instantly insert its item link into chat.
  - **Ctrl + Click** any gear tooltip to preview the item in the Dressing Room.
- **Live Updates:**
  - Real-time updates when equipping items, swapping weapons, changing specs, or receiving item data from the server.
- **Smart Auto-Centering (Zero Taint):**
  - Centers your Character Sheet on the screen so all flanking tooltips fit comfortably on both left and right margins, and snaps it cleanly back when closed or toggled off.
- **Zero-Taint Architecture:**
  - Engineered without modifying protected Blizzard UI tables (`PAPERDOLL_SIDEBARS`, `CharacterFrameMixin`, etc.), preventing execution taint and status bar UI errors.

---

## Slash Commands

| Command | Action |
|---|---|
| `/gd` or `/geardisplay` | Toggle Gear Display tab / showcase |
| `/gd config` or `/gd options` | Open the Graphical Settings Window |
| `/gd scale <0.6 - 1.2>` | Set tooltip scale (e.g., `/gd scale 0.85` or `/gd scale 1.0`) |
| `/gd autocenter` | Toggle auto-centering of Character Frame |
| `/gd quality` | Toggle rarity color borders on tooltips |
| `/gd layout` | Switch between Compact Grid and Single Column modes |
| `/gd reset` | Reset all settings to default |

---

## Compatibility

- **Classic Beta (Camelot / Build 16001)**
- **Modern / The War Within (11.x)**
- **Classic Era & Season of Discovery (1.15.x)**
- **Cataclysm Classic (4.4.x)**
- **Wrath of the Lich King Classic (3.4.x)**
- **Dragonflight (10.x)**
