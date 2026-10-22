# Try Luma before installing it on your TV

## Start the browser preview

Use Node.js 24 or newer, then run these commands from the repository:

```sh
npm ci
npm --prefix preview ci
npm run dev
```

Open **http://127.0.0.1:5173**. Keep the terminal running. `Ctrl+C` stops both the preview and its local Jellyfin gateway. `npm run doctor` checks dependencies, network interfaces, and both local services.

The first screen finds your Jellyfin server and asks you to sign in. After sign-in, Home displays your real collection. Sample films appear only after an explicit demo choice; a disconnected server never silently replaces your library with demo content. The preview uses mouse/touch and keyboard remote navigation. Use arrow keys to move, Enter to select, and Escape to go back. Browser fullscreen helps approximate a TV.

On first launch, select your server on the connection screen. You can also open it from Settings later. The PC must be awake, Jellyfin must be running, and both devices must be on the same local network. Select the server and sign in once. If discovery finds nothing, enter its full URL, including a configured base path, such as `http://my-pc:8096/jellyfin`.

The preview's access token is stored locally by the gateway in ignored `server/.local/session.json`. The Roku app has its own device session; signing into the browser does not provision the TV.

## Check the feature that matters most

1. Connect to your actual server and open a title.
2. Reload the preview: the account should remain connected.
3. Stop Jellyfin or shut down the PC. Retry the connection; the account should remain remembered while unavailable.
4. Start the PC again. If DHCP gave it a different address, use Retry/reload. Discovery should identify the same server and reconnect without a password.
5. If a different Jellyfin server occupies the old address, Luma must not use your saved token against it.

An administrator revoking the device session, deleting the user, or replacing the Jellyfin installation with a new server identity legitimately requires signing in again. A plain IP change does not.

## Saved sign-in

Sign in once. Luma stores the server's identity, its access token and (on the Roku) your Jellyfin username and password in the channel's private registry. If Jellyfin ever drops the session (a revoked device, an expired token), Luma checks it is still talking to the same server and silently signs in again with the saved credentials, then retries what you were doing. You only see the sign-in screen if the password itself changed. **Ajustes → Sair da conta** removes the token and password from the TV.

## One press to watch

As on Apple TV, OK on an episode card (Continue Watching, a show's season rail) or on a movie you already started plays it right away; new movies and shows open their page. The remote's Play key starts any movie or episode card. Back from the player returns to the same shelf. On a show page, the main button plays Jellyfin's next-up episode.

## Ambient mode

After three minutes without remote input outside playback, Luma fills the screen with your library's artwork: random movie and show backdrops crossfade every 12 seconds with a slow drift, the title logo, genre and year, and the time and date. Any key returns to exactly where you were; that key is not passed on. Roku forbids normal channels from providing the *system* screensaver, so the TV's own screensaver still starts at the delay set in Roku Settings; set it to 5 minutes or longer, or "Off", to keep seeing Luma's.

## Posters

A show's poster follows its newest season when that season is season 2 or later and has its own art in Jellyfin (e.g. Cyberpunk: Mercenários Season 2). The Séries library is ordered by the most recently added episode, so a new season puts its show first. Wide artwork (Home cards and show-page backgrounds) still comes from the show's backdrop because Jellyfin has no per-season backdrops here; to change it, pick a new backdrop for the show in Jellyfin (Edit images).

## Skip intro

Luma asks Jellyfin where the intro, recap and credits are, in this order: the built-in **MediaSegments** API (Jellyfin 10.10+, fed by the Intro Skipper plugin, which this server already runs), the older Intro Skipper endpoints, then chapters named *Intro/Opening/Abertura* or *Credits/Créditos*. The lookup runs after the video starts, so it never delays playback.

When an intro starts, a white **Pular abertura** pill rises from the bottom edge over a dark gradient and takes focus: press OK once to jump to the end of the intro, whether or not the controls are showing. Play/Pause still pauses, Left/Right still rewind and advance, and Up reaches the timeline. If you rewind into an intro, the pill appears without taking focus; press Down to reach it. Recaps say **Pular recapitulação**; mid-file credits **Pular créditos**. Credits that run to the very end are not offered, since skipping them would just end the episode.

## Titles on the tiles

Like Apple TV, every landscape tile on Home carries the title's logo in its lower-left corner over a soft shade, so a row reads at a glance. Continue Watching episodes show the show's logo on the episode still, with "T2, E1 · episode" underneath. Titles without a logo show their name in the same place. Library posters already carry their title, and a show's own season rails stay plain.

## Next episode and remembered tracks

When an episode's end credits start (or its last 20 seconds, if Jellyfin has no credits marker), the next episode's picture and number rise above a **Próximo episódio em 10** pill that counts down. At zero, or when the file ends, the next episode starts by itself; one OK starts it at once, crossing into the next season when needed. Back hides the offer and lets the credits play. After three episodes in a row with nobody touching the remote, Luma waits for OK instead of continuing. Seeking or scrubbing into the credits never brings it up: it appears only when the episode itself plays into them. The finished episode is reported as stopped and the new one starts from its beginning (or where you left it). Credits followed by more story still say **Pular créditos**, and the last episode of a series offers nothing.

Audio and subtitle choices are remembered per series. Pick English audio and Portuguese subtitles once, and every later episode of that show starts with them, whether you open it from Continuar assistindo, the show page or **Próximo episódio**. Tracks are matched by language and name, since the same subtitle can have a different number in each episode; if an episode lacks that language, it keeps Jellyfin's default. Choosing **Desativadas** is remembered too. Original and Máxima quality keep the defaults they can play unchanged. The 20 most recent series are remembered.

## Scrubbing

Tap Right/Left to jump 10 seconds. Hold to scrub: it starts at 10 seconds per step and keeps speeding up while held, faster on long films, and a thumbnail above the playhead shows where you will land. Thumbnails come from Jellyfin's trickplay images, which the server is generating for the whole library (about a day, ~1.6 GB); titles not processed yet scrub without a picture.

## Cast and similar titles

Movie and show pages end with **Elenco e equipe** (round photos with each person's character or job) and **Mais como este**. OK on a person opens their page: biography, and the titles from your library they appear in.

## Library filters

In Filmes or Séries, press Left from the posters to reach the library column. Pick **Filmes**, **Séries** or **Coleções**, then **Ordenar por** (date added, A–Z, release year), **Gênero** and **Não assistidos**. The posters reload while focus stays in the column. Coleções lists Jellyfin collections; this server has none yet. To have Jellyfin build them, enable automatic collections for the Movies library (or create one under a movie's ⋯ menu).

## Profiles

If you sign in as the server's administrator, Ajustes (or the remote's ✱ key) offers **Trocar perfil** with every user on the server. A profile asks for its password the first time only; after that, switching is instant, including back to yours. Other people's profiles never see this option unless the administrator has signed in on this Roku. **Sair da conta** removes all saved profiles for the server.

## Try the playback controls

The player follows Apple TV's layout: episode and title lower left, round Audio/Subtitles/Quality buttons above the right end of the timeline (Version appears only when an item has several files), elapsed time under the playhead, and a Capítulos pill below the timeline when the item has chapters. Press Up from the timeline for the round buttons; menus open upward from the button.

Open a title with multiple audio/subtitle tracks and resume playback. Reveal the player controls, then use the separate audio and captions buttons. The captions list includes Off; the settings menu offers quality and, when available, file versions. Chapters appear only when the item has chapter metadata.

Pause before changing audio, then choose 720p and a subtitle. The player should stay paused at the same position with the other choices retained. Resume to check the actual picture, sound and subtitle timing. Try Off and confirm the text disappears. Use Back/Escape to close a menu before leaving playback.

Quality options cap resolution and bitrate while preserving the video's aspect ratio. Browser Original retains source resolution, with codec conversion when necessary. Roku Original means compatible direct play and can reject combinations that require conversion; choose Auto for those files. Subtitle rendering and compatible output depend on the PC's transcoding capability.

## Direct home-network connection

Tailscale is not needed when this Mac and the Jellyfin PC share a reachable LAN. Automatic discovery uses private LAN interfaces and excludes known tunnel adapters. A manually entered VPN URL is still supported if deliberately chosen. Luma does not change system VPN settings.

For this installation, the PC was verified directly through the Mac’s `en0` interface at `http://192.168.1.50:8096`. Authenticated Home, Movies, and Shows requests returned the real library, and a real movie and episode played at 1920×1080 in Chrome. The reported playback error was reproduced and fixed: Jellyfin's dashed video IDs are now recognized as equivalent to the compact IDs in its item metadata. This is a verified current address, not a hardcoded server address; subsequent DHCP changes are handled by saved server identity and rediscovery.

## Local discovery troubleshooting

- Allow **UDP 7359** to Jellyfin for discovery and its HTTP port (normally **TCP 8096**) for the API and video.
- Use the same local subnet. Guest Wi-Fi/client isolation, a VPN, or container networking can block broadcasts.
- In Docker, make sure discovery traffic reaches the container and the advertised Jellyfin address is reachable from the LAN.
- When UDP is silent, Luma also checks nearby private-network addresses through Jellyfin's public HTTP identity endpoint. A manual URL remains an escape hatch for custom ports, base paths, and larger or segmented networks. A DHCP reservation or stable local hostname is also useful, but ordinary IP changes should not require one.
- Do not configure Internet port forwarding for this home-network feature.

See [Jellyfin's network documentation](https://jellyfin.org/docs/general/post-install/networking/) for the current port and base-path behavior.

To check the API routes advertised by your actual server without signing in:

```sh
npm run check:server -- http://your-jellyfin:8096
```

Luma uses the current `/Items`, `/Items/Latest`, and `/UserItems/Resume` routes. This matters on Jellyfin 12.2, where older user-prefixed library routes are no longer advertised. The route check does not access private library data or verify credentials.

## Build and install the native Roku app

Before sideloading, run `npm run simulate:roku` on this Mac and open **http://127.0.0.1:8090/**. This executes the native channel in BrightScript Desktop Simulator. The [simulator guide](roku-simulator.md) explains the current release's discovery limitation and which checks still require hardware.

```sh
npm run check:roku
npm run build:roku
```

The package is **`dist/luma.zip`**, a native BrightScript/SceneGraph channel independent of the browser preview.

When ready to test on the TV:

1. Enable Roku developer mode with **Home ×3, Up ×2, Right, Left, Right, Left, Right**.
2. Follow the TV prompts to enable the installer and choose a development password.
3. Open the TV's current IP in your browser, then sign in as `rokudev` with that password. Read the current address from the TV; the screenshot's address can change too.
4. Upload the generated ZIP using the Development Application Installer.
5. Discover Jellyfin, sign in, and repeat the PC restart test.

Roku has one sideloaded development-app slot; uploading Luma replaces whatever development app is currently in that slot. Store-installed apps are separate. Follow [Roku's developer setup guide](https://developer.roku.com/dev/docs/developer-setup).

## What still needs the real TV

A browser preview is a usability preview, not a Roku hardware emulator. BrighterScript compilation and package validation catch syntax, component, and packaging problems, but they do not prove native rendering or decoder behavior.

On the Philco PTV58G70R2CSGBL4K / Roku OS 16, test:

- Remote focus, Back navigation and keyboard entry at normal viewing distance.
- A resumed movie and a TV episode, including season/episode navigation.
- H.264/AAC video and your typical HEVC/4K files. Auto preserves verified-compatible HEVC up to 4K/HDR10 and uses bounded H.264/stereo fallback; Original only offers unchanged playback supported by the device. Confirm capability-gated 4K on the actual TV.
- Audio, text and image subtitles, Off, quality changes, version selection and chapter navigation. Repeat a change while paused and after resuming well into a movie.
- Seek, pause, exit, relaunch, and Jellyfin's recorded resume position.
- An offline PC, a changed server IP, and a revoked access token.

Playback is only verified for the environments and media actually exercised. Treat unsupported codecs or subtitle combinations as test findings rather than assuming browser success proves TV support.
