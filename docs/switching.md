# Switching from iNiR (and back)

How to move a niri setup that runs [iNiR](https://github.com/snowarch/inir) (a
Quickshell shell started as the `inir.service` user unit) to dmsh + dm-desktop, and
how to go back. Nothing here deletes iNiR: its config, `config.d/` and service stay
where they are, so going back is a few commands.

What changes:

| iNiR | After |
|---|---|
| Bar, notifications, OSDs, tray | dmsh |
| Polkit agent | polkit-kde-agent |
| Lock screen and idle (screen off 5 min, lock 10 min, lock before sleep) | hypridle + hyprlock, same timings; the lock shows the blurred desktop, clock and date |
| Wallpaper and wallpaper picker | awww, and walker with previews, Ctrl+Alt+T |
| Clipboard overlay (Mod+V) | walker, Mod+V. History starts empty: walker keeps its own, separate from iNiR's cliphist |
| Overview / launcher (Mod+Space) | walker, Mod+Space. niri's overview stays on Mod+Tab |
| Region menu (Mod+Shift+S) | niri's screenshot UI, Mod+Shift+S or Print |
| OCR (Mod+Shift+X), recording (Mod+Shift+R) | Same keys, grim/slurp/tesseract/wf-recorder |
| Session menu (Mod+Shift+Q) | walker power menu, Mod+Shift+Q |
| Volume, brightness, media keys | wpctl, brightnessctl, playerctl (dmsh shows the OSD) |
| Close with confirmation (Mod+Q) | niri's plain close-window |
| Cheatsheet (Mod+Slash) | niri's hotkey overlay |

Not replaced: the crosshair overlay (Super+G), Google Lens search (Mod+Shift+A),
Ctrl+Shift+S (left to apps, where it usually means "Save as"), the settings app
(Mod+Comma), panel family (Mod+Shift+W), equalizer (Ctrl+Alt+F), wallpaper-based
color theming. The colors iNiR generated for kitty, Qt, GTK and so on stay as they are
and won't follow a new wallpaper.

## Switch over

Do this from the running iNiR session. Step 3 changes niri's config, which niri
reloads at once, so the iNiR keybinds stop working right after it. Log out right away
(step 6).

1. **Install dmsh** (from its repo). Answer **n** to adding the include line to
   config.kdl (dm-desktop's config has it) and **n** to starting dmsh now (iNiR is
   still running):

   ```sh
   cd ~/Documents/Projects/DM-Shell && ./install.sh
   ```

   This builds dmsh into `~/.local/bin` and writes `~/.config/niri/dmsh.kdl`.

2. **Check the starting point** for the way back. The dm-desktop installer saves your
   current `config.kdl` by itself; this is just a quick look:

   ```sh
   ls ~/.config/niri ~/.config/systemd/user/niri.service.wants
   ```

   You should see `config.kdl`, `config.d/`, `dmsh.kdl` and the `inir.service` link.

3. **Install dm-desktop.** It lists the files it writes and asks before installing
   packages and before writing. walker comes from the CachyOS repo; elephant and its
   provider plugins come from the AUR through `yay`, which asks for your password itself:

   ```sh
   cd ~/Documents/Projects/dm-desktop && ./install.sh
   ```

4. **Add this laptop's settings** as `~/.config/niri/local.kdl`. These are the
   machine-specific parts of the old config: keyboard layout, cursor, the VRR output,
   Qt/KDE theming, Dolphin's "Open with" menus, niri-focused-booster, browser and file
   manager keys, and OCR with Russian:

   ```kdl
   input {
       keyboard {
           xkb {
               layout "us,ru"
               options "grp:alt_shift_toggle"
           }
       }
   }

   cursor {
       xcursor-theme "capitaine-cursors-light"
       xcursor-size 24
   }

   output "eDP-1" {
       variable-refresh-rate
   }

   environment {
       XDG_MENU_PREFIX "plasma-"
       QT_QPA_PLATFORMTHEME "kde"
       QT_STYLE_OVERRIDE "Darkly"
   }
   spawn-sh-at-startup "systemctl --user import-environment XDG_MENU_PREFIX && kbuildsycoca6"
   spawn-sh-at-startup "command -v niri-focused-booster >/dev/null && [ -r /sys/fs/cgroup/dmem.capacity ] && exec niri-focused-booster"

   // KDE's XEmbed tray bridge (autostarted) shows a transient X11 window; keep it invisible.
   window-rule {
       match app-id=r#"^xembedsniproxy$"#
       open-floating true
       open-focused false
       opacity 0.0
       focus-ring { off; }
       border { off; }
       shadow { off; }
   }

   binds {
       Mod+E hotkey-overlay-title="Files" { spawn "dolphin"; }
       Mod+W hotkey-overlay-title="Browser" { spawn "floorp"; }
       Mod+Shift+X hotkey-overlay-title="Copy text from a region (OCR)" { spawn-sh r#"t=$(grim -g "$(slurp)" - | tesseract - - -l eng+rus 2>/dev/null) && [ -n "$t" ] && printf '%s' "$t" | wl-copy && notify-send -a OCR 'Text copied' "$t""#; }
   }
   ```

   Then check it: `niri validate` should say "config is valid".

5. **Stop iNiR from starting at login**. This removes only the link that starts it with
   niri; the unit file stays. Don't stop it now, so the current session keeps working
   until you log out:

   ```sh
   rm ~/.config/systemd/user/niri.service.wants/inir.service
   systemctl --user daemon-reload
   ```

   (`inir service disable` does the same, but it also stops iNiR immediately.)

6. **Log out** (Mod+Shift+E) and log back in.

7. **Set the wallpaper once**; awww restores it at every login after this:

   ```sh
   awww img ~/Pictures/Wallpapers/wallhaven-1qod3w.jpg
   ```

### Check

```sh
pgrep -a 'dmsh|hypridle|awww-daemon|polkit-kde|elephant|walker'   # all six running
systemctl --user is-active inir.service                      # inactive: iNiR is off
niri validate                                               # config is valid
```

Then try: Mod+Space (launcher), Mod+V (clipboard), Mod+Alt+L (lock, then unlock),
Mod+Shift+S (screenshot), a volume key (dmsh shows the OSD), Mod+N (dmsh's
notification list) and something that asks for a password, like `pkexec true`
(the polkit-kde dialog appears).

The tray: Qt and Electron apps that were running under iNiR (Throne, the Claude
desktop app) only register their tray icons at startup. After logging in fresh this is
fine, but if one is missing, restart that app.

## Roll back

From the dmsh session, or from a text console (Ctrl+Alt+F3) if the graphical session
is unusable:

1. **Restore the old files**: iNiR's `config.kdl` comes back
   byte for byte. dm-desktop's niri files and the hypr, walker and elephant configs go away:

   ```sh
   ~/Documents/Projects/dm-desktop/install.sh --uninstall
   ```

   `local.kdl` stays, but iNiR's config doesn't include it, so it does nothing. Delete
   it if you like. The packages stay installed and do nothing; iNiR's clipboard
   history was never touched.

2. **Start iNiR with niri again**:

   ```sh
   ln -s ~/.config/systemd/user/inir.service ~/.config/systemd/user/niri.service.wants/inir.service
   systemctl --user daemon-reload
   ```

   (or `inir service enable`).

3. **Log out and back in.** iNiR's config.kdl doesn't include `dmsh.kdl`, so dmsh
   doesn't start. To remove dmsh completely as well:

   ```sh
   ~/Documents/Projects/DM-Shell/install.sh --uninstall
   ```

To try iNiR for a moment without rolling back: `pkill -x dmsh` and then
`systemctl --user start inir.service`. Undo: `systemctl --user stop inir.service`,
then `niri msg action spawn -- ~/.local/bin/dmsh`.
