# Windows Modern — Style Specification

This document describes the visual style, color palette, and layout
decisions for the Windows Modern KDE Plasma theme. It serves as a
reference for maintaining consistency across all components.

---

## Design Philosophy

The theme targets an authentic **Windows 11** look on KDE Plasma 6.
Two variants are provided:

- **Dark** (`Windows-modern-dark`) — Win11 dark mode
- **Light** (`Windows-modern-light`) — Win11 light mode

Each variant ships matching assets for the plasma desktop theme,
aurorae window decoration, Kvantum Qt style, color scheme, and
look-and-feel package.

---

## Color Palette

### Dark variant

| Token | Hex | Usage |
|---|---|---|
| Window/panel background | `#202020` | Aurorae window decoration bg |
| Panel background (opaque) | `#1C1C1C` | Taskbar / panel fill when solid |
| Acrylic/popup background | `#2C2C2C` | Tooltips, flyouts, applet popups |
| Surface border (active) | `#3F3F3F` | Window borders, popup borders |
| Surface border (inactive) | `#2A2A2A` | Inactive window borders |
| Text (primary) | `#FFFFFF` | Title bar text, popup text, icons |
| Text (inactive) | `30,30,30 @ 50%` | Inactive title bar text |
| Highlight/accent | `#4CC2FF` | Focus indicators, links (Win11 SystemAccentColorLight2 — lighter shade for dark mode) |
| Button hover bg | `#3F3F3F` | Hover states |
| Button bg | `#2C2C2C` | Button backgrounds |
| Close hover | `#C42B1C` | Close button hover (Win11 red) |
| Close pressed | `#9E1B1B` | Close button pressed (Win11 dark red) |

### Light variant

| Token | Hex | Usage |
|---|---|---|
| Window/panel background | `#F9F9F9` | Aurorae window decoration bg |
| Acrylic/popup background | `#F9F9F9` | Tooltips, flyouts, applet popups |
| View background | `#FFFFFF` | List views, input fields |
| Surface border (active) | `#E5E5E5` | Window borders, popup borders |
| Surface border (inactive) | `#D5D5D5` | Inactive window borders |
| Text (primary) | `#1E1E1E` | Title bar text, popup text, icons |
| Text (inactive) | `153,153,153` | Inactive title bar text |
| Highlight/accent | `#0067C0` | Focus indicators, links (Win11 SystemAccentColorDark1 — darker shade for light mode) |
| Button hover bg | `#E9E9E9` | Hover states |
| Button bg | `#F3F3F3` | Button backgrounds |
| Close hover | `#C42B1C` | Close button hover (Win11 red) |
| Close pressed | `#9E1B1B` | Close button pressed (Win11 dark red) |

> Color values are sourced from the WinUI 3 (microsoft-ui-xaml)
> theme resource dictionaries.

---

## Components

### Plasma Desktop Theme

Location: `plasma/desktoptheme/Windows-modern-{dark,light}/`

Based on the Win11OS-dark plasma theme by yeyushengfan258, with all
`.svgz` files expanded to `.svg` and the following modifications:

#### Panel background (`widgets/panel-background.svg`)

- **Dark fill `#1C1C1C`** when opaque (Win11 taskbar color); dialog
  and popup backgrounds (`background.svg`) remain `#2C2C2C`.
- **No shadow** — all `shadow-*` elements set to `opacity:0`,
  `shadow-hint-*-margin` rects zeroed (width/height = 0).
- **48px panel height** supported (Win11 taskbar height) — the SVG
  hint margins scale cleanly to the taller panel; the original
  30px is also still usable.
- Three variants maintained: `widgets/`, `solid/widgets/`,
  `translucent/widgets/`.
- Light variant uses reduced border opacity (0.08 vs 0.3) for
  visibility on light backgrounds.

#### Panel layout template (`plasma/layout-templates/org.kde.windowsmodern.panel/`)

A Plasma 6 layout-template package that builds a Win11-style taskbar
when selected from **Add Panels** in the desktop context menu, or
applied via `kpackagetool6`. Installed to
`~/.local/share/plasma/layout-templates/` (or `/usr/share/` as root)
by `install.sh`.

The `contents/layout.js` creates:

- Bottom panel, 48px tall (resizable after adding; 30-32px also works
  well), `alignment=center`, `lengthMode=fill`, no auto-hide.
- Panel docked to screen edge (`floating=false`). "Applets Only"
  floating (applets inset, panel docked) cannot be set from a layout
  script — the `floatingApplets` PanelView property is not exposed in
  the Plasma scripting API, and writing it via `ConfigFile` doesn't
  work because plasmashell holds config in memory. Users must toggle
  "Floating → Applets Only" manually in Panel Settings after adding.
- Opaque background (`panel.opacity="opaque"`) — no adaptive
  translucency toggling when windows touch the panel.
- Widgets left→right:
  1. **Left expanding spacer** — `org.kde.plasma.panelspacer`. Pushes
     the Start + tasks group to the horizontal center of the panel,
     matching Win11's centered taskbar.
  2. **Start** — `org.kde.plasma.kickoff` (icon `start-here`). A custom
     Windows-logo icon is provided, with both a scalable version and a
     fixed `48/apps/start-here.svg` that draws the logo at 30px so it
     matches the app-icon size on a 48px panel.
  3. **Icon-only task manager** — `org.kde.windowsmodern.icontasks` (grouped
     by app, sits immediately to the right of Start in the centered
     group)
  4. **Right expanding spacer** — `org.kde.plasma.panelspacer`. Separates
     the centered Start + tasks group from the system tray on the far
     right.
  5. **System tray** — `org.kde.windowsmodern.systemtray`
  6. **Digital clock** — `org.kde.windowsmodern.digitalclock` (with a
      fallback to `org.kde.plasma.digitalclock`). Stacked date below the
      time, no seconds by default, `use24hFormat=1` so it follows the
      user's locale. The compact view uses `compactPadding` (default 0.18)
      so the text height matches the icon-task icon area instead of
      spanning the full panel. The expanded popup is a dark rounded
      Windows 11 calendar with month navigation, current-day blue circle,
      hover highlights, and optional KDE calendar event dots.
  7. **Show Desktop** — `org.kde.windowsmodern.showdesktop`, a custom
      forked applet (see below). Renders as a 6px-wide bare sliver with
      no icon. Click minimizes all windows; click again restores.

The template does not replace an existing panel automatically; users add it
via right-click desktop → Add Panels → "Windows Modern Panel".

In addition, each look-and-feel package ships the same layout as
`contents/layouts/org.kde.plasma.desktop-layout.js` (the file name
Plasma 6 expects for the default `org.kde.plasma.desktop` shell). When a
user applies the global theme in System Settings → Appearance → Global
Theme and chooses to use the desktop layout from the theme, Plasma
removes any existing panels and creates the Windows Modern Panel
automatically.

#### Show Desktop applet (`plasma/applets/org.kde.windowsmodern.showdesktop/`)

A simplified fork of [Zren's plasma-applet-win7showdesktop](https://github.com/Zren/plasma-applet-win7showdesktop)
(which itself forks KDE's `org.kde.plasma.showdesktop`). Stripped to
the essentials for the Win11 look:

- **Thin sliver** — `Layout.maximumWidth` is driven by the `size`
  config key (default 6px), overriding the upstream 22px floor.
- **No icon** — the `Kirigami.Icon` is only visible in edit mode.
- **Minimize-all** — uses `MinimizeAllController` (toggle minimize on
  all windows) rather than peek.
- **Win11 hover indicator** — invisible by default. On hover, a 1px
  vertical line (50% of panel height, centered) fades in at 50% text
  color alpha. No background fill, no separator line — matches Win11
  exactly.
- **No active indicator** — no overlay when windows are minimized.

Removed from the upstream fork: command controller, mousewheel volume,
peek-on-hover, openSUSE qdbus detection, `Plasma5Support.DataSource`.

Config keys (`contents/config/main.xml`): `size` (int, default 6),
`edgeColor` (string, empty = theme text color @ 50% alpha for the hover
line). Installed to `~/.local/share/plasma/plasmoids/` (or
`/usr/share/plasma/plasmoids/` as root) by `install.sh`.

#### Digital Clock applet (`plasma/applets/org.kde.windowsmodern.digitalclock/`)

A pure-QML fork of the upstream `org.kde.plasma.digitalclock`, rebranded
as `org.kde.windowsmodern.digitalclock` and redrawn with Windows 11
visuals. It reuses the upstream Plasma clock and calendar backends
(`org.kde.plasma.clock`, `org.kde.plasma.private.digitalclock`,
`org.kde.plasma.workspace.calendar`) so all KDE functionality is
preserved: time/date formatting, time zones, calendar events, week
numbers, and calendar plugins.

Win11 refinements over upstream:

- **Padded compact clock** — `compactPadding` (default 0.18) caps the
  text height so the clock visually matches the icon-task icon area
  instead of spanning the full panel height. Works with both Automatic
  and Manual text display modes.
- **Theme-aware rounded popup** — the popup fill, border and shadow are
  supplied by the Plasma theme's `dialogs/background.svg`
  (`#2C2C2C`/`#F9F9F9` fill with `#3F3F3F`/`#E5E5E5` border), 8px corner
  radius, sized by `expandedWidth` (default 320px). Text colors come
  from the Win11 palette via `Win11Palette`.
- **Win11 time header** — large seconds-capable time with AM/PM rendered
  smaller and raised, plus a locale-aware "dddd, MMMM d" date line.
- **Win11 calendar grid** — month/year header with custom chevron
  buttons, localized day-of-week header, 6-week grid, current day as a
  solid accent circle (`#4CC2FF` dark / `#0067C0` light), hover/pressed
  rounded rectangles (`#3F3F3F`/`#E9E9E9`), selected day as a subtle
  rounded rectangle (`#2C2C2C`/`#F3F3F3`), and previous/next month days
  dimmed. Days scale slightly when pressed and colors animate.
- **Event dots** — small colored dots under days that have events from
  enabled KDE calendar plugins; hovering a day with events shows a
  tooltip with the event summaries.
- **Dynamic navigation** — mouse wheel over the grid flips months, arrow
  keys move the selection, Page Up/Down flips months, Home jumps to
  today, and clicking a day from the previous/next month jumps to that
  month. Month changes cross-fade.
- **Time zone list** — shown in the popup when multiple time zones are
  configured.

Removed interactions: pin on middle-click, calendar launch,
clipboard time copy, and wheel-to-switch-timezone.

Config keys are the same as upstream plus `compactPadding` (double)
and `expandedWidth` (int). Build and install with
`./install.sh digitalclock`.

#### System Tray applet (`plasma/applets/org.kde.windowsmodern.systemtray/`)

A C++ fork of the upstream Plasma system tray, rebranded as
`org.kde.windowsmodern.systemtray` and restyled with Windows 11 visuals.
It is a full `Plasma::Containment`, so child applets (network, volume,
battery, clipboard, notifications, etc.) appear and disappear
automatically. The QML UI is embedded in the compiled `.so`; a separate
KPackage must not be installed (it causes the dark-rectangle popup bug).
See `docs/SYSTEMTRAY_ARCHITECTURE.md` and
`plasma/applets/org.kde.windowsmodern.systemtray/BUILD.md`.

#### Icon Tasks applet (`plasma/applets/org.kde.windowsmodern.icontasks/`)

A C++ fork of the upstream `org.kde.plasma.taskmanager` (from
plasma-desktop), packaged under `org.kde.windowsmodern.icontasks` while
using the runtime plugin ID `org.kde.windowsmodern.icontasks`, and restyled with
Windows 11 tooltip visuals. The C++ backend is preserved
unchanged (jump lists, places, recent docs, app categories, smart
launcher badges, audio stream matching). The QML UI is forked from
upstream with minimal Win11 refinements:

- **Always icons-only** — `iconsOnly` hardcoded to `true`.
- **Hidden subtext in thumbnail mode** — desktop/activity info ("On
  Desktop 2") is hidden when a window thumbnail is visible (Win11
  behavior — it's noise when the preview already shows the window).
- **Subtle close button** — replaces the upstream `PlasmaComponents3.ToolButton`
  with a minimal X icon pinned to the far right of the header row. Background is
  transparent by default and turns Win11 red `#C42B1C` on hover; pressed is
  `#9E1B1B`.
- **Rounded thumbnail corners** — PipeWire thumbnail clipped to 8px
  rounded corners via `OpacityMask` (Win11 thumbnails are rounded).

No font is forced — the global `Kirigami.Theme.defaultFont` is used
throughout, matching the rest of the desktop.

The QML UI is embedded in the compiled `.so`; a separate KPackage must
not be installed. Build and install with `./dev.sh` or
`./install.sh icontasks`. See
`plasma/applets/org.kde.windowsmodern.icontasks/BUILD.md`.

The panel layout template and look-and-feel layout scripts target the compiled
runtime ID `org.kde.windowsmodern.icontasks` and fall back to the stock
`org.kde.plasma.taskmanager` when the custom plugin is unavailable.

#### Popups / tooltips

The following files were rewritten as clean 9-patch SVGs with
authentic Win11 colors (replacing the original hardcoded light
color schemes that caused unreadable white popups on dark theme):

| File | Purpose | Corners | Margin hints |
|---|---|---|---|
| `widgets/tooltip.svg` | Hover tooltips | 8px radius, 1px Fluent stroke | 8px |
| `dialogs/background.svg` | Dialog/popup backgrounds | 7px | 8px |
| `widgets/background.svg` | Applet/widget backgrounds | 7px | 8px |
| `widgets/translucentbackground.svg` | Translucent applet popups | 7px | 8px |

All four exist in both `widgets/`, `solid/widgets/`, and
`translucent/widgets/` as needed, with consistent colors.

Tooltips use a **subtle 1 px Fluent stroke** baked into the 9-patch
edge/corner tiles (dark: white `#14FFFFFF`, light: black `#14000000`)
to avoid the double-border artifact caused by an SVG `stroke`
against the tooltip window edge. The fill matches the acrylic/popup
spec for the default and translucent variants (`#2C2C2C` dark,
`#F9F9F9` light) while solid fallbacks keep `#323130` dark and use
`#F0F0F0` light. The soft outer drop shadow is 8px deep (matching the
8px corner radius so the shadow curves around the rounded body rather
than forming a square frame) at 0.16 dark / 0.14 light opacity for a
Win11 elevation penumbra.

#### Slider (`widgets/slider.svg` + Kvantum)

System-wide slider styling across Plasma applets and Kvantum (Qt apps).
The system tray flyout uses the default `PlasmaComponents3.Slider`, which
inherits the themed look.

| Element | Dark | Light |
|---|---|---|
| Filled track | `ColorScheme-Highlight` = `#4CC2FF` (luminous cyan) | `ColorScheme-Highlight` = `#0067C0` (royal blue) |
| Unfilled track | `ColorScheme-Text` @ 25% opacity (medium grey) | `ColorScheme-Text` @ 25% opacity (medium-dark grey) |
| Knob outer ring | `ColorScheme-Background` (dark grey) | `ColorScheme-Background` (white) with `#D5D5D5` border |
| Knob inner circle | `ColorScheme-Highlight` (cyan) | `ColorScheme-Highlight` (royal blue) |
| Hover/focus glow | `ColorScheme-Highlight` @ 20-30% opacity | `ColorScheme-Highlight` @ 20-30% opacity |

- **Kvantum** — `slider_width=4`, `slider_handle_width=16`. The
  `slidercursor-*` SVG elements render the two-circle knob (outer ring
  + inner accent). Groove elements use solid fills (`slider-normal-*`
  for unfilled, `slider-toggled-*` for filled).
- **Plasma theme** — `widgets/slider.svg` uses the same two-circle
  knob design. Both groove and knob use `ColorScheme-*` CSS classes
  with `fill="currentColor"` — the filled track and knob inner circle
  use `ColorScheme-Highlight`, the unfilled track uses `ColorScheme-Text`
  at 25% opacity, and the knob outer ring uses `ColorScheme-Background`.
  This makes the slider automatically follow the per-variant accent
  without hardcoded hex values.

#### Switch / toggle (`widgets/switch.svg`)

Renders the on/off toggle switches used in Plasma applet popups
(e.g. network, Bluetooth, do-not-disturb). The original asset made
the off-state track and thumb the same color as the popup
background, so the switch was invisible against popups.

| Element | Class | Notes |
|---|---|---|
| Off track fill | none (transparent) | Pill outline only |
| Off track border | `ColorScheme-Text` | 1 px stroked outline, `stroke-linecap=round` for seamless joints |
| On track fill | `ColorScheme-Highlight` | Solid accent from the color scheme |
| On track border | none | Filled pill, no visible stroke |
| Knob (both states) | `ColorScheme-Text` | Same color as text — visible on both transparent off-track and accent on-track |
| Knob border | none | Flat, borderless |
| Focus/hover ring | `ColorScheme-Highlight` | 12 px accent ring around the 10 px knob |

- Both states share the same outer track size (38 × 16 px hint) and knob.
- The off track is a **transparent pill outline** stroked in
  `ColorScheme-Text` — no fill, so the popup background shows through.
  `stroke-linecap=round` ensures the 9-patch arc/line joints are seamless.
- The on track is a **solid accent pill** with no border.
- The knob uses `ColorScheme-Text` so it is always visible: white in
  dark mode (on blue track) and dark in light mode (hole effect on
  blue track).
- The knob is 10 px inside a 16 px handle bounding box, giving 3 px
  transparent padding on all sides so it never touches the track edge.

#### Taskbar (`widgets/tasks.svg`)

Rendered by the Windows Modern `org.kde.windowsmodern.icontasks` applet (the panel
layout template uses it). The SVG supplies the hover/focus background
 visuals:

| State | Dark | Light |
|---|---|---|
| Hover fill | `#0FFFFFFF` (~6% white) | `#09000000` (~3.5% black) |
| Hover border | `#08FFFFFF` (~3% white) | `#08000000` (~3% black) |
| Focus/pressed fill | `#17FFFFFF` (9% white) | `#17000000` (9% black) |
| Corner radius | 4 px | 4 px |
| Border thickness | 1 px | 1 px |

- **Group expander removed** — the `group-expander-*` groups (white
  circle with `+` icon) are emptied. Windows 11 does not show a plus
  indicator on grouped taskbar buttons.
- **Inactive app indicator `#858585`** — the running-indicator strip
  under normal/minimized task buttons uses solid `#858585` at full
  opacity in both dark and light variants. Active/hover indicators
  use the per-variant accent (`#4CC2FF` dark / `#0067C0` light).

> Note: upstream `icontasks` is now a compiled C++ plugin, so exact
> 40×40 px hover-box sizing and a separate mouse-down pressed state can
> only be controlled from the SVG/theme level. The values above are the
> closest match using the Plasma desktop theme.

#### Icons

Location: `icons/windows-modern/` (gitignored because of its size)

Curated Windows-11-style icon theme assembled from multiple upstream packs and
restructured into a clean freedesktop context layout. The current repository
contains 4,958 SVG assets under the ten context directories listed in
`index.theme`. All ten directories are declared as scalable SVG contexts, so
the index does not advertise synthetic `@2x` directories that do not exist on
disk. The icon cache is rebuilt at install time when the cache utility is
available.

## Install / Uninstall

### Install

Interactive menu (recommended for first install):

```sh
./install.sh
```

Install everything non-interactively:

```sh
./install.sh all
```

Install individual components:

```sh
./install.sh themes      # Aurorae, colors, Kvantum, Plasma themes, wallpapers
./install.sh icons       # Icon pack
./install.sh lookfeel    # Global themes
./install.sh layout      # Panel layout template
./install.sh showdesk    # Show Desktop applet
./install.sh systray     # System Tray applet (C++ — see below)
./install.sh applets     # All four applets
```

Copies all themes to `~/.local/share/` (user) or `/usr/share/` (root),
then automatically sets `BorderSize=Tiny` in kwinrc and reconfigures
KWin so window decorations have no extra padding.

### System Tray

The System Tray applet is a compiled C++ Plasma::Containment. Install it
with:

```sh
./install.sh systray
```

This builds the `.so`, removes any conflicting KPackage, prunes stale
local copies, and restarts `plasmashell`. Build dependencies are listed
in `plasma/applets/org.kde.windowsmodern.systemtray/BUILD.md`.

### Uninstall

```sh
./uninstall.sh all       # Remove everything
./uninstall.sh themes    # Remove theme components
./uninstall.sh icons     # Remove icon pack
./uninstall.sh systray   # Remove system tray plugin
# ... etc.
```

Removes theme directories and resets `BorderSize` to `Normal`.

---

## Repository Structure

```
windows_modern2/
├── aurorae/
│   ├── windows-modern-dark-aurorae/     # Dark window decoration
│   └── windows-modern-light-aurorae/    # Light window decoration
├── color-schemes/
│   ├── WindowsModernDark.colors
│   └── WindowsModernLight.colors
├── Kvantum/
│   └── Windows-modern/                   # Kvantum Qt style (light + dark variants)
├── icons/
│   └── windows-modern/                   # Curated Win11 icon theme (gitignored)
├── plasma/
│   ├── applets/
│   │   ├── org.kde.windowsmodern.showdesktop/     # Win11 thin-show-desktop sliver
│   │   └── org.kde.windowsmodern.systemtray/      # Win11 system tray
│   ├── desktoptheme/
│   │   ├── Windows-modern-dark/         # Dark plasma theme (165 SVGs)
│   │   └── Windows-modern-light/        # Light plasma theme (165 SVGs)
│   ├── layout-templates/
│   │   └── org.kde.windowsmodern.panel/ # Win11 centered taskbar layout
│   ├── look-and-feel/
│   │   ├── org.kde.windowsmodern.dark/  # Dark global theme
│   │   └── org.kde.windowsmodern.light/ # Light global theme
│   └── shells/
├── wallpaper/
├── docs/
│   └── STYLE.md                         # This file
├── install.sh
├── uninstall.sh
└── README.md
```

---

## Credits

- Plasma desktop theme based on [Win11OS-kde](https://github.com/yeyushengfan258/Win11OS-kde)
  by yeyushengfan258 (GPL 3.0).
- Win11 color values verified from
  [microsoft-ui-xaml](https://github.com/microsoft/microsoft-ui-xaml)
  theme resources.
- Kvantum theme based on [Fluent-kde](https://github.com/vinceliuice/Fluent-kde)
  by vinceliuice.
- **[mjkim0727](https://github.com/mjkim0727/Eleven-icon-theme)** —
  **Eleven** icon pack.
- **[vinceliuice](https://github.com/vinceliuice/Fluent-icon-theme)** —
  **Fluent** icon pack.
- **[Zren / Chris Holland](https://github.com/Zren)** — upstream Show
  Desktop applet (`win7showdesktop`).
- Window decoration, popup SVGs, icon curation, applets, and integration
  by Jeysef.
- Additional icon pack sources are credited in
  [`ATTRIBUTION.md`](ATTRIBUTION.md).

## License

GNU GPL v3
