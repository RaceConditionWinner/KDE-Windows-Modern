# System Tray — Architecture & History

## Overview

The Windows Modern system tray (`org.kde.windowsmodern.systemtray`) is a C++ `Plasma::Containment` fork of the upstream plasma-workspace system tray. It replaces the default `org.kde.plasma.systemtray` with identical Plasma containment behavior — child applets (network, volume, battery, clipboard, etc.) are managed by the containment and appear/disappear automatically.

---

## Architecture

```
┌─────────────────────────────────────────────┐
│  Panel (org.kde.panel)                      │
│  ┌───────────────────────────────────────┐  │
│  │  System Tray (CustomEmbedded)         │  │
│  │  ├─ PlasmoidItem (network)            │  │
│  │  ├─ PlasmoidItem (volume)             │  │
│  │  ├─ PlasmoidItem (battery)            │  │
│  │  ├─ PlasmoidItem (notifications)      │  │
│  │  ├─ StatusNotifierItem (Discord)      │  │
│  │  ├─ StatusNotifierItem (Steam)        │  │
│  │  └─ ...                               │  │
│  └───────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

### Key Components

| File | Purpose |
|------|---------|
| `systemtray.cpp/.h` | C++ `Plasma::Containment` — manages child applets, DBus model, XDG activation |
| `contents/ui/main.qml` | Root `ContainmentItem` — GridView of active icons, AppletPopup, ExpanderArrow |
| `contents/ui/SystemTrayState.qml` | State machine — expanded/collapsed, active applet tracking |
| `contents/ui/ExpandedRepresentation.qml` | Popup content — heading, PlasmoidPopupsContainer, HiddenItemsView |
| `contents/ui/PlasmoidPopupsContainer.qml` | StackView for child applet FullRepresentations |
| `contents/ui/PlasmoidItem.qml` | Wrapper for each child applet icon — handles click/tooltip/context menu |
| `contents/ui/ExpanderArrow.qml` | Chevron toggle for hidden items popup |

### Data Flow

```
Plasmoid.systemTrayModel (C++ multi-source model)
  ├─ PlasmoidModel (embedded plasmoids)
  ├─ StatusNotifierModel (SNI via DBus)
  └─ BackgroundAppsModel (flatpak/background)
       │
       ▼
  KSortFilterProxyModel
  ├─ activeModel (ActiveStatus → panel icons)
  └─ hiddenModel (PassiveStatus → expander popup)
```

### Popup Mechanism

```
User clicks icon
  → PlasmoidItem.onActivated → applet.Plasmoid.activated()
  → applet.expanded = true (framework event)
  → Instantiator detects onExpandedChanged
  → SystemTrayState.setActiveApplet(applet)
  → systemTrayState.expanded = true
  → root.expanded = true (containment sync, triggers framework child-embedding)
  → dialog.visible = true (QML AppletPopup opens)
  → PlasmoidPopupsContainer shows applet.fullRepresentationItem
```

The `rootConnections` block in SystemTrayState.qml (matching upstream exactly) keeps the containment's `expanded` property in sync with `systemTrayState.expanded`. This is part of the correct Plasma containment contract — it doesn't fix the dark rectangle (see below for the actual fix).

```qml
readonly property Connections rootConnections: Connections {
    function onExpandedChanged() {
        if (systemTrayState.acceptExpandedChange) {
            systemTrayState.expanded = root.expanded  // user-initiated
        } else {
            root.expanded = systemTrayState.expanded  // suppress framework
        }
    }
}
```

---

## Installation

The applet is a C++ plugin loaded from a shared library (`.so`). It is deployed as a compiled Plasma applet with embedded QML and embedded JSON metadata. A full KPackage directory containing `contents/ui` must not be installed because it creates a second implementation of the same plugin ID and can reproduce the dark-rectangle popup bug.

```bash
# Build and deploy
./dev.sh

# Or from the repository root
./install.sh systray
```

`dev.sh` resolves the Qt6 plugin directory with `qtpaths6` when available, then `pkg-config`, and finally a small set of standard fallback locations. The resulting library is installed under `<Qt6 plugin dir>/plasma/applets/`.

The QML files are embedded in the `.so` via `ecm_target_qml_sources`; the plugin also embeds `metadata.json` through `K_PLUGIN_CLASS_WITH_JSON`. The layout scripts use Plasma's current `knownWidgetTypes` API before calling `addWidget()` and fall back to the stock system tray when the compiled plugin is not discoverable.

## Critical Bug: Duplicate KPackage Installation

### Symptom

A dark rectangle appeared alongside the system tray popup when clicking individual icons.

### Root Cause

The old implementation installed the same applet ID both as a compiled plugin and as a full QML KPackage. That created duplicate applet registrations and could route child-applet embedding through the package instance.

### Current Plasma 6 deployment model

The Windows Modern tray is intentionally a compiled applet plugin only. Its QML is embedded into the `.so`, and its JSON metadata is embedded into the plugin. No full `contents/` KPackage copy is installed.

Do not reintroduce a package directory containing `contents/ui` for this applet. The runtime must have one implementation of the plugin ID.

### Local plugin shadowing

A stale copy of the plugin at `~/.local/lib*/qt6/plugins/plasma/applets/org.kde.windowsmodern.systemtray.so` can shadow the system-installed copy on some Qt setups. The installer removes known local copies automatically. If manual cleanup is required, remove stale local copies and restart Plasma.

### Theme layout compatibility

The current Plasma scripting API exposes `knownWidgetTypes` as the installed-widget capability list. Windows Modern checks that list before adding the custom tray and falls back to `org.kde.plasma.systemtray` if the custom plugin is unavailable.

## History: Original Windows 11-Style Custom Tray (v0)

Before the C++ containment fork, the system tray was a pure-QML plasmoid with a custom Windows 11-style design. The code is documented below for historical reference.

### Visual Design

**Panel Tray (CompactRepresentation)**
```
┌────┬────┬────┬────┬────┬────┐
│  ^  │  ♫  │  ⎘  │  ⚡  │  🔔  │  🔋  │
│hidden│media│clip │devices│notif│battery│
└────┴────┴────┴────┴────┴────┘
```
- Row of icon buttons with hover/press highlight effects
- Each button: rounded Rectangle with semi-transparent white overlay on hover/press
- `Kirigami.Icon` with symbolic variants and `T.ToolTipArea` tooltips
- Optional media player icon (visible only when MPRIS player is active)
- Hidden icons chevron rotates when popup is open (180° animation)
- Per-icon right-click context menus via `Plasmoid.contextualActions`

**Popup (FullRepresentation)**
```
┌──────────────────────────────┐
│  HIDDEN ICONS          ✕     │  ← header with label
│  ┌───┐ ┌───┐ ┌───┐ ┌───┐   │
│  │ 🎮│ │ 💬│ │ 📡│ │ 🖨│    │  ← GridView of hidden SNI icons
│  └───┘ └───┘ └───┘ └───┘   │
└──────────────────────────────┘
```
- `StackLayout` with pages: TrayIcons, Clipboard, Devices, Notifications, Battery, MediaPlayer
- Each page: header label + content area with ListView/GridView
- Pages toggle on re-click (click clipboard icon → show clipboard page, click again → close)
- Context menus dynamically rebuilt based on hovered icon

**Page Details**

| Page | Content | Data Source |
|------|---------|-------------|
| TrayIconsPage | GridView of hidden SNI icons with tooltips | `SniModel` (DBus: `org.kde.StatusNotifierWatcher`) |
| ClipboardPage | List of clipboard entries, clear button | Klipper via DBus |
| DevicesPage | Removable devices with mount/unmount/eject | UDisks2 via DBus |
| NotificationsPage | Notification list with clear all | `NotificationManager` QML model |
| BatteryPage | Percentage, progress bar, health, sleep/lock inhibitor | `powermanagement` engine + UPower |
| MediaPlayerPage | Album art, track info, play/pause/prev/next | MPRIS via DBus (`org.mpris.MediaPlayer2.Player`) |

**Reusable TrayButton component**
```qml
component TrayButton : Item {
    Rectangle {  // hover/press background
        radius: 4
        color: containsPress ? Qt.rgba(1,1,1,0.12)
             : containsMouse ? Qt.rgba(1,1,1,0.08)
             : "transparent"
    }
    Kirigami.Icon { anchors.centerIn: parent }  // icon
    PlasmaCore.ToolTipArea { }                   // tooltip
    MouseArea { hoverEnabled: true }             // interaction
}
```

### Why It Was Replaced

The pure-QML custom tray had limitations:
- **SNI polling**: `SniModel` used a 5-second polling timer to query DBus, causing latency
- **No applet containment**: Icons were hardcoded buttons, not real Plasma applets. Network/volume/bluetooth couldn't be managed by the tray — they appeared as separate panel items
- **Limited SNI support**: Basic SNI activation only; no per-item visibility config, no keyboard shortcuts, limited context menu integration
- **UI inconsistency**: Custom pages didn't match Plasma's standard popup behavior (pin, floating, border removal)

The C++ fork replaced this with a full `Plasma::Containment` based on the upstream plasma-workspace system tray, providing proper applet containment, event-driven SNI, and full Plasma integration. The old custom QML was removed for cleanliness — visual documentation is preserved above.
