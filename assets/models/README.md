# 3D models

## Playable character models and animation

- Main and Joris use MakeHuman anatomy, clothing and textures exported through the [Ara 3D Gen CLI](https://github.com/olatunde85/3d-gen). Main uses the Getaway Driver preset with uncovered hair and Joris uses Detective. The new city worker comes from Road Worker. The assets are CC0.
- The GLBs use embedded Ara 3D Gen clips for locomotion, punch, pistol and carbine recoil, vault, swimming, vehicle entry and a pedestrian get-up. Some clips, including the walks and run, are retargeted from the Carnegie Mellon Graphics Lab Motion Capture Database. The export notice is in [characters/LICENSE.txt](characters/LICENSE.txt). `tools/prepare_character_glb.mjs` aligns the embedded bone and clip names with the game. The original gameplay actor code supplies collisions, movement speed and animation timing.

## Other tevy assets

The following models are by [tevy](https://tevy.dev/) and are distributed under [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/).

- [Five-Door Hatchback](https://tevy.dev/models/hatchback), v1 LOD0. The game recolors the paint and mounts the model’s wheels and door to its suspension and entry controller.
- [Family Sedan](https://tevy.dev/models/family-sedan) and [High-Roof Delivery Van](https://tevy.dev/models/delivery-van), v1 LOD1. The game uses the separate wheels, original material colors and distinct chassis dimensions and mass. For Compatibility, the geometry was decompressed and the web-specific KTX2 textures were omitted.
- [Mid-Engine Supercar](https://tevy.dev/models/supercar), v2 LOD2. The coupe uses its separate doors, cabin, steering wheel and road wheels. Mesh compression was expanded for Godot and the web-only texture maps were removed.
- [Casual Walker](https://tevy.dev/models/casual-walker), v1 LOD0. The model supplies a rigged mesh and authored idle and walk animations.
- [Dog Walker](https://tevy.dev/models/dog-walker), v1 LOD0. Its animated character model remains in the pedestrian roster.
- [Mid-Engine Supercar](https://tevy.dev/models/supercar), v2 LOD2. The coupe uses its separate doors, cabin, steering wheel and road wheels. Mesh compression was expanded for Godot and the web-only texture maps were removed.
- [Casual Walker](https://tevy.dev/models/casual-walker) and [Hiker](https://tevy.dev/models/hiker), v1 LOD1. These rigged meshes provide the walking pedestrians.
- [Aspen](https://tevy.dev/models/aspen), LOD2. The city groups its branch, leaf, and trunk meshes into tile-local instances.

Meshopt-compressed sections were expanded and normalized accessors converted to 32-bit floats for Godot's importer. These GLB files are loaded locally.

- [Cherry Blossom Tree](https://tevy.dev/models/cherry-blossom-tree), v1 LOD2, supplies the spring cherry grove in Senjorų Park. The geometry was decompressed for Godot.

## Added vehicle, building and grocery models

- **RGSDEV, Free Low Poly Vehicles Pack, CC0.** The Police Sedan supplies the patrol exterior and road wheels. The prototype adds an opening door and a green-and-white POLICIJA livery. The civilian exteriors and interiors currently use the tevy models above. [Publisher download and license](https://opengameart.org/content/free-low-poly-vehicles-pack)
- **Quaternius, Ultimate Textured Building Pack, CC0.** The gabled house, two-storey balcony and small three-storey exteriors are fitted to selected mapped rectangles. [Publisher download and license](https://opengameart.org/content/lowpoly-buildings-pack)
- **Kenney, Food Kit, CC0.** The food and package meshes are scaled to the store shelves and given gameplay collision when thrown. The phone, vape, construction toy package and training pistol are original placeholder props. [Publisher download and license](https://opengameart.org/content/food-kit)
