# Design and implementation

lyridec is a native DMS desktop plugin. `src/Lyridec.qml` adapts shell settings and theme roles; `src/components/LyricsView.qml` contains the interface without DMS imports. A shared `src/services/LyricsService.qml` follows Spotify through MPRIS, resolves lyrics and owns persistent storage. `src/Lyrics.js` contains parsing and timing logic.

## Reading and interaction

Lyrics fill the panel. Hover or keyboard navigation reveals track identity, options, source and time without changing the lyric viewport. Options, search and file selection keep controls visible. There is no cover thumbnail or playback transport.

Reading view anchors the first visual line of the active phrase at 30% of viewport height. Wrapped lines retain the same font weight so line changes do not alter wrapping. Current, next, previous and distant phrases use 100%, 43%, 30% and 22% opacity. Scrolling suspends following and exposes **Back to current line**. Plain text remains readable without implying synchronization or seeking.

The default size is 440 × 520; the minimum is 320 × 300. Lyric size is adjustable from 18–44 px. DMS supplies the font and palette, with reduced saturation for the main surface and lyric text. Options and state messages scroll when necessary.

## Glass and motion

The compiled Qt shader draws a 24 px rounded contour with an 18 px refracted rim. Three samples of a 192 × 192 artwork texture supply edge distortion and subtle color separation. Text and controls render above the material.

**Glass intensity** scales refraction, reflections, artwork tint and the difference between edge and center opacity. At 0%, these effects and the widget's blur request are off. **Background opacity** controls the surface separately. Unsupported graphics rendering falls back to a plain rounded surface.

DMS's `WindowBlur` requests a rounded native blur region. The compositor chooses what is sampled beneath the window; the Niri rule in README.md disables wallpaper-only xray for lyridec. Refraction inside the widget samples artwork, not other application windows.

The glass has no animation timer. Following animates for 280 ms for nearby lines; longer jumps are immediate. Context fades take 220 ms and controls take 180 ms. Reduced motion removes those transitions and the loading spinner.

## States and accessibility

Idle explains how Spotify starts the display. Loading shows recording identity, a small busy indicator and lyric-shaped placeholders. Missing lyrics offer search and import. Errors preserve the service's explanation and offer retry or search. Instrumental status is presented as the source's classification, with an option to find another version.

Controls have accessible names, keyboard focus indicators and tooltips for icons. Arrow keys, Page Up/Down, Home and End browse lyrics. Search focuses its text field; Escape returns to lyrics. Hover disclosure does not move click targets. No solid backdrop is drawn over the glass behind the header or footer.

## Validation

`make check` covers parsing, timing, view interaction and service behavior using synthetic data and a private D-Bus session. `make check-glass` verifies shader/source consistency and renders seventeen scenes, including minimum-size states and 0%, 50% and 100% intensity. The final three images have identical content and must render differently.

Preview lyrics, titles and search results are synthetic. Optional preview artwork comes from `LYRIDEC_PREVIEW_ART`; it is not bundled. Captures are development artifacts and are excluded from Git and installation. Rendering tests do not prove live network behavior or every compositor, font and display scale.
