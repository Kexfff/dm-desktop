# dm-desktop

A minimal niri desktop around [dmsh](https://github.com/Kexfff/DM-Shell). dmsh is the
shell (bar, notifications, OSDs, tray, battery, quick controls) and deliberately leaves
out the rest of a desktop. This repo adds those pieces, using small standard tools,
and a niri config that ties them together.

It's my personal setup: it also carries my laptop's niri settings (`local.kdl`) and my
dmsh config. Change those two for another machine.


| Piece | Tool | Keys |
|---|---|---|
| Polkit agent (password prompts from apps) | polkit-kde-agent | — |
| Idle and lock screen | swayidle + hyprlock | Mod+Alt+L to lock |
| Wallpaper | awww (remembers the last image) | Ctrl+Alt+T to pick one, with previews |
| Clipboard history (text and images) | walker | Mod+V |
| Launcher, calculator, emoji | [walker](https://github.com/abenz1267/walker) | Mod+Space |
| Screenshots | niri's built-in screenshot UI | Print, Mod+Shift+S |
| Text from a region (OCR) | grim + slurp + tesseract | Mod+Shift+X |
| Screen recording | slurp + wf-recorder | Mod+Shift+R (again to stop) |
| Power menu | walker | Mod+Shift+Q |

There is no daemon or script of its own: just config files for niri, swayidle,
hyprlock and walker, plus an install script. Mod+Slash lists the keys.

## Install

Install dmsh first. Its install.sh writes `~/.config/niri/dmsh.kdl`, which this config
includes. Then run:

```sh
git clone https://github.com/Kexfff/dm-desktop
cd dm-desktop
./install.sh
```

It lists what it will do and asks first. It:

- installs the tools above that are missing (pacman, apt or dnf), and asks separately
  about the optional ones (tesseract for OCR, wf-recorder for recording);
- copies `config/` into `~/.config`. A file of yours that this replaces (usually
  `niri/config.kdl`) is saved under `~/.local/state/dm-desktop`;
- checks the resulting niri config with `niri validate` before writing anything.

Then log out and back in: niri starts the daemons (polkit agent, swayidle, awww-daemon,
elephant and walker) at login. Set a wallpaper once with `awww img FILE` or
Ctrl+Alt+T (it lists `~/Pictures/Wallpapers`). awww restores it at every login after
that.

`./install.sh --yes` doesn't ask, `--no-deps` skips packages. Run it again after
pulling to update; your saved originals stay as they were.

`./install.sh --uninstall` puts back the files it replaced, byte for byte, and removes
the ones it added. Log out and back in to stop the daemons.

## Files

```
~/.config/niri/config.kdl              includes the rest, in this order:
~/.config/niri/dm-desktop/base.kdl     input, layout, animations, window rules
~/.config/niri/dm-desktop/startup.kdl  the daemons started at login
~/.config/niri/dm-desktop/binds.kdl    keybinds
~/.config/niri/dmsh.kdl                dmsh's autostart and binds (from dmsh)
~/.config/niri/local.kdl               this machine: keyboard layout, outputs, theming, apps
~/.config/dmsh/config.kdl              dmsh's look (pill and reserved height)
~/.config/swayidle/config              screen off after 5 min, lock after 10, lock before sleep
~/.config/swayidle/lock                starts hyprlock and waits until the screen is locked
~/.config/hypr/hyprlock.conf           the lock screen: blurred desktop, clock, password pill
~/.config/walker/config.toml           launcher settings and its theme (black, like dmsh)
~/.config/elephant/menus/              the power menu and the wallpaper picker
```

Settings for one machine go in `config/niri/local.kdl`: outputs, keyboard layout,
cursor theme, the browser and file manager keys. It's included last, so a bind there
replaces the same bind above, and settings in sections like `input {}` are merged in.
For another machine, replace it with something like:

```kdl
input {
    keyboard {
        xkb {
            layout "us,ru"
            options "grp:alt_shift_toggle"
        }
    }
}

output "eDP-1" {
    variable-refresh-rate
}

binds {
    Mod+W { spawn "firefox"; }
    Mod+E { spawn "dolphin"; }
}
```

The terminal is kitty (Mod+T, Mod+Return). Use another one by binding Mod+T and
Mod+Return in local.kdl.

## The launcher

[walker](https://github.com/abenz1267/walker) is the front end;
[elephant](https://github.com/abenz1267/elephant) is its backend, with one plugin per
provider. This setup uses six: desktop apps, clipboard, menus, calculator, symbols and
the provider list. On Arch, walker is in the CachyOS repos and the AUR, and elephant and
its plugins are in the AUR (`elephant-bin` plus `elephant-<provider>-bin`, from the same
build). install.sh installs them with `paru` or `yay` if you have one. Elsewhere, install
them by hand.

While searching: `=` calculator, `:` clipboard, `.` symbols and emoji, `;` all providers.
In the clipboard view, Ctrl+P pins an entry and Ctrl+D removes it.

Both run as user services started by niri (`systemd-run`), tied to the session, so
they restart if they crash. Logs: `journalctl --user -u elephant -u walker`.

Elephant's README says its development is on hold (September 2026); walker itself is
still maintained. If elephant stops working with a future walker, fuzzel plus cliphist
is the fallback this repo used before.

## Notes

- **Polkit agent path**: startup.kdl tries the usual locations of
  `polkit-kde-authentication-agent-1` (Arch, Fedora, Debian). Run only one polkit
  agent; a second one fails to register.
- **Lock**: Mod+Alt+L, the idle timer and suspend all go through
  `loginctl lock-session`; swayidle starts hyprlock when that happens. Apps that ask
  to stay awake pause the idle timers, whether they ask through Wayland (browsers playing
  video, dmsh's Keep awake) or D-Bus (niri itself answers those).
- **Lock before sleep**: swayidle holds suspend (`-w`) until `~/.config/swayidle/lock`
  returns, and that script returns once hyprlock logs that niri confirmed the lock
  (about 0.3 s), or after 3 s at most. So the lock is already up when the lid opens.
  hypridle can't do this on niri: its wait-for-lock needs a Hyprland-only protocol, and
  without it suspend went ahead before the lock, leaving the desktop visible for about a
  second after opening the lid.
- **Screenshots**: niri's UI copies the image to the clipboard and saves it to
  `~/Pictures/Screenshots`. Ctrl+C in the UI copies without saving.
- **Recording** captures system audio (the default output's monitor) and saves to
  `~/Videos`. A notification shows the file when it stops.
- **Wallpaper in the overview**: the layer rule for `awww-daemon` puts the wallpaper in
  niri's backdrop, and the transparent workspace background lets it show through.

Moving over from another shell, with a way back: [docs/switching.md](docs/switching.md).

## License

GPL-3.0, like dmsh.
