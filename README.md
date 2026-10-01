# FS25_CropCalendarSort

A lightweight Farming Simulator 25 quality-of-life mod that adds selectable sorting modes to the **native crop calendar**.

Current development version: **0.3.0.0**

## What it does

Open the standard FS25 crop calendar and use the bottom-bar **SORT: <MODE>** action. Crop Calendar Sort opens the stock FS25 option dialog and immediately reorders the calendar when you choose a mode.

The selected mode is stored under:

`modSettings/FS25_CropCalendarSort/settings.xml`

That makes the sort order a player UI preference rather than savegame state.

## Sort modes

### Reference sorts

- **Native Order** — restores the ordering supplied by the game/map.
- **Alphabetical A-Z** — sorts every entry by its displayed/localised crop name.
- **Plantable A-Z** — crops with `allowsSeeding == true` first A-Z, then remaining entries A-Z.
- **Planting Start** — earliest annual planting period first, then A-Z.
- **Harvest Start** — earliest annual harvest period first, then A-Z.

### Gameplay sorts

- **Plant Now** — crops plantable in the current seasonal period first, A-Z within each group.
- **Harvest Now** — crops harvestable in the current seasonal period first, A-Z within each group.
- **Next Planting** — nearest planting opportunity from the current period first, wrapping through the 12-period year.
- **Next Harvest** — nearest harvest opportunity from the current period first, also wrapping through the year.

If FS25 or a custom map does not expose a usable current seasonal period, the gameplay-oriented modes safely fall back to A-Z.

## Scope

Crop Calendar Sort changes **presentation order only**. It does not modify:

- crop definitions;
- planting or harvesting windows;
- growth states;
- fruit-type registration;
- fields;
- contracts;
- savegame crop data.

## Compatibility/API

The mod exposes `CropCalendarSortAPI` v1 so another mod can deliberately reuse the sorting engine instead of competing with the native-calendar hook.

Available API calls:

- `getMode()`
- `setMode(modeId, frame)`
- `sortFruitTypes(fruitTypes, modeId)`
- `getModes()`

This is intended to support integration with **Crop Control Override** while keeping Crop Calendar Sort useful as a standalone mod.

## Development

The current 0.3.0.0 build includes all nine sort modes, persistent preferences, native calendar integration, and the stock FS25 `OptionDialog` selector.

Debug builds log with:

`[FS25_CropCalendarSort]`

## Building and releases

GitHub Actions validates the source and creates:

`FS25_CropCalendarSort.zip`

on pushes and pull requests.

To publish a GitHub release, create and push a version tag matching `modDesc.xml`, for example:

`v0.3.0.0`

The release workflow validates that the tag, `modDesc.xml` version and `CCS.VERSION` all agree before publishing the ZIP.
