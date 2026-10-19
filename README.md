# Film Space for iPhone — personal editor edition 1.1

Based on [Max Prokopp's Film Space](https://github.com/maxprokopp/film-space). Original project description and attribution are preserved in [UPSTREAM-README.md](UPSTREAM-README.md).

A local virtual studio: arrange colored 3D reference objects, then move your iPhone to perform the camera move and record a clean MP4. No AI subscription, Google account, or generation credits are needed to use this app.

## Downloads

- [iPhone 1.1 release and unsigned IPA](https://github.com/Moealbunni/film-space/releases/tag/iphone-v1.1.0)
- [Windows 0.3 app and source](https://github.com/Moealbunni/film-space-universal/releases/tag/v0.3.1)
- [Build workflow and downloadable artifacts](https://github.com/Moealbunni/film-space/actions/workflows/build-ipa.yml)

**An unsigned IPA needs signing before installation. It is not an App Store or TestFlight download.** iOS 18 or later and an ARKit-capable iPhone are required. The Windows application and iPhone app run separately; live phone-to-PC control and scene transfer between them are not implemented.

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

1. Choose **Edit**, then tap **Objects & scene** at the top.
2. Tap a preset: Person, Child, Car, Bike, Box, Sphere, Wall, Cylinder, Cone, Circle, Plane, or Torus. Cars and bikes are simple blocking shapes, and the ring uses rounded segments.
3. Tap an object's name in the list to select it. Change its name to identify its role, such as “Red actor”, “Yellow car”, or “Cat reference”. Naming a shape does not generate a detailed model.
4. Pick any color or use the red, blue, green, and yellow shortcuts.
5. Use **Bigger/Smaller** to resize uniformly. Width, Height, and Depth edit each dimension separately; 1 means original size. A Child begins at 65% adult size.
6. Edit Position X/Y/Z with number fields or +/- controls. Y is height. Use Rotation X/Y/Z to tilt or turn it. Duplicate makes a copy; Delete removes it.
7. Adjust Floor size, from 2 to 200 meters, in the same panel.
8. Tap **Save scene** before leaving the app. This stores one scene on this iPhone; saving again replaces it. **Load saved scene** restores it. Deleting the app deletes its local save.
9. Tap **Done**. Tap empty space to deselect, drag to orbit, and pinch to approach or move away. A selected object can be dragged across the floor without losing its height.

## 3. Frame and control the camera

- The bottom arrows raise/lower the edit camera; the joystick moves it across the floor.
- Set Touch sensitivity in Objects & scene for slower or faster orbit gestures.
- Lock saves and freezes the current viewpoint. Tap the open-lock icon or **Unlock viewpoint** once to resume navigation. Object editing remains available while the viewpoint is locked.
- Return recalls the last saved viewpoint. Unlocking does not erase that saved pose.
- Choose a lens in the editor, or cycle 35/50/75/200 mm in Camera mode.

## 4. Use physical iPhone tracking

1. Frame the scene in Edit, unlock the viewpoint, then switch to **Camera**.
2. Let tracking initialize. The top status says **Tracking ready** when ARKit reports normal tracking.
3. Walk forward/backward or sideways, raise/lower the phone, and tilt/turn it. Position and rotation both drive the virtual camera. The real camera supplies tracking data; its live background is not recorded.
4. Use a well-lit room with visible surface detail. A blank wall, covered camera, or abrupt motion can reduce tracking quality; the status advises moving slowly.
5. For slow movement, set Phone movement to 0.1–0.5× **before entering Camera**. At 1×, one physical meter becomes one virtual meter; rotation remains direct. This changes camera movement, not time or object animation.
6. Shoulder placement moves the camera to roughly 1.5 m at the scene center. Return rebases tracking onto your saved viewpoint.

## 5. Record and find the video

1. Tap the red circle in Camera mode.
2. Perform the move. Tap the red square to stop.
3. Wait for encoding and check the video in Photos. Allow Photos access when prompted.
4. The export is H.264 MP4, targeting 30 fps with a maximum long side of 1280 pixels, plus microphone audio when available. Actual throughput depends on the device.
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
- `Views/VirtualStudioView.swift`: scene editing and touch gestures.
- `Views/ARCameraView.swift`: ARKit positional/rotational tracking and camera locking.
- `Services/SceneRecorder.swift`: scene-only MP4 and audio encoding.
- `.github/workflows/build-ipa.yml`: hosted build and packaging.

## Verification and remaining limits

The iPhone device build and simulator test passed in [run 39278500408](https://github.com/Moealbunni/film-space/actions/runs/39278500408), source commit `aac895830ba811da74ed4ff7f734fe512acdcb24`. The test checks all object types, save/load, duplication/deletion, object scale locking/reset and constrained camera position/rotation. IPA archive integrity, version 1.1 (build 2), and minimum iOS 18 were checked. Compilation and simulator checks are separate from hands-on verification: camera tracking, Photos saving, microphone behavior, and touch usability still need a real iPhone check. Windows has been runtime tested separately. Scenes are currently saved locally in each app; they do not synchronize. No Android or Mac package is included.


## Axis locks, resets, and direct controls

- Camera **Position X/Y/Z** locks hold individual world coordinates. Camera **Rotation X/Y/Z** locks hold the current angles: X is tilt, Y is heading, Z is roll. You can enter 45 degrees and lock that rotation axis. Other axes remain free. Locks remain active when changing modes.
- **Lock lens / zoom** prevents changes to focal length. A perspective camera has no useful object-size scale, so use lens controls for zoom.
- Objects have separate locks for all X/Y/Z position, rotation, and scale values. A closed lock holds that value during dragging, resizing, and quick edits.
- **Reset position** returns an object to the origin; **Reset rotation** returns all angles to zero; **Reset size** returns all scales to 1. Each reset clears its group's locks. Reset size makes a child adult-sized; use Smaller to shrink it again.
- For the camera, Position Reset returns to (0, 1.6, 4) meters; Rotation Reset faces along the default forward direction. **Reset camera** clears position/rotation locks and full viewpoint locking, then restores both defaults.
- On Windows, select an object and use its floating **Move / Rotate / Resize** buttons to show draggable 3D handles. Bigger/Smaller and Lift/Lower are beside the object. The side inspector provides exact numbers and locks.
- On iPhone, tap an object or select it in Objects & scene. The right-hand quick panel provides Bigger/Smaller, Lift/Lower and Edit details. **Camera controls** opens the axis lock panel in either mode.
- Resizing from ground level keeps the object's base on the floor; Lift/Lower changes its height deliberately. Floor resizing scales the checkerboard squares along with the ground.
- Recording captures only the scene. Quick panels and 3D editing handles are excluded.

