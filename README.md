# Cat

A small Quickshell shell for Hyprland, inspired by Omarchy's restrained,
monospaced desktop. A slim bar, compact panels, and one palette file.

## Included

- A bar on every monitor: a square active-workspace marker, numbered
  workspaces, active window title, clock, tray, and matching vector icons for
  network, volume, and battery/power. Clipboard and notification panels
  are accessible through keybindings, without buttons on the bar.
- A volume popup with a slider and mute control, a battery/power popup with
  available power profiles, and a Wi-Fi popup with nearby networks and
  password entry.
- An app launcher with icons, keyword search, arrow-key navigation, and
  support for terminal applications.
- A compact menu for theme selection, wallpapers, apps, clipboard, and
  notification history.
- A notification centre with actions, unread count, dismiss/clear, do not
  disturb, and up to three notification popups.
- Searchable `cliphist` history with image previews, copy, delete, and a
  two-click clear-all button.
- Catppuccin Mocha, Everforest, Gruvbox, and Tokyo Night palettes. Every
  colour is in `Theme.qml`.

## Run

Requires Quickshell 0.3.2 with Hyprland and Networking support, Hyprland,
`cliphist`, and `wl-clipboard`. PipeWire/WirePlumber provides volume controls,
UPower provides battery information, NetworkManager provides Wi-Fi, and
`power-profiles-daemon` (including `powerprofilesctl`) provides power profiles.
Hyprpaper applies wallpapers selected from `~/Pictures/Wallpapers`.
`nm-connection-editor` is used by the Network settings button. JetBrains Mono
provides the shell's text; the shell draws its own vector icons.

On Arch, with Quickshell already installed:

```sh
sudo pacman -S cliphist wl-clipboard networkmanager power-profiles-daemon nm-connection-editor hyprpaper
quickshell -p /a/qs
```

Use your checkout's path if it is somewhere else. Run from a Hyprland session.
After updating from the earlier shell, restart Quickshell once: native tray
menus require the `UseQApplication` startup pragma, which a hot reload cannot
apply.
Stop your existing notification daemon (such as Mako or SwayNC) before starting
Cat: only one daemon can own the desktop notification service. Remove your
previous bar and notification daemon's autostart entries when making Cat
your default.

For a permanent setup, symlink this checkout:

```sh
mkdir -p ~/.config/quickshell
ln -s /a/qs ~/.config/quickshell/cat
```

For a Lua Hyprland configuration, merge `hyprland.lua.example` into your
configuration. It uses `/a/qs` directly, so no symlink is needed. Replace
existing bindings on the same keys, especially a Fuzzel binding on Super+V.
Keep your existing clipboard watcher if you already have one.

For a legacy `hyprland.conf`, use `hyprland.conf.example` after creating the
symlink above. That example also starts text/image clipboard watchers at login.
Keep only one watcher per content type. To begin collecting history in the
current session:

```sh
wl-paste --type text --watch cliphist store &
wl-paste --type image --watch cliphist store &
```

`exec-once` entries run at session startup, not on a Hyprland config reload.

## Controls

| Input | Action |
| --- | --- |
| Click menu icon / Super+Space | Theme, wallpapers, apps, clipboard, notification history, and power menu |
| Super+R | App launcher |
| Super+P | Power menu: lock, suspend, hibernate, log out, restart, shut down |
| Super+V | Clipboard history |
| Super+N | Notification centre |
| Super+Shift+N | Toggle do not disturb |
| Up / Down, Enter | Select and open a menu entry, launch an app, or copy |
| Right / Left in menus | Open submenu / go back |
| Backspace / Shift+Backspace | Go back / forward (search fields must be empty) |
| Ctrl+Delete in clipboard search | Delete selected entry |
| Escape / click or tap anywhere outside a panel (including the bar) | Close panel |
| Click speaker / scroll over speaker | Volume popup / adjust volume |
| Click battery or power icon | Battery details and power profiles |
| Click network icon | Nearby Wi-Fi networks and connection controls |
| Left / right / middle click tray icon | Activate / menu / secondary action |

Panels opened from the bar appear on that monitor. Keybindings use the
focused monitor. Selecting a clipboard entry restores its original contents
to the clipboard; use your application's normal paste shortcut afterwards.
Image entries show thumbnails decoded from cliphist's stored data.

The IPC commands can also be used directly:

```sh
quickshell ipc -p /a/qs call shell menu
quickshell ipc -p /a/qs call shell session
quickshell ipc -p /a/qs call shell launcher
quickshell ipc -p /a/qs call shell clipboard
quickshell ipc -p /a/qs call shell notifications
quickshell ipc -p /a/qs call shell audio
quickshell ipc -p /a/qs call shell power
quickshell ipc -p /a/qs call shell network
quickshell ipc -p /a/qs call shell dnd
quickshell ipc -p /a/qs call shell close
```

## Theme and settings

Choose a palette from the **Theme** entry in the bar menu. The selection is
saved in Quickshell's state directory and applies immediately. Available
palettes are `everforest` (default), `catppuccin-mocha`, `gruvbox`, and
`tokyo-night`. To add a palette, edit the `palettes` map in `Theme.qml` and
provide the same color keys as the existing palettes.

All backgrounds, borders, text, and highlights come from `Theme.qml`. The
interface uses JetBrains Mono, configured in `Config.qml`.

`Config.qml` sets the font family and size, bar height, spacing, workspace count,
notification limit, popup duration, and terminal command. Set `fontSize` (in
pixels) to resize text throughout the bar and panels; headings and smaller
labels scale with it. Saving the file reloads the shell automatically.

The default terminal is Ghostty; for Kitty, for example, use:

```qml
property var terminalCommand: ["kitty", "-e"]
```

The menu remembers your selected palette and wallpaper in Quickshell's state
directory. Wallpaper selection applies the image to all active Hyprland
monitors through hyprpaper; start hyprpaper with IPC enabled.

The bar always shows the configured numbered workspaces, plus any additional
active numbered workspaces. Workspace clicks support both Lua and legacy
Hyprland dispatcher syntax. The active workspace is a small rounded square;
other workspaces use single numbers. The battery icon becomes a power icon
on desktops without a battery.

## Network and power controls

The Wi-Fi popup scans while open and connects to saved networks using their
stored credentials. New WPA/WPA2/WPA3 personal networks prompt for a password.
Passwords go directly to NetworkManager, never into a process command line,
and the input is cleared after submission or closing the panel. Open networks
do not prompt. Enterprise and other networks needing extra configuration can
be set up through Network settings, then selected here as saved connections.
The popup also includes a Wi-Fi radio toggle and a disconnect button.

Power profiles are read from the running `power-profiles-daemon`. Choose
Power saver, Balanced, or Performance; unsupported profiles are dimmed. The
current selection updates after the change succeeds, and failures are shown
in the popup. Battery percentage and charge/discharge time appear only in the
popup, keeping the bar free of text readouts.

## Notifications and history

Ordinary popups disappear after their timeout while their notifications remain
in the centre. Critical notifications and notifications requesting no timeout
stay visible until dismissed. Transient notifications skip the centre and are
released when they expire. Do not disturb suppresses popups while ordinary
notifications still reach the centre. History holds up to 100 notifications
by default, survives QML reloads, and is kept only for the current shell
process; it is not written to disk.

Clipboard history is stored by cliphist on disk, independently of Cat. Use
the panel's delete/clear controls to remove entries. Start Cat only once per
session; its one process handles all connected monitors.

## Layout

```text
shell.qml                 Entry point and IPC
Theme.qml                 All colours and palette selection
Config.qml                Dimensions, font, limits, terminal
ShellState.qml            Panel visibility and monitor selection
widgets/                  Bar and notification popups
panels/                   Launcher, clipboard, notifications, audio, power, Wi-Fi
components/               Shared UI controls
services/                 Notification, clipboard, audio, power, network state
scripts/clipboard.sh      Binary-safe cliphist operations and image previews
scripts/wallpapers.py     Wallpaper list and hyprpaper integration
hyprland.conf.example     Autostart and keybindings
hyprland.lua.example      Autostart and keybindings for Lua configs
```

The native integrations use Quickshell's
[desktop entries](https://quickshell.org/docs/v0.2.1/types/Quickshell/DesktopEntry/),
[notification service](https://quickshell.org/docs/v0.2.1/types/Quickshell.Services.Notifications/NotificationServer/),
[Wayland layers](https://quickshell.org/docs/v0.3.1/types/Quickshell.Wayland/WlrLayershell/),
and [network service](https://quickshell.org/docs/v0.3.1/types/Quickshell.Networking/Networking/).

## Validation

```sh
python3 -m unittest discover -s tests -v
bash -n scripts/clipboard.sh
```

The clipboard tests use a temporary, real cliphist database and a substitute
`wl-copy`. They check text/binary round trips, deletion, clearing, invalid
IDs, and preserving the clipboard when decoding fails. They do not read or
modify your clipboard history.

The control tests run the network and power services offscreen with isolated
backends. They cover new/saved/open Wi-Fi connections, password retries,
enterprise setup, radio toggling, and successful/failed profile changes.
They do not change your network, power profile, or audio settings.

The interaction tests check that delayed hover hints preserve keyboard focus,
icons accept repeated clicks without moving the pointer away, and opening a
panel or leaving the icon hides its hint. Hints use an empty input region so
they cannot intercept clicks. Transparent surfaces below the bar catch outside
clicks and taps on each monitor. The bar stays interactive, so clicking another
panel icon switches panels directly; clicking the active icon closes it.
Mouse and touch dismissal, panel controls, empty panel padding, empty bar clicks,
and switching between panels are exercised with offscreen windows.

The panels have also been rendered with Qt's offscreen backend using temporary
floating windows, including populated popups and the Wi-Fi password prompt.
Live Hyprland focus, D-Bus delivery, system tray, audio, network switching,
power-profile changes, and clipboard ownership still need a check in a desktop session; the build
sandbox blocks those sockets.
