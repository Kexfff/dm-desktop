#!/bin/sh
# Installs dm-desktop: the desktop pieces dmsh leaves out (polkit agent, idle and lock,
# wallpaper, clipboard history, launcher, screenshots) and a niri config using them.
# Install dmsh first; its install.sh writes ~/.config/niri/dmsh.kdl, which this includes.
#
#   ./install.sh               install (asks before changing anything)
#   ./install.sh --yes         don't ask
#   ./install.sh --no-deps     skip installing packages
#   ./install.sh --uninstall   put back the files it replaced, remove the ones it added
set -eu

deps=1
yes=0
uninstall=0
while [ $# -gt 0 ]; do
    case "$1" in
        --yes | -y) yes=1 ;;
        --no-deps) deps=0 ;;
        --uninstall) uninstall=1 ;;
        -h | --help) sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

repo=$(cd "$(dirname "$0")" && pwd)
config="${XDG_CONFIG_HOME:-$HOME/.config}"
state="${XDG_STATE_HOME:-$HOME/.local/state}/dm-desktop"
# What install did, one line each: "replaced PATH" (original saved under $state/backup),
# "added PATH" (a new file) or "dir PATH" (a new directory). PATH is relative to $config.
manifest="$state/manifest"
sudo=${SUDO:-sudo}

say() { printf '\033[1m==>\033[0m %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
ask() {
    [ "$yes" = 1 ] && return 0
    printf '\033[1m==>\033[0m %s [y/N] ' "$1"
    read -r answer || return 1
    [ "$answer" = y ] || [ "$answer" = Y ]
}

restore() {
    [ -f "$manifest" ] || return 0
    # Put back replaced files first (config.kdl stops including the added ones), then
    # remove added files, then the directories they were in, innermost first.
    while read -r kind path; do
        [ "$kind" = replaced ] || continue
        cp -Pp "$state/backup/$path" "$config/$path.dm-desktop-new"
        mv -f "$config/$path.dm-desktop-new" "$config/$path"
    done < "$manifest"
    while read -r kind path; do
        if [ "$kind" = added ]; then rm -f "$config/$path"; fi
    done < "$manifest"
    tac "$manifest" | while read -r kind path; do
        if [ "$kind" = dir ]; then rmdir "$config/$path" 2>/dev/null || true; fi
    done
    rm -rf "$state"
}

if [ "$uninstall" = 1 ]; then
    if [ ! -f "$manifest" ]; then
        say "Nothing to uninstall (no $manifest)."
        exit 0
    fi
    restore
    say "Restored your previous files. Log out and back in to stop the dm-desktop daemons."
    exit 0
fi

if [ ! -f "$config/niri/dmsh.kdl" ]; then
    say "No $config/niri/dmsh.kdl. Install dmsh first: https://github.com/Kexfff/DM-Shell"
    exit 1
fi

# --- Dependencies -------------------------------------------------------------------
install_packages() {
    if command -v pacman >/dev/null; then
        $sudo pacman -S --needed --noconfirm "$@"
    elif command -v apt-get >/dev/null; then
        $sudo apt-get install -y "$@"
    elif command -v dnf >/dev/null; then
        $sudo dnf install -y "$@"
    else
        say "Unknown package manager; please install: $*"
        return 1
    fi
}

pkg() {
    # pkg <pacman> <apt> <dnf>
    if command -v pacman >/dev/null; then echo "$1"
    elif command -v apt-get >/dev/null; then echo "$2"
    elif command -v dnf >/dev/null; then echo "$3"
    fi
}

polkit_agent() {
    for a in /usr/lib/polkit-kde-authentication-agent-1 /usr/libexec/polkit-kde-authentication-agent-1 \
        /usr/lib/*/libexec/polkit-kde-authentication-agent-1; do
        [ -x "$a" ] && return 0
    done
    return 1
}

if [ "$deps" = 1 ]; then
    missing=""
    need() { command -v "$1" >/dev/null || missing="$missing $2"; }
    need swayidle swayidle
    need swaylock swaylock
    need awww awww
    need fuzzel fuzzel
    need cliphist cliphist
    need wl-copy wl-clipboard
    need grim grim
    need slurp slurp
    need brightnessctl brightnessctl
    need playerctl playerctl
    polkit_agent || missing="$missing $(pkg polkit-kde-agent polkit-kde-agent-1 polkit-kde)"
    optional=""
    tesseract --list-langs 2>/dev/null | grep -qx eng ||
        optional="$optional $(pkg "tesseract tesseract-data-eng" "tesseract-ocr tesseract-ocr-eng" "tesseract tesseract-langpack-eng")"
    command -v wf-recorder >/dev/null || optional="$optional wf-recorder"

    if [ -n "$missing" ] && ask "Install packages:$missing?"; then
        install_packages $missing || say "Some packages failed to install; the binds that need them won't work."
    fi
    if [ -n "$optional" ]; then
        say "Optional: text from a region (Mod+Shift+X) and screen recording (Mod+Shift+R) need:$optional"
        if ask "Install them too?"; then
            install_packages $optional || say "Skipped; those two binds won't work."
        fi
    fi
fi

# --- Config files ---------------------------------------------------------------------
# Reverse order puts niri/config.kdl after the files it includes: niri reloads on every
# change and shouldn't see an include that isn't there yet.
files=$(cd "$repo/config" && find . -type f | sed 's|^\./||' | sort -r)
say "These files in $config will be written:"
for f in $files; do
    if [ -e "$config/$f" ] || [ -L "$config/$f" ]; then
        if cmp -s "$repo/config/$f" "$config/$f"; then note "$f (unchanged)"
        elif grep -qxsF -e "replaced $f" -e "added $f" "$manifest"; then note "$f (update)"
        else note "$f (replaces yours; it's kept and --uninstall puts it back)"
        fi
    else
        note "$f (new)"
    fi
done
# Check the result on a copy first: niri applies config changes as soon as they land.
if command -v niri >/dev/null; then
    stage=$(mktemp -d)
    [ -d "$config/niri" ] && cp -a "$config/niri/." "$stage/"
    cp -r "$repo/config/niri/." "$stage/"
    if ! out=$(niri validate -c "$stage/config.kdl" 2>&1); then
        rm -rf "$stage"
        printf '%s\n' "$out" >&2
        say "niri rejects the config this would make (see above). Nothing changed."
        exit 1
    fi
    rm -rf "$stage"
fi
if ! ask "Go ahead?"; then
    say "Nothing changed."
    exit 0
fi

mkdir -p "$state/backup"
touch "$manifest"
for f in $files; do
    dir=$(dirname "$f")
    # Record each directory this creates, outermost first.
    missing_dirs=""
    d=$dir
    while [ "$d" != . ] && [ ! -d "$config/$d" ]; do
        missing_dirs="$d $missing_dirs"
        d=$(dirname "$d")
    done
    for d in $missing_dirs; do
        mkdir "$config/$d"
        echo "dir $d" >> "$manifest"
    done

    if grep -qxF -e "replaced $f" -e "added $f" "$manifest"; then
        :
    elif [ -e "$config/$f" ] || [ -L "$config/$f" ]; then
        mkdir -p "$state/backup/$dir"
        cp -Pp "$config/$f" "$state/backup/$f"
        echo "replaced $f" >> "$manifest"
    else
        echo "added $f" >> "$manifest"
    fi
    # Copy then rename, so niri (which reloads on change) never sees a missing file.
    cp "$repo/config/$f" "$config/$f.dm-desktop-new"
    mv -f "$config/$f.dm-desktop-new" "$config/$f"
done

say "Installed. Log out and back in to start the polkit agent, idle/lock, wallpaper and"
note "clipboard daemons (niri starts them). Machine-specific settings (outputs, keyboard"
note "layout, your apps) go in $config/niri/local.kdl. Undo with: $0 --uninstall"
