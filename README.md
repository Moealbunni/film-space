# Film Space for iPhone — personal editor edition 1.3

Based on [Max Prokopp's Film Space](https://github.com/maxprokopp/film-space). Original project description and attribution are preserved in [UPSTREAM-README.md](UPSTREAM-README.md).

A local virtual studio: arrange colored 3D reference objects, then move your iPhone to perform the camera move and record a clean MP4. No AI subscription, Google account, or generation credits are needed to use this app.

## Downloads

- [iPhone 1.3 release and unsigned IPA](https://github.com/Moealbunni/film-space/releases/tag/iphone-v1.3.0)
- [Windows 0.4 app and source](https://github.com/Moealbunni/film-space-universal/releases/tag/v0.4.0)
- [Build workflow and downloadable artifacts](https://github.com/Moealbunni/film-space/actions/workflows/build-ipa.yml)

**An unsigned IPA needs signing before installation. It is not an App Store or TestFlight download.** iOS 18 or later and an ARKit-capable iPhone are required. Both apps can edit and record independently, transfer scenes over local Wi-Fi, and show the iPhone camera view on Windows.

## 1. Install from your Windows PC

1. Download the IPA from the release above to your PC.
2. Download [Sideloadly from its official website](https://sideloadly.io/). Follow its Windows prerequisites for the web versions of iTunes and iCloud.
3. Connect your iPhone by USB, unlock it, and accept Trust if prompted.
4. Open Sideloadly, select your phone, and drag in the IPA.
5. Enter your Apple account directly into Sideloadly and complete its authentication prompts yourself. Start installation.
6. Follow iOS prompts to trust the developer profile and enable Developer Mode if required. Open Film Space.
7. Allow Camera for tracking, Photos for saving video, and Microphone if you want audio.

Sideloadly supports free Apple accounts; free signing lasts seven days, with automatic refresh available. See the [official installation and refresh information](https://sideloadly.io/). Physical installation and device testing are deferred until the phone is connected.

## 2. Build your scene before recording

Landscape orientation is recommended for the bottom toolbar.

1. Choose **Edit**, then tap **Menu → Objects & scene** (or Add / edit objects in the side panel).
2. Tap a preset: Person, Child, Car, Bike, Box, Sphere, Wall, Cylinder, Cone, Circle, Plane, or Torus. Cars and bikes are simple blocking shapes, and the ring uses rounded segments.
3. Tap an object's name in the list to select it. Change its name to identify its role, such as “Red actor”, “Yellow car”, or “Cat reference”. Naming a shape does not generate a detailed model.
4. Pick any color or use the red, blue, green, and yellow shortcuts.
5. Use **Bigger/Smaller** to resize uniformly. Width, Height, and Depth edit each dimension separately; 1 means original size. A Child begins at 65% adult size.
6. Edit Position X/Y/Z with number fields or +/- controls. Y is height. Use Rotation X/Y/Z to tilt or turn it. Duplicate makes a copy; Delete removes it.
7. Adjust Floor size, from 2 to 200 meters, in the same panel.
8. Tap **Save scene** before leaving the app. This stores one scene on this iPhone; saving again replaces it. **Load saved scene** restores it. Deleting the app deletes its local save.
9. Tap **Done**. Tap empty space to deselect, drag to orbit, and pinch to zoom the lens in or out. A selected object can be dragged across the floor without losing its height.

## 3. Frame and control the camera

- The side-panel Up / Down controls raise/lower the camera; the joystick moves it across the floor in both modes.
- Set Touch sensitivity in Objects & scene for slower or faster orbit gestures.
- Lock saves and freezes the current viewpoint. Tap **Unlock viewpoint** once to resume navigation. Object editing remains available while the viewpoint is locked.
- Lens / saved view → Return to saved view recalls the last saved viewpoint. Unlocking does not erase that saved pose.
- Choose 18/24/35/50/75/200 mm in the editor or the side-panel Lens / saved view menu.

## 4. Use physical iPhone tracking

1. Frame the scene in Edit, unlock the viewpoint, then switch to **Camera**.
2. Let tracking initialize. The status message says **Tracking ready** when ARKit reports normal tracking.
3. Walk forward/backward or sideways, raise/lower the phone, and tilt/turn it. Position and rotation both drive the virtual camera. The real camera supplies tracking data; its live background is not recorded.
4. Use a well-lit room with visible surface detail. A blank wall, covered camera, or abrupt motion can reduce tracking quality; the status advises moving slowly.
5. For slow movement, set Phone movement to 0.1–0.5× in the side panel, including during recording. At 1×, one physical meter becomes one virtual meter; rotation uses the selected smoothing. This changes camera movement, not time or object animation.
6. Lens / saved view → Shoulder position moves the camera to roughly 1.5 m at the scene center. Return rebases tracking onto your saved viewpoint.

## 5. Record and find the video

1. Tap Record in Camera mode.
2. Perform the move. Tap Stop to finish.
3. Wait for encoding and check the video in Photos. Allow Photos access when prompted.
4. The export is H.264 MP4, targeting 60 fps with a maximum long side of 1280 pixels, plus microphone audio when available. Actual throughput depends on the device.
5. Buttons, object panels, tracking messages, selection controls, and editor guide axes are excluded. The checkerboard floor and objects remain in the scene.
6. Share the MP4 from Photos to your PC or a video-reference AI workflow. This app does not automatically call an AI service.

## 6. Rebuild from Windows using GitHub

1. Open this repository's **Actions** tab.
2. Select **Build Film Space iPhone app** and choose **Run workflow** on main. Source pushes also trigger it.
3. Wait for the Mac runner's checks and build to finish successfully.
4. Open the run and download **FilmSpace-unsigned-IPA** under Artifacts. Unzip it to obtain the IPA.
5. Sign and install with the steps above. No local Mac is required for this workflow; GitHub supplies Xcode 26 on its hosted Mac runner.

## Source map

- `Models/SceneState.swift`: object properties, local persistence, camera settings.
- `Views/ObjectEditorView.swift`: add menu, object list, inspector, save/load.
- `Services/SceneContentBuilder.swift`: primitive and vehicle geometry.
- `Views/ARCameraView.swift`: shared edit/camera renderer, gestures, tracking and smoothing.
- `Views/CameraSideControls.swift`: joystick, zoom and movement controls.
- `Services/SceneRecorder.swift`: scene-only MP4 and audio encoding.
- `.github/workflows/build-ipa.yml`: hosted build and packaging.

## Verification and remaining limits

The 1.2 release adds local pairing, scene transfers and recording-menu auto-hide. The device build and both simulator tests passed in [run 39284353578](https://github.com/Moealbunni/film-space/actions/runs/39284353578), at source commit `80698fed6c3c09a97009dcecb4b19fc269ac4b8a`. The IPA archive was checked as version 1.2, build 3, minimum iOS 18, with the Local Network permission description. Real-device ARKit tracking, Wi-Fi preview performance, Photos/audio behavior and touch usability remain pending; physical iPhone installation is deferred. No Android or Mac package is included.


## Axis locks, resets, and direct controls

- Camera **Position X/Y/Z** locks hold individual world coordinates. Camera **Rotation X/Y/Z** locks hold the current angles: X is tilt, Y is heading, Z is roll. You can enter 45 degrees and lock that rotation axis. Other axes remain free. Locks remain active when changing modes.
- **Lock lens / zoom** prevents changes to focal length. A perspective camera has no useful object-size scale, so use lens controls for zoom.
- Objects have separate locks for all X/Y/Z position, rotation, and scale values. A closed lock holds that value during dragging, resizing, and quick edits.
- **Reset position** returns an object to the origin; **Reset rotation** returns all angles to zero; **Reset size** returns all scales to 1. Each reset clears its group's locks. Reset size makes a child adult-sized; use Smaller to shrink it again.
- For the camera, Position Reset returns to (0, 1.6, 4) meters; Rotation Reset faces along the default forward direction. **Reset camera** clears position/rotation locks and full viewpoint locking, then restores both defaults.
- On Windows, select an object and use its floating **Move / Rotate / Resize** buttons to show draggable 3D handles. Bigger/Smaller and Lift/Lower are beside the object. The side inspector provides exact numbers and locks.
- On iPhone, tap an object or select it in Objects & scene. The right-hand quick panel provides Bigger/Smaller, Lift/Lower and Edit details. **Menu → Camera axis locks & reset** opens the axis lock panel in either mode.
- Resizing from ground level keeps the object's base on the floor; Lift/Lower changes its height deliberately. Floor resizing scales the checkerboard squares along with the ground.
- Recording captures only the scene. Quick panels and 3D editing handles are excluded.


## Connect iPhone and Windows on Wi-Fi

1. Install Windows **0.4.0** and iPhone **1.3**. Put both devices on the same private Wi-Fi network and keep both apps open.
2. On Windows, expand **Connect iPhone**, then click **Start pairing**. If Windows asks, allow Film Space on **Private networks**. A QR code appears. If multiple addresses appear, choose your Wi-Fi adapter's address.
3. On iPhone, tap **Menu → Desktop link → Scan desktop QR**. Scan the code displayed on Windows and allow **Local Network** access. You can also paste the pairing address and tap Connect.
4. Tap **Done**, then choose **Camera** on iPhone. On Windows, click **Live Monitor**. You see the actual rendered iPhone camera view, plus its recording status. Click **Back to desktop editor** to close the monitor.
5. On iPhone, start recording. The menus automatically disappear, leaving **Stop recording** and **Controls**. Tap Controls to bring them back, then Hide controls to clear them again. These buttons never enter the MP4.
6. Each app can edit and record independently. Record the full-quality phone MP4 on iPhone; it saves to Photos. Record the Windows scene using its Record video button after closing Live Monitor. The Windows monitor does not save a second phone MP4 or remotely press the phone's recording button.
7. Click **Stop sharing** on Windows (or Disconnect on iPhone) when finished. Starting pairing again creates a new code; old codes no longer connect.

### Move scenes in either direction

- **Windows → iPhone:** save any phone scene you need, click **Prepare scene for phone** on Windows, then tap **Load desktop scene** on iPhone. Return to the camera after loading.
- **iPhone → Windows:** save any Windows scene you need, tap **Send scene to desktop** on iPhone, then click **Load received phone scene** on Windows.
- Transfers replace the receiving scene. They include object presets, names, colors, position/rotation/scale, floor size and lens. They do not merge ongoing edits. Camera viewpoints, axis locks, local saves and recorded clips remain on their original device.
- The apps use different rendering engines, so materials and basic preset shapes may look slightly different after transfer. Live Monitor shows the actual iPhone image.

### Preview quality and connection help

The monitor uses JPEG previews capped at 640 pixels on the long edge, targeting about 6 frames per second without audio. This is a framing monitor, not a full-quality video stream. Smoothness depends on phone performance and Wi-Fi. The native phone recording uses its separate MP4 recorder. Physical-device performance still needs testing.

If pairing fails, check that both devices use the same network, that Windows permits the app on Private networks, and that iPhone Settings allows Local Network and Camera access. Guest Wi-Fi can block communication between devices. VPNs and multiple network adapters may require choosing the Wi-Fi address in Windows. If preview pauses, return to Camera mode on iPhone and keep it awake. Re-pair after restarting Windows sharing.

The connection uses a random session token and direct local HTTP, with no cloud account or AI credits. It is not encrypted; use trusted private Wi-Fi and keep the pairing QR private. Internet access is not required for editing, recording or the local link.

### Developer checks

Run `node --test phone-link.test.cjs` for authorization, scene validation, JPEG handling, transfer and token rotation checks. Run `npm run build`, then `.\node_modules\electron\dist\electron.exe monitor-smoke.cjs` for the real Electron preload/IPC, QR pairing, received preview, recording indicator, monitor toggle and scene import checks. `smoke.cjs` tests the existing editor, axis locks, persistence and MP4 export. The phone simulator tests include pairing address validation and scene serialization. A simulated sender exercises Windows preview tests; a physical iPhone session is still pending.


## iPhone 1.3: smooth camera and recording controls

### Update the installed app

Download the new unsigned IPA from the 1.3 release. In Sideloadly, select your connected iPhone, use the same Apple ID as before, load the new IPA, and install over the existing Film Space app. Do not delete the existing app first if you want to keep its local saved scene. The Windows 0.4.0 Live Monitor remains compatible.

### Find everything without clipped menus

The top bar contains Menu, Edit, Camera, Controls/Hide controls and Record/Stop. The bar can scroll horizontally if the screen is narrow. Menu opens Objects & scene, Camera axis locks & reset, Desktop link or Save scene. The right-hand panel scrolls inside the screen rather than growing beyond it. Controls hide automatically when recording starts; tap Controls to bring the side panel back during the take. All interface elements remain outside the exported video.

### Zoom while editing, standing still or recording

- Pinch the scene with two fingers in either mode.
- Drag the Smooth zoom slider between 0.5× and 4× relative to the selected lens.
- Tap + Zoom / − Zoom for a small eased change. Hold a button for continuous zoom.
- Tap a 0.5× / 1× / 2× / 4× preset to ease toward that zoom.
- Lens / zoom lock disables these inputs. Zoom changes the virtual lens; it does not require walking or change the real phone camera's optical lens.

### Move with the joystick and your phone together

The same round joystick is available in Edit and Camera mode. In Camera mode it moves the virtual camera while ARKit continues to track your physical position and orientation. Up / Down raises or lowers it. Camera smoothing eases starts, stops and small tracking changes. Higher values feel softer but introduce more lag; zero follows the input directly. Side-panel movement stops when the panel closes.

Movement scales physical travel from 0.1× to 10× and also adjusts joystick speed. For your 4 m room / 10 m virtual travel example, use **2.5×**: 1 m walked becomes 2.5 m in the scene. The 1×, 2.5×, 5× and 10× buttons provide quick presets. Changing this value rebases at the current viewpoint to avoid a jump. This setting expands virtual travel, not your physical safe walking space. Zoom and smoothing are stored with the local scene save; the current desktop transfer format keeps these phone-specific controls local.

### Performance and 60 fps recording

Edit and Camera now share one persistent ARView and tracking session, avoiding renderer destruction and tracking reset on every mode switch. Shape templates are reused; color changes update existing materials, and primitive selection uses simple bounding shapes rather than repeated mesh collision generation. The checkerboard uses one mesh instead of 200 tile entities. During recording, the Wi-Fi preview reuses captured frames instead of taking additional snapshots. The encoder queue is bounded to avoid accumulating frames when the device is busy.

The MP4 recorder requests **60 fps**, H.264 and a 12 Mbps encoding bitrate, with the existing maximum image dimension of 1280 pixels. Actual captured frame rate can fall below 60 when the device cannot render/capture/encode fast enough; this update does not guarantee sustained 60 fps on every iPhone. The Windows monitor remains a lower-resolution preview at about 6 fps. Real-device performance verification is separate from compilation and simulator tests.
