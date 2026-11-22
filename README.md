# GTA MAŽEIKIAI

A playable Godot 4 project set on the mapped streets of Mažeikiai, Lithuania.

## Play

1. Extract the project and keep its folders together.
2. In [Godot 4.7.2](https://godotengine.org/download/archive/4.7.2-stable/), select **Import** and open the extracted `GTA_MAZEIKIAI/project.godot`. Allow the first asset import to finish.
3. Press **F5**. The title, **NotUziStudios**, and **BLITZ** cards appear first. Let the intro finish or press **Enter** or **Esc** to skip it. Select **PLAY** on the title screen to start.
4. You begin on **Žemaitijos g.** Press **E** by the car, then use **WASD** to drive. Hold **Q**, point at a station, and release **Q** to tune. Use **Space** to brake. The first checkpoint is farther along the same street, near Naftininkų g.
5. To reload progress, use **Esc → SAVE**, return to the title screen, and choose your manual save or auto-save under **CONTINUE**.

| Action | Keyboard and mouse | Controller |
| --- | --- | --- |
| Walk, drive, reverse and steer | WASD | Left stick |
| Look around | Mouse | Right stick |
| Switch between chase and cockpit cameras | V | Right-stick click |
| Sprint | Shift | Left-stick click |
| Jump, vault, surface or brake | Space | A / south |
| Dive while swimming | Ctrl | Keyboard |
| Interact, enter or honk | E | Y / north |
| Leave the car | F when stopped or moving slowly | B / east |
| Tune radio in the car | Hold Q, point or use arrows, release Q | Hold LB, point with right stick, release LB |
| Turn radio off | Point to centre or press X while the picker is open | Press A while picker is open |
| Choose equipment | Hold Tab, point, release Tab | Hold RB, point with right stick, release RB |
| Open weapon wheel | Hold Backtick (`) | Hold D-pad left |
| Punch or use equipped gear | Left mouse button | Right trigger or X / west |
| Open the phone | Up Arrow | D-pad down |
| Use the selected hotbar item | Y | Phone backpack |
| Throw a held item or ragdoll | G. Tap repeatedly for a stronger item throw. | Touch Throw or rebind |
| Drop a held item or ragdoll | Backspace | Rebind in Settings |
| Return to checkpoint with a firearm equipped | K | Rebind in Settings |
| Multiplayer chat | / | Keyboard |
| Pick inventory slot | Scroll wheel or 1–8 | Inventory picker |
| Select character | Hold Alt, use arrows or scroll, release Alt. C cycles directly. | D-pad up |
| Recover a stopped or overturned car | R | Keyboard |
| Hold enlarged minimap | T | Keyboard |
| Reset display to windowed defaults | F10 | Keyboard |
| Take a wallet, search a glovebox, or take a shelf product | F, on foot and within reach | Keyboard |
| Pause | Esc | Start |

**Esc** opens the fullscreen pause map and freezes the radio where it is. Drag to pan and scroll to zoom. Double-click a destination to set a purple route along connected roads. The route appears on both maps, adjusts if you leave it, and clears when you arrive. Right-click the fullscreen map to remove it. The map caches discovered streets and building footprints while keeping unexplored areas dark. **T** shows the enlarged minimap during gameplay. A new game starts with an empty hotbar and €0.

Henry Stickmin is Main and Blitzo is Joris. Both supplied models have articulated walking and running poses. Henry uses the corrected FBX rig and face materials. Blitzo uses a game-ready rig with the supplied textures and a shorter curved tail. The source FBX and rig-building tool are included. The game’s Credits page lists the supplied model sources.

**CONTINUE** lets you choose Auto-save or Manual Save. **PLAY** asks for confirmation before clearing the auto-save slot. Your manual save stays available. Autosave normally runs every 45 seconds and after checkpoints, pickups, and purchases. Henry and Blitzo each have their own cash, inventory, hotbar and equipped gear. Older saves assign shared gear and cash to the active character.

Press **E** near a stopped car to walk to the driver's door, open it and climb in. **F** plays a separate glovebox search. Press **V** to look around the cabin. Vehicle panels dent on impact. Severe crashes can detach body panels and leave a smoking wreck. Hard crashes scatter masonry debris and can shatter shop door panes or knock down streetlights. The structural walls stay solid. Vehicle theft, shoplifting and serious collisions can raise the six-star wanted level. **POLICIJA** patrols respond with lights and siren and search until the player gets away.

Find **Maxima XX** at Žemaitijos g. 20-2. Look for the gold **M** on the minimap and fullscreen map. Walk through the automatic doors at **Maxima XX**, **Rimi**, **Rovana** and **Grūstė · Putinas**. Grūstė · Putinas is marked at the corner entrance at Naftininkų g. 38-2. The 2go screens face the two approaches on the other side of the junction. Both Putinas and Maxima XX now use almost all of their mapped ground-floor footprint, with enterable departments, stocked shelves and working checkouts. The department layouts are gameplay interpretations. [Grūstė store directory](https://gruste.lt/parduotuves) · [Maxima’s Mažeikiai refurbishment](https://sc.bns.lt/view/item/po-atnaujinimo-mazeikiuose-atidaryta-maxima-xx-parduotuve-174029) · [2go screen orientations](https://www.2go.lt/ekranai/mazeikiai)

Press **E** at the **Kultūros centras** lobby entrance. At Maxima XX or Putinas, use any checkout or face a shelf product and press **E** to buy it. **F** takes the same item without paying and raises the wanted level. The real store's blue and silver panels, roof sign, glass entrance, and parking informed a modeled exterior on the mapped footprint. The playable shop floor is an approximation. [Maxima property listing](https://www.maxima.lt/verslui/siuo-metu-nuomojamos-patalpos) · [Published photo of the Žemaitijos g. frontage](https://telsiai.policija.lrv.lt/lt/naujienos/prasome-pagalbos-nustatant-eismo-ivykio-aplinkybes-42/)

The item catalog includes cola, Sprunk, gira, cepelinai, šaltibarščiai, frozen food, yogurt, drinks and electronics. The selected hotbar item appears in your hand. **G** throws it, and **Backspace** drops it. Press **E** near it to pick it up again. Bundled grocery models come from Kenney’s CC0 Food Kit and supplied assets. Other items use prototype models. [Kenney Food Kit](https://opengameart.org/content/food-kit) **Burger Stotis** is a walk-in restaurant at Eifelis on Senkelio g. 14A with meals, Sprunk, McPiss orange soda, seating and a play area. Lidl on Daukšos g. 24 has a grocery hall, bakery and checkouts. Senukai on Tirkšlių g. 5E has hardware aisles and a pickup counter. The store interiors use mapped footprints and public storefront references with original interior layouts. Pickups display a small floating item icon. The phone's **Backpack** keeps everything you own, and **PIN** places an item in the currently selected hotbar slot. Food, drinks, and bandages with a **USE** button restore stamina or health. Hold the cannabis item and press **E** for a 90-second visual effect. The phone includes an offline Messenger app and Gugu local search. [Eifelis restaurant reference](https://www.hesburger.lt/restoranai?tid=420)

The **Backtick** wheel equips acquired gear. The catalog includes the existing gear and seven new weapons or tools available at Rovana. **K** shows a checkpoint restart screen when a firearm is equipped. Select the centre to put gear away. **Left click** uses the equipped gear or punches if your hands are empty. Some pedestrians fight back at close range. Firearms produce impact effects and draw police attention. The player has separate walking, running, jumping and landing animations. Pedestrians stumble with pose-controlled physics or fall with a 13-bone ragdoll, then blend into a get-up animation. Hard landings reduce player health. **Settings → Display → Injury effects → Full** shows heavier particle spray, bleeding, pooled stains and splatter trails from severe impacts. The Field Blade from Rovana can separate the head or torso of a fallen pedestrian when effects are set to Full.

Orange **F** map pins mark 12 fuel stops. Press **F** at a kiosk entrance with a firearm equipped and the clerk hands over cash. With empty hands, **F** starts a 55-second parcel run. Press **E** at the marked parcel and leave the forecourt. Clearing a stop pays cash and records it in your save. The kiosk layouts and robbery objectives are fictional. [Lithuanian Energy Agency station registry](https://www.ena.lt/degalu-kainos-degalinese/)

Press **E** by a fallen ragdoll to carry it. **G** throws it, and **Backspace** or **E** puts it down. Thrown items keep their distinct models. Wall dents stay in your save. Blood trails and splatter fade and disappear after three in-game days. **Settings → Audio** offers High and Low sound quality. **Settings → Display** provides terrain and façade texture detail (Off, Low or Full) and a draw distance from 0.3 to 2.5 km.

Enter Swedbank at Žemaitijos g. 1A or the fictional SED branch in the old town. Press **F** to start the bank challenge, collect three marked tokens with **E**, and exit within 40 seconds. The playable interiors and objectives are fictional. [Swedbank branch directory](https://www.swedbank.lt/private/home/contacts?language=LIT)

The teal **H** markers on **T** and the pause map show Main's and Joris's apartment buildings, just south of the starter car. Press **E** at a building entrance, take both flights around the half landing, then press **E** at the upstairs door. The doors, stairs, landings and furnished flats share the city's 3D space. Walk down and open the same street door to leave. Saves can resume inside the flats. The paired stair flights and the short entrance hallway follow the published Sodų g. 8-2 layout. The two playable homes are fictional, with adapted dimensions and furnishings. [Mažeikiai municipal plan, sheet 2](https://www.mazeikiai.lt/uploads/main/documents/files/veiklos-sritys/architektura-urbanistika/visuomenes-informavimas-apie-numatoma-statiniu-projektavima/2023m/2023-03-01vaizdin%C4%97-med%C5%BEiaga.pdf)

**At fuel stations**, walk to the register and press **E** to shop. Monster and Red Bull flavors restore stamina and increase your on-foot movement speed by 22% for a short time. Use a consumable with **Y** or from the phone backpack. **F** exits a stopped car or helicopter and bails out when it is moving. Hold **Q** for radio in either vehicle. Lower **Settings → Graphics → Greenery density** to render fewer trees and bushes. The Low preset also reduces traffic and pedestrian density, shortens tree draw distance, and limits particle and shadow cost. The fullscreen map displays the remaining distance for an active GPS route.

The expanded southern map includes the Venta, Kruciai, and Tirkšliai. Open the pause map for labels as you explore. Settings includes a mobile joystick-size slider and a controller look-sensitivity slider. Foods and drinks can be used with **Y** or the phone backpack. They have different use poses and replenish health or stamina according to the item. Drinks use the supplied drinking sound. On defeat, the supplied audio starts immediately, the foggy red **YOU DIED** title appears two seconds into the track, and the player respawns after it finishes.

## Multiplayer

Players on the updated build can punch or shoot one another. Older clients that already understand version prompts are offered a choice before joining a newer server on the same protocol. Builds released before the version prompt receive a warning in chat after joining. Gameplay additions depend on the version each player is running.

- **Same network**. Choose **Multiplayer → Host Session**, enter a username and optionally a password, and start hosting. Guests choose **Join Session**, enter a username, pick the room under **Nearby rooms**, and connect. If local discovery is unavailable, use the host's **Esc → LAN Invite** and paste the invite in the Join field.
- **Across the internet**. The host can try **Esc → Internet Invite**. If the router offers UPnP with a public IPv4 address, the game requests a temporary UDP forwarding lease and offers an invite to copy. On other networks use a public host address with forwarding for the game's UDP port, a shared VPN address, or a dedicated room. Share any room password separately. [Godot networking documentation](https://docs.godotengine.org/en/4.7/tutorials/networking/high_level_multiplayer.html)
- **In the session**. Press **/** to chat, **Enter** to send, and **Esc** to close chat or leave through the session menu. Up to eight players can see each other walking and driving. Traffic, police, missions and property damage are simulated locally. Multiplayer sessions do not use the single-player save slots.

### Public dedicated room

On a machine with a publicly reachable UDP port, extract this project and run Godot 4.7.2 in headless mode. The server only runs the room and does not load the city. Guests need only your public IP or hostname, the game port, and the password if you set one. Each process hosts one room. The project does not use a central matchmaking or relay service.

```sh
MAZEIKIAI_PORT=31940 MAZEIKIAI_ROOM_PASSWORD='your-room-password' \
  godot --headless --path /path/to/GTA_MAZEIKIAI -- --dedicated-room
```

On a Windows host where you have exported the standalone game, PowerShell uses the same settings.

```powershell
$env:MAZEIKIAI_PORT = '31940'
$env:MAZEIKIAI_ROOM_PASSWORD = 'your-room-password'
.\GTA_MAZEIKIAI.exe --headless -- --dedicated-room
```

## Windows, Android and iOS exports

For iPhone and iPad, use the **iOS 15** export preset with Godot 4.7.2 and matching templates. It targets iOS/iPadOS 15.0 on ARM64 and uses the game's Compatibility renderer. The actual minimum device for acceptable performance needs testing on hardware.

1. On a Mac with Xcode, set your Apple Team ID in **Project → Export → iOS 15**. Use your own unique bundle identifier if Xcode cannot register the default one.
2. To embed the supplied audio, install PowerShell 7 and run `pwsh -NoProfile -File tools/stage_android_audio.ps1` from the Godot project directory. This stages the same audio for both mobile presets.
3. Select **Export Project**. Choose an empty output directory and the basename `GTA_MAZEIKIAI.ipa`. This preset generates an Xcode project. Open the resulting `.xcodeproj`, select your Team in **Signing & Capabilities**, select a connected iPhone or iPad, and click **Run**.
4. iOS uses the same touch controls as Android. Use an invite or host address to join multiplayer. Allow Local Network access for Wi-Fi connections. For custom media, open the game's folder under **On My iPhone** or **On My iPad** in Files after first launch and use its `Radio Music` and `Custom Assets` directories.

[Godot iOS export instructions](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_ios.html) · [Apple local network permissions](https://developer.apple.com/documentation/technotes/tn3179-understanding-local-network-privacy)

This project uses the Godot Engine. [Godot Engine license](https://godotengine.org/license)

- **Windows x64**. Install the matching Godot 4.7.2 export templates. In **Project → Export → Windows Desktop**, click **Export Project** and select an EXE location. Put your `Radio Music` and `Custom Assets` folders beside the exported game.
- **Android ARM64**. Install the export templates, OpenJDK 17, and the Android SDK. Set both SDK paths in **Editor Settings → Export → Android**. Select **Project → Export → Android**, then **Export Project** and **Export With Debug** for a test APK. The preset requests Internet access for multiplayer. Run `powershell.exe -NoProfile -File tools/stage_android_audio.ps1` from the project folder before export to include your loading tracks and station files in a local APK. The mobile interface includes a left thumbstick, drag to look, and touch buttons for driving, radio, inventory, the phone, chat and pause. [Godot Android export instructions](https://docs.godotengine.org/en/4.7/tutorials/export/exporting_for_android.html)

## Put your music in the game

Select **RADIO MUSIC** on the title screen or open `Radio Music/` beside the Windows executable or `project.godot`. It contains **14 station folders**. For example, put music for GrassFM in `Radio Music/12 GrassFM 83.1/`.

1. Copy **MP3, Ogg Vorbis, or WAV** files into the station folder. The game scans on PLAY and CONTINUE and checks for changed files whenever you open the radio wheel.
2. Tag files with artist and title in your music library or name them `Artist - Song Title.mp3`. The game uses embedded MP3 ID3, Vorbis comments, or WAV INFO tags first. It falls back to the artist and title in the filename. A bare name uses **Unknown artist**.
3. Tune the station in the car. The HUD shows the station, track title, artist, elapsed time and duration. Each station shuffles its songs and plays through the rotation before reshuffling. Your first tune can join a song in progress. Station clocks keep running while you switch stations or get out of the car. Pausing freezes them all. Name station interludes `1 Advert.mp3`, `2 DJ.ogg`, or similar. Stations with DJ and advert clips play one at random after each song. To turn inserts off, use **Settings → Audio → Radio DJ and adverts**. Folder 14 is **MATT’S INTERVIEWS**.

Godot plays MP3, Ogg Vorbis and WAV. On Windows, run `powershell.exe -NoProfile -File tools/convert_radio_m4a.ps1` from the project folder to convert M4A files to WAV alongside the originals. The local Windows and project ZIPs include the supplied music. Extract the whole archive to keep the tracks beside the game.

Empty stations stay silent until you add playable audio. A duplicate artist/title belongs to one station. If duplicate files are in multiple station folders, the last folder in catalog order owns the track. Move the file out of the old folder when changing its station. The known Lex Amarni playlist move is retained for bundled metadata and playlist imports. Placing audio in a different station folder makes it an explicit local assignment.

Older CSV, TXT and JSON playlists still work in the user data folder `radio_packs/playlists/`, with media in `radio_packs/media/`. Named packs can have their own `playlists/` and `media/` directories. The Windows user data folder is `%APPDATA%\GTA Mazeikiai Prototype`. It also accepts its own `Radio Music/` and `Custom Assets/` folders. When running an exported game, put the project folders next to the executable. Supply only audio you have permission to use.

## Replace artwork and sound

Choose **CUSTOM ASSETS** in the main menu, or open `Custom Assets/` beside `project.godot`. Drop a replacement into the matching slot below and reopen the title screen or restart the game. You can use PNG, JPEG, WebP, or SVG for images and WAV, Ogg Vorbis, or MP3 for sounds.

| Asset | Example replacement |
| --- | --- |
| Main menu backdrop | `Custom Assets/menu.jpg` |
| Windows game icon | `assets/brand/windows_icon.ico` |
| Clickable PikiHub icon | `Custom Assets/pikihub.png` |
| Studio splash portrait | `Custom Assets/studio_profile.png` |
| BLITZ portrait | `Custom Assets/blitz_profile.png` |
| Studio splash audio | `Custom Assets/sound/studio_start.mp3` |
| Crew loading artwork | `Custom Assets/loading/mazeikiai_crew.png` |
| Mažeikiai loading illustration | `Custom Assets/loading/mazeikiai.jpg` |
| Naikių g. hill loading view | `Custom Assets/loading/naikiu.jpg` |
| Kultūros centras loading capture | `Custom Assets/loading/culture.jpg` |
| Eifelis loading capture | `Custom Assets/loading/eifelis.jpg` |
| Gameplay loading music | `Custom Assets/sound/loading.mp3` |
| Item icon | `Custom Assets/items/purslas.png` |
| Engine loop | `Custom Assets/sound/engine.wav` |
| Door sound | `Custom Assets/sound/door.wav` |
| Menu hover, click and character select | `Custom Assets/sound/menu_hover.mp3`, `menu_click.mp3`, and `character_switch.mp3` |
| Crash sound | `Custom Assets/sound/impact.wav` |
| Walking and running sounds | `Custom Assets/sound/footstep_walk.wav` and `footstep_run.wav` |
| Tree ambience and police siren | `Custom Assets/sound/birdsong.wav` and `police_siren.wav` |
| Station icon | `Custom Assets/station_icons/mazeikiai_fm.png` |

Station icon overrides use the IDs in `data/radio_stations.json`. The bundled catalog links the supplied artwork by its original filename. A station abbreviation fills any icon slot without an image. Use a seamless loop for the engine recording. To add or reorder loading slides, edit `data/loading_art.json`.

The bundled menu uses the supplied `jo.jpg`. The startup cards fade in and out over 0.65 seconds. The title cue begins at 0:00, **(AND ZEKOPANE)** at 0:01, **NotUziStudios** at 0:03 and **BLITZ** at 0:05.5. The screen goes black at 0:08. The studio intro plays `studio_start.mp3` once. The second screen appears on **PLAY** and **CONTINUE**, loops `loading.mp3`, and holds each slide for five seconds and fades through black between images. A loading log shows the resources and phases as they load. The audio and screen fade together into gameplay. Keep both files in `Custom Assets/sound/` or the loading screens run in silence. The local Windows and project ZIPs include both supplied loading tracks.

## What the prototype covers

- An approximately **7.0 × 6.2 km Mažeikiai-area extract** projected at metre scale from OpenStreetMap. It includes 2,230 mapped road ways, 356 additional road and path sections, 8,804 base OSM building footprints, 1,655 supplemental cadastral footprints and 5 additional school buildings. Roads, pavement, vehicle collision and building foundations follow the local Copernicus elevation grid. [Map data and license](data/city/README.md) · [Elevation data and license](data/city/ELEVATION.md)
- Photographic ground and sky textures, procedural façade and pavement shaders, mesh-based trees, sun shadows, two animated players and a touring hatchback. Asphalt and road paint follow terrain triangles through elevation changes. The car uses a rigid-body chassis, four spring-and-damper wheel contacts, driven rear wheels, tire grip, and independent braking. [Model credits](assets/models/README.md) · [Photographic texture credits](assets/environment/README.md)
- A title menu, asynchronous musical loading, rectangular HUD, two playable characters (Main Character and Joris), an inventory picker, and local progress saves.
- Main and Joris use new rigged MakeHuman models and imported animation clips for locomotion, punches, swimming, climbing over obstacles, and entering cars. A road worker joins the pedestrian roster. [Models, animation and import instructions](TECHNICAL_SETUP.md#replacing-characters-and-animations)
- Ten park and recreation markers include Sodų skveras, Senamiesčio, Melioratorių, Juodpelkio, Senjorų, Pavasario, Vyturių takas and the Pavenčių riverside. The map imports mapped fences, walls, hedges and gate openings, plus paths and bridge spans. [Local park references](data/city/README.md#parks-and-storefronts)
- Walking pedestrians, four civilian traffic body types and a police sedan with Lithuanian-inspired livery. Traffic routes follow mapped street links. A full day and night takes 15 minutes of gameplay. Automatic weather cycles through clear conditions, rain and snow. Under **Settings → Graphics**, force a weather type to test it. Swim in mapped waterways including the Venta: use **Ctrl** to dive and **Space** to surface. Listen for footsteps and birds near some trees during daylight.

Six landmark exteriors have their own models. Look for the low green roof and spire of **Šv. Pranciškaus Asyžiečio bažnyčia**, the brick tower of **Švč. Jėzaus Širdies bažnyčia**, the stepped masses and tall windows of the **Kultūros centras**, the street-side lattice tower and commercial frontage at **Eifelis**, the narrow windows at the **Mažeikiai Museum**, and the rust-coloured screens at the **Henrikas Nagys Library**. Their locations follow mapped footprints and their exteriors are modeled from published photos. [Culture Centre](https://mkultura.lt/apie-mus/) · [St. Francis church](https://www.pamatyklietuvoje.lt/lankytinos-vietos/mazeikiu-sv-pranciskaus-asyziecio-baznycia/3453) · [Sacred Heart church](https://visit.mazeikiai.lt/lankytinos-vietos/mazeikiu-svc-jezaus-sirdies-baznycia-ir-asyziecio-kankiniu-kryzius/) · [Eifelis](https://commons.wikimedia.org/wiki/File:Ma%C5%BEeikiai,_Eifelis.JPG) · [Museum](https://www.bodesoslangai.lt/mazeikiu-muziejus/) · [Library](https://www.savb.lt/regiono-bibliotekos/)

Recent street modeling adds the Rimi frontage and indoor approach, four ČIA Market exteriors and detailed apartment fronts at Sodų g. 9, 11 and 13. The wider city uses mapped footprints with different house, apartment, industrial and retail treatments. Selected rectangular buildings use CC0 exterior models fitted to their footprints. Pavement widths, marked lanes, fine grades and untagged heights are approximations. The project runs offline with the bundled map and terrain. [Map data and license details](data/city/README.md)

Seventeen school and education sites have **S** markers on the city map and their own exterior treatment. The set includes Gabijos, Merkelio Račkausko, Ventos, Kalnėnų, Pavasario, Senamiesčio, Sodų, Jievaro, the three municipal primary schools, and other education sites. Their footprints and locations are mapped. [Municipal list of education sites](https://www.mazeikiai.lt/savivalda/administracine-informacija/veiklos-sritys/svietimas/svietimo-istaigos)

If you continue from the earlier flat Mažeikiai build, your mapped position is adjusted to the current ground height. Saves from the original invented street grid restart at the mapped spawn and retain money, items, and station. Povi and Poniukas saves open as the Main Character.

The game starts in Godot’s **Compatibility** renderer. **F10** restores the 1280 × 720 window and Medium graphics settings. **Settings → Graphics** has Low, Medium, High and Ultra presets and overrides for render scale, upscaling, antialiasing, shadows, fog, reflections, indirect light, bloom and surface detail. Forward+ is required for the controls marked as Forward+ features. Select that renderer in the editor or launch with `--rendering-method forward_plus` on a compatible PC.

The playable area is Mažeikiai. Zakopane appears in the intro title and remains a planned destination. The grocery catalog uses Kenney meshes for many products and representative props for some branded goods. The six stars can escalate patrol count and pursuit speed.

The [technical setup guide](TECHNICAL_SETUP.md) describes the scene trees and lists the exact suspension, ragdoll, lighting and shader settings. Character presets are in `data/characters.json`. The **Windows Desktop** export preset points to the supplied icon and includes the city and inventory data. Install the matching Godot export templates before building an executable.
