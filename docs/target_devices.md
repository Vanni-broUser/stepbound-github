# Target devices

F0 must be checked on at least one physical Android phone in landscape immersive mode. The minimum performance reference is an inexpensive 2021-class device.

| Tier | Reference | Android | RAM | Purpose |
| --- | --- | --- | --- | --- |
| Minimum | Motorola Moto E20 (2021) or equivalent | 11 Go | 2 GB | Startup, orientation, immersive mode |
| Mid-range | Samsung Galaxy A52 (2021) or equivalent | 11+ | 6 GB | Main gameplay target |
| Current | Pixel 8 or equivalent | 14+ | 8 GB | Modern OS compatibility |
| iOS | iPhone 11 or newer | iOS 13+ | 4 GB+ | Landscape and safe-area behavior |

## F0 physical smoke test

1. Install the current debug build on a clean device.
2. Launch Stepbound with the phone in portrait.
3. Confirm that the app switches to landscape.
4. Confirm that status and navigation bars are hidden.
5. Confirm that the screen is a stable blank dark surface.
6. Background and resume the app, then repeat the orientation and fullscreen checks.

Record the device model, OS version, build type, commit SHA, and result in the merge request.
