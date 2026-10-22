# Luma architecture

Luma is an independent Jellyfin client. The native TV application uses BrightScript and SceneGraph. The browser preview uses React and a local Node gateway because a browser cannot broadcast UDP packets itself.

## A server is more than its address

The durable connection tuple is Jellyfin server ID, user ID, access token, and a stable client device ID. The last known URL is a cache, not the identity. The password is used only for initial authentication.

1. Request `/System/Info/Public` at the saved URL without an access token.
2. If the ID matches, validate the saved session against that server.
3. If the address is unreachable or belongs to a different server, discover servers using Jellyfin's UDP protocol on port 7359. If UDP cannot find the server, make a bounded, concurrent pass over local private-network addresses using Jellyfin's public HTTP identity endpoint.
4. Check candidate identities through `/System/Info/Public` and select the saved server ID.
5. Update its cached URL and use the saved token.
6. Preserve credentials during an outage; request sign-in when the server rejects authentication.

Discovery is the default first-run entry, followed by sign-in. Demo content requires an explicit choice and never substitutes for an offline or unsigned-in account. Automatic discovery excludes known tunnel adapters and non-private IPv4 addresses, keeping discovery on the home LAN; a deliberate manual URL remains available for other networks. Discovery also supports first-run server selection. HTTP discovery uses the default Jellyfin port initially and the saved port/base path for reconnection; the fallback is restricted and bounded rather than scanning arbitrary networks. A manual address accommodates custom network layouts. Addresses may include Jellyfin's configured base path. A server reinstall with a new ID is a new server and must not silently inherit a previous session.

Jellyfin's unauthenticated server ID prevents accidental credential delivery to another server that acquired an old DHCP address; it is not a cryptographic identity. The normal deployment is the user's trusted home LAN.

## Two execution environments

- `roku/`: standalone SceneGraph channel. Network work runs in Task nodes. Persistent account data lives in Roku registry storage. Video is decoded by the Roku Video node.
- `preview/`: browser interface with pointer, keyboard and simulated remote navigation. Demo mode is explicitly selected and labelled. A real server supplies the actual library, artwork and playback responses.
- `server/`: loopback-only discovery and Jellyfin gateway for the preview. The gateway keeps tokens out of frontend storage, restricts browser origins, and proxies only application-owned media requests.
- `server/.local/`: ignored local preview session storage. Root `.local/` holds ignored diagnostics and QA data. Neither is packaged with the Roku channel.
- `tests/server/`: protocol and gateway tests using a controlled Jellyfin fixture.

The TV does not require the preview or Mac to keep running. Signing into the preview and signing into the native Roku app are separate device sessions.

## Playback

The client requests Jellyfin playback information with a device profile, selects a compatible stream, resumes from saved position, and reports session progress. Actual codec, audio, subtitle and transcode behavior must be tested with representative files on the Philco TV. Browser playback exercises the browser profile and cannot certify Roku hardware compatibility.

## References

- [Roku developer documentation](https://developer.roku.com/develop): native BrightScript/SceneGraph platform.
- [Jellyfin networking](https://jellyfin.org/docs/general/post-install/networking/): local discovery and base-path behavior.
- [Jellyfin API](https://api.jellyfin.org/): authentication, library and playback contracts.
- [Official Jellyfin Roku client](https://github.com/jellyfin/jellyfin-roku): reference for its native language, UDP discovery socket sequence, playback negotiation and packaging layout. [Its development guide](https://github.com/jellyfin/jellyfin-roku/blob/master/docs/DEVGUIDE.md) documents the device setup and installation workflow.
- [REA](https://github.com/morluto/rea): inspected as requested. It is an app-analysis toolkit, not a Roku client framework. No Apple TV binary or proprietary assets were supplied or extracted.

The user clarified that the reference was the public Jellyfin Roku ecosystem, not an existing local launcher. The official client was inspected as a behavioral reference; Luma's code and visual design were authored for this project.
