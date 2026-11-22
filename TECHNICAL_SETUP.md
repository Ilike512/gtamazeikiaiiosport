# Physics and graphics setup

## Raycast vehicles

Open `scenes/vehicles/BasicCar.tscn` and select the root to tune the **Chassis**, **Suspension**, and **Tires** groups in the Inspector. The raycasts use `PhysicsDirectBodyState3D` and each marker's chassis-local position.

```text
BasicCar (RigidBody3D, BasicCar.gd)
├── ChassisCollision (CollisionShape3D)
├── Visuals (Node3D)
│   ├── Cabin model (runtime)
│   ├── Exterior (MeshInstance3D, runtime)
│   ├── DriverDoor (Node3D, runtime)
│   │   └── Door skin (MeshInstance3D, runtime)
│   └── Wheel pivots and replacement meshes (runtime)
└── Suspension (Node3D)
    ├── FrontLeft (Marker3D)
    ├── FrontRight (Marker3D)
    ├── RearLeft (Marker3D)
    └── RearRight (Marker3D)
```

All variants place their suspension markers over the wheel hubs during setup. In `BasicCar.gd`, each variant supplies mass, dimensions, wheel radius, engine force and speed cap. The hatchback, sedan, van and coupe use exterior and interior materials from their GLBs. The patrol sedan uses its own exterior and shares the civilian sedan cabin.

| Inspector property | Default |
| --- | --- |
| Mass multiplier | 1.08 |
| Centre of mass offset | (0, 0.075, 0.05) m |
| Suspension travel | 0.48 m |
| Spring stiffness | 26,500 N/m at 1,480 kg |
| Damper strength | 2,850 N·s/m at 1,480 kg |
| Rebound damping ratio | 1.12 |
| Tire grip | 1.22 |
| Rear grip scale | 1.04 |
| Front peak slip angle | 8° |
| Sliding grip ratio | 0.70 |

The suspension applies forces at each hub and applies tire forces at the road contact. That separation and the raised centre of mass generate pitch under acceleration and braking and roll in corners. Soft springs, rebound damping, and progressive bump stops control the bounce. `TireGrip.gd` shapes lateral grip from slip angle and caps the combined braking, cornering and drive load. The front tires saturate first when coasting into a sharp turn. Rear drive uses some of the rear tires' lateral grip and can swing the rear out under throttle.

## Third-person movement and camera

```text
Player (CharacterBody3D, Player.gd)
├── BodyCapsule (CollisionShape3D)
├── VaultProbe (RayCast3D)
└── Character model, skeleton and AnimationPlayer (runtime)

ChaseCamera (Node3D, driven by Mazeikiai.gd)
└── SpringArm3D (sphere collision shape)
    └── Camera3D
```

The player accelerates toward a target speed instead of immediately replacing velocity. Grounded motion uses Idle, Walk, Jog and Sprint. Sprint limits heading changes through an Inspector setting in `Player.tscn`. The vault probe is cast forward from the feet, then clearance and landing checks determine whether to play a vault or a regular jump. The camera damps its focus and heading, then gently recentres after the mouse or stick has been idle. Near an idle vehicle, the player moves to the driver's door, plays the entry clip and hands input to the rigid body once seated.

`GameManager.KEY_DEFAULTS` declares the editable Input Map actions. Movement uses `move_forward`, `move_left`, `move_back` and `move_right`. `sprint` uses Shift, `jump_brake` uses Space, `dive` uses Ctrl, and `interact` uses E for entry or the horn. `rob` uses F for the foot interaction or vehicle exit. Change them in Settings or in the defaults dictionary.

## Replacing characters and animations

1. Put a rigged Sloyd GLB or Mixamo FBX in `assets/models/characters/` and allow Godot to import it. A static export needs a humanoid skin first. Mixamo offers a humanoid rigger after Adobe sign-in. For separate animation downloads, choose **Without Skin** and **In Place** where the clip offers it. [Adobe Mixamo guide](https://helpx.adobe.com/creative-cloud/help/mixamo-rigging-animation.html)
2. For a different skeleton, set a **Humanoid BoneMap** in Godot’s Advanced Import settings. Retarget the animation source to the same skeleton profile. Save separate clips as an `AnimationLibrary` resource if the actor file does not contain them. The track paths must resolve to the actor scene’s skeleton. [Godot retargeting guide](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html)
3. Edit the appropriate entry in `data/characters.json`. Set its `model` and adjust `model_yaw_degrees` if needed. The movement controller expects lowercase `idle`, `walk` and `run`. Optional separate clips use `animation_library` and `animation_aliases`. Values in the aliases map identify the source clips with their library prefix, such as `custom/Walking`. To inspect the available names, open the imported scene and select its `AnimationPlayer`.

```json
{
  "model": "res://assets/models/characters/replacement.fbx",
  "model_yaw_degrees": 180,
  "animation_library": "res://assets/models/characters/mixamo_clips.tres",
  "animation_aliases": {
    "idle": "custom/Idle",
    "walk": "custom/Walking",
    "run": "custom/Running",
    "punch": "custom/Punch"
  }
}
```

The built-in actors use embedded clips. Embedded replacements can alias names directly, such as `"walk": "Walking"`, and omit `animation_library`. A custom animation set can also supply `leap`, `land`, `vault`, `swim`, `swim_dive`, `tread`, `car_entry` and `get_up`. Current controls drive the actual character position, so use in-place locomotion.

## Articulated character impacts

1. Import a skinned character with an `AnimationPlayer`, a `Skeleton3D` and a walk cycle. The three bundled civilian characters share their bone names. For a different rig, change `BODY_LAYOUT` in `scripts/world/ActiveRagdoll.gd` to list its bone and tip names.
2. In the civilian's ready method, create `ActiveRagdoll.new(self, skeleton, controller)`. Its first impact adds the following nodes to the live skeleton. Inspect them in the Godot editor's **Remote** scene tree during play.
3. Keep the ground on collision layer 1 and vehicle chassis on layer 4. The walking civilian uses layer 8. Physical bones use layer 16 and collide with ground and vehicles.

```text
Civilian (CharacterBody3D, Civilian.gd)
├── Walking capsule (CollisionShape3D)
└── Imported model
    ├── AnimationPlayer
    └── Skeleton3D
        ├── ImpactSimulator (PhysicalBoneSimulator3D)
        │   ├── hips, chest and head (PhysicalBone3D)
        │   ├── upperarm_L/R and forearm_L/R (PhysicalBone3D)
        │   └── thigh_L/R, calf_L/R and foot_L/R (PhysicalBone3D)
        │       └── Each physical bone has a fitted capsule collision
        └── GetUpBlend (SkeletonModifier3D)
```

Capsules align to the rest-pose bone axes. Cone joints limit swing and twist. At moderate impact, the animation pose supplies the brace targets. Angular PD torque works toward those targets, the pelvis uses a bounded positional spring, and the head targets the original upright pose. The stumble gives way to a loose ragdoll when the pelvis leans too far or a stronger impact occurs.

`Civilian.vehicle_impact(strength, direction)` uses the chassis's closing-speed and impulse estimate, with a stumble threshold of 3.8 and a full-fall threshold of 8.8. Once linear and angular velocities settle for 0.32 seconds and the rig has ground beneath it, `GetUpBlend` blends the last simulated pose into a 1.2-second get-up clip. A recovered stumble uses a shorter 0.37-second blend.

References for the nodes and physics callback. [PhysicalBone3D](https://docs.godotengine.org/en/stable/classes/class_physicalbone3d.html) · [PhysicalBoneSimulator3D](https://docs.godotengine.org/en/stable/classes/class_physicalbonesimulator3d.html)

## World environment and color grading

The following settings are created in `scripts/world/MazeikiaiDistrict.gd`. The city uses Godot's Compatibility renderer and updates sky and sun intensity over a 900-second day. The visible horizon blends toward warm gray during daylight and blue-gray at night.

| WorldEnvironment property | Daylight setting |
| --- | --- |
| Background | Panorama sky from `assets/environment/sky.hdr` |
| Panorama energy | 0.98 |
| Ambient source | Color |
| Ambient color and energy | `#ccc5b7` at 0.69 |
| Sky contribution | 0.16 |
| Tonemap | Linear, exposure 0.95, white 5.8 |
| Adjustment | Contrast 1.035 and saturation 0.95 |
| Fog | Exponential, density 0.0025 |
| Height fog | Height −4.0 m, height density 0.032 |
| Fog daylight color and energy | `#a39988` at 0.91 |
| Fog sky affect and sun scatter | 0.18 and 0.21 |

The `DirectionalLight3D` rotates over the day from −78° to 170° on Y and between −5° and −43° on X. Daylight energy peaks at 1.06 with `#ffdfbc` light. Night uses energy 0.15 and `#869cbd`. Angular distance is 0.65°, shadow bias is 0.028, normal bias is 0.66, and Medium and High use 112 m and 185 m shadow distances respectively.

```text
District (Node3D)
├── WorldEnvironment
├── DirectionalLight3D
└── CityPostProcessing (CanvasLayer −1)
    └── CityGrade (fullscreen ColorRect, ShaderMaterial)
```

`assets/environment/CityGrade.gdshader` applies desaturation at 0.79, a warm shadow tint, and a soft highlight bloom using screen mip levels 3.0, 4.8 and 6.1. Its threshold is 0.61 and bloom strength is 0.47 on Medium. The layer sits below the game HUD and menus. This bloom works in Compatibility and is independent of Forward+ glow. [Environment settings](https://docs.godotengine.org/en/stable/classes/class_environment.html) · [Screen-reading shaders](https://docs.godotengine.org/en/stable/tutorials/shaders/screen-reading_shaders.html)

## Graphics controls

`scenes/menus/SettingsMenu.tscn` uses `scripts/ui/SettingsMenu.gd` to build the display and graphics sections. `SettingsManager.gd` applies the controls to the active viewport, light and environment. `GameManager.gd` persists the values and keyboard bindings using `ConfigFile` at `user://settings.cfg`.

| Preset | 3D scale | MSAA | Directional atlas | Shadow distance |
| --- | ---: | --- | ---: | ---: |
| Low | 0.60 | Off | 1024 | Off |
| Medium | 0.78 | Off | 2048 | 112 m |
| High | 0.90 | 2× | 3072 | 185 m |
| Ultra | 1.00 | 4× | 4096 | 235 m |

Overrides are available independently. Forward+ enables FSR, FSR2, SSR, SDFGI and volumetric fog. The `city_detail` global uniform controls the optional high-detail surface work. The `city_wetness` and `city_snow` uniforms also affect surfaces and come from the weather system. The rain and snow draw with the Compatibility renderer.
