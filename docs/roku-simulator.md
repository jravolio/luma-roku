# Run the native Roku channel on this Mac

```sh
npm run simulate:roku
```

This builds `dist/luma.zip`, starts BrightScript Desktop Simulator, and loads the native BrightScript/SceneGraph channel. It does not run the React preview. The first launch downloads the official macOS **2.6.2** release (about 236 MB) and verifies its published SHA-256 digest. Later runs reuse it and reload Luma. No global installation is needed.

Open **http://127.0.0.1:8090/** for the live screen and remote. The desktop simulator window has sound; its browser screen stream is video-only. Use:

| Key | Roku action |
| --- | --- |
| Arrows | Navigate |
| Enter | OK |
| Escape | Back; dismiss an open player menu first |
| End | Play/pause |
| Insert / on-screen Options | Playback options |
| Backspace | Replay |
| Home | Exit the channel; rerun the command to reopen it |

The viewer's text field sends text to a native keyboard dialog. Use the simulator window for password entry, since the viewer field is plain text.

`npm run simulator:status` checks the running environment. Quit the desktop simulator normally when finished. Its profile and saved account remain in ignored `.local/roku-simulator/profile`; the download is in `.local/tools/brs-desktop`. Logs stay local and can contain private media URLs, so do not publish them unredacted. Simulator services accept localhost connections only; they do not advertise a fake Roku on the home network.

## What matches the TV

The same `dist/luma.zip` is executed, including Task nodes, registry, native SceneGraph UI, Video node, player menus, and remote-key handlers. It runs at 1920×1080 with Portuguese/Brazil locale, the host timezone and reported model G510X. This release implements OS 16 APIs and reports 16.0.4.

The model setting changes device identity, not hardware behavior. This is an API simulator, not a Philco firmware image. It cannot establish the TV's memory limits, GPU performance, codecs, HDMI/HDCP behavior, HDR, or 4K decoder support. Remote screen compression can also soften text; inspect the desktop window for rendering detail.

## Known networking limitation in this simulator

The tested 2.6.2 desktop release / 2.6.1 engine logs a UDP helper error (`NS.tmpdir is not a function`). Its HTTP “async” operations also execute synchronous XHR inside the message-port callback. An unreachable host can block that callback, so Luma's normal asynchronous subnet-probe deadlines cannot run. Fresh automatic discovery therefore stalled in this simulator. Native discovery was not altered to accommodate it.

For the local acceptance pass, the existing browser preview's saved account and **verified public server identity** were copied privately into the isolated simulator registry. Luma then contacted Jellyfin directly over the home LAN, rendered the real library and opened a real movie. No credentials were embedded in the ZIP. This validates the saved-session path; it does **not** validate native first-time sign-in or discovery after DHCP changes. A new/cleared simulator profile currently needs the same provisioning workaround or an upstream networking fix.

The simulator drops `ContentNode.playStart` when handing content to its media player. Luma now verifies the new decoder's reported position before completing a resumed start or stream replacement. If the bookmark was ignored, it issues one absolute seek, keeps the saved position authoritative, and waits for acknowledgement within three seconds of the target. A 20-second seek-acknowledgement timeout offers recovery instead of saving a false zero. The native Roku bookmark remains the primary path; a correctly applied bookmark does not incur another seek. Its explicit seek path can also resume paused video, so the channel preserves pause intent on acknowledgement. See the [engine's Video implementation](https://github.com/lvcabral/brs-engine/blob/v2.6.1/src/extensions/scenegraph/nodes/Video.ts).

Local audio-switch acceptance (2026-10-12): Avatar 2 retained **3:30** and stayed paused when switching from the TrueHD source track to the compatibility source track. Switching back while playing resumed around the requested 3:40 position and continued beyond 4:39 without restarting. These are source-track selections, not a claim of TrueHD/Atmos output on the Mac. Buffering is still required for Jellyfin's separately negotiated single-audio streams; this is not seamless alternate-audio HLS. The updated guard has not yet been tested on the physical TV.

Do not interpret a successful local run as completion of the [physical Roku acceptance checklist](../tests/roku/HARDWARE.md). The next step is developer-mode sideloading of the same ZIP on the TV; see [installation instructions](testing.md#build-and-install-the-native-roku-app). The TV's previously photographed address did not respond during this pass, so use its current network settings to find the address.

Sources: [simulator release](https://github.com/lvcabral/brs-desktop/releases/tag/v2.6.2), [remote services](https://github.com/lvcabral/brs-desktop/blob/v2.6.2/docs/remote-access.md), [engine limitations](https://github.com/lvcabral/brs-engine/blob/v2.6.1/docs/limitations.md), [HTTP implementation](https://github.com/lvcabral/brs-engine/blob/v2.6.1/src/core/brsTypes/components/RoURLTransfer.ts).
