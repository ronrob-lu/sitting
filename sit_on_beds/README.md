# Sit on Beds Mod

A Luanti/Minetest mod that allows players to sit on beds (or any registered bed-like object) during daytime.

## Features

- Sit on beds during daytime without sleeping
- Full 360-degree rotation while sitting
- Look around freely while seated
- Compatible with any object registered as a bed
- Easy to extend for other sit-able objects

## Usage

1. Install the mod in your `mods` directory
2. Enable the mod in your world's `world.mt` file or through the game menu
3. Right-click on a bed during daytime to sit on it
4. Press sneak (default: Shift) or right-click again to stand up
5. Use mouse to look around while sitting

## Configuration

The mod automatically detects beds registered with the `beds` mod or objects with the `bed` group.

To register custom objects as sit-able beds, add them to the `bed` group:

```lua
minetest.register_node("mymod:custom_bed", {
    -- your node definition
    groups = {bed = 1},
})
```

## Requirements

- Minetest/Luanti 5.0+
- Optional: `beds` mod for default bed functionality

## License

MIT License - See LICENSE.md for details

## Author

ronrob-lu
