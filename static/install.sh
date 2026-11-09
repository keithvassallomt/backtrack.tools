#!/usr/bin/env bash
#: This script installs Backtrack the way the [install guide](/install/) would
#: for your computer. It looks at which Linux you use, tells you what it found
#: and what it is about to do, and changes nothing until you say yes.
#:
#: Below is the whole script, every line of it in order, with what each part
#: does before it. This page is made from the script itself, so the two always
#: match. [install.sh](/install.sh) is the script in one piece.
#:
#:## Running it
#: In a terminal:
#:
#: ```sh
#: curl -fsSL https://backtrack.tools/install.sh | bash
#: ```
#:
#: To see what it would do on your computer, without changing anything:
#:
#: ```sh
#: curl -fsSL https://backtrack.tools/install.sh | bash -s -- --dry-run
#: ```
#:
#: To read it before you run it, download it first:
#:
#: ```sh
#: curl -fsSL https://backtrack.tools/install.sh -o install.sh
#: less install.sh
#: bash install.sh
#: ```
#:
#:## Its first lines
#: The program that runs the script (bash), its licence, and the same two ways
#: to run it.
# SPDX-License-Identifier: GPL-3.0-or-later
# SPDX-FileCopyrightText: 2026 Keith Vassallo <keith@vassallo.cloud>
#
# Installs Backtrack the way https://backtrack.tools/install/ would for this
# computer, after asking. https://backtrack.tools/install-script/ explains it
# step by step; the lines that start with "#:" are that page's text.
#
#   curl -fsSL https://backtrack.tools/install.sh | bash
#   curl -fsSL https://backtrack.tools/install.sh | bash -s -- --dry-run

#:## Where Backtrack comes from
#: These are the places the install guide sends you: Backtrack's repositories
#: for Fedora (COPR) and Ubuntu (PPA), its package in the Arch User
#: Repository, and the Flatpak on FriendlyHub. Backtrack's own packages need
#: the libraries that came with GNOME 50, so the Fedora ones need Fedora 44 or
#: later, and the PPA has packages only for the Ubuntu releases listed here.
set -euo pipefail

SITE=https://backtrack.tools
COPR=keithvassallo/backtrack
PPA=ppa:keithvassallomt/backtrack
# Kept in step with the [ppa] series in Backtrack's packaging/release.toml.
PPA_SERIES=" resolute "
FEDORA_OLDEST=44
AUR=https://aur.archlinux.org/backtrack.git
FLATPAKREF=https://dl.friendlyhub.org/repo/appstream/tools.backtrack.Backtrack.flatpakref
APP_ID=tools.backtrack.Backtrack
ISSUES=https://github.com/keithvassallomt/backtrack/issues

#:## How it looks
#: This part sets up the colours, the spinners and the little timeline at the
#: start and the end. None of it changes anything on your computer. Outside a
#: terminal, or with `NO_COLOR` set, the script prints plain text.
setup_look() {
    FANCY=0 UNI=0
    if [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ]; then
        FANCY=1
    fi
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *[Uu][Tt][Ff]-8* | *[Uu][Tt][Ff]8*) [ "${TERM:-}" = linux ] || UNI=1 ;;
    esac
    WIDTH=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2) || true
    case "$WIDTH" in '' | 0 | *[!0-9]*) WIDTH=80 ;; esac
    [ "$WIDTH" -gt 78 ] && WIDTH=78
    [ "$WIDTH" -lt 40 ] && WIDTH=40

    B='' D='' R='' ACC='' WARM='' OK='' BAD=''
    if [ "$FANCY" = 1 ]; then
        B=$'\e[1m' D=$'\e[2m' R=$'\e[0m'
        if [[ "${COLORTERM:-}" == *truecolor* || "${COLORTERM:-}" == *24bit* ]]; then
            ACC=$'\e[38;2;150;115;230m' WARM=$'\e[38;2;225;150;60m'
            OK=$'\e[38;2;70;175;105m' BAD=$'\e[38;2;220;75;75m'
        elif [ "$(tput colors 2>/dev/null || echo 8)" -ge 256 ]; then
            ACC=$'\e[38;5;98m' WARM=$'\e[38;5;179m' OK=$'\e[38;5;71m' BAD=$'\e[38;5;167m'
        else
            ACC=$'\e[35m' WARM=$'\e[33m' OK=$'\e[32m' BAD=$'\e[31m'
        fi
    fi
    if [ "$UNI" = 1 ]; then
        TICK='✔' CROSS='✖' WOULD='○' POINT='›' MID='·'
        REWIND='◀◀' HEAD='●' TRACK='─' TRAIL='━'
        TL='╭' TR='╮' BL='╰' BR='╯' H='─' V='│'
        # A clock going backwards.
        SPIN=(🕛 🕚 🕙 🕘 🕗 🕖 🕕 🕔 🕓 🕒 🕑 🕐)
    else
        TICK='+' CROSS='x' WOULD='o' POINT='>' MID='-'
        REWIND='<<' HEAD='o' TRACK='-' TRAIL='='
        TL='+' TR='+' BL='+' BR='+' H='-' V='|'
        SPIN=('|' '/' '-' "\\")
    fi
}

pause() { if [ "$FANCY" = 1 ]; then sleep "$1"; fi; }
cursor() { if [ "$FANCY" = 1 ]; then printf '\e[?25%s' "$1"; fi; }
repeat() { local s='' i; for ((i = 0; i < $2; i++)); do s+=$1; done; printf '%s' "$s"; }
wrap() { printf '%s\n' "$1" | fold -s -w "$2"; }

heading() { printf '\n  %s%s%s\n' "$B" "$1" "$R"; pause 0.1; }
say() { wrap "$1" $((WIDTH - 4)) | while IFS= read -r l; do printf '  %s\n' "$l"; done; }
quiet() { wrap "$1" $((WIDTH - 4)) | while IFS= read -r l; do printf '  %s%s%s\n' "$D" "$l" "$R"; done; }
found() { printf '  %s%s%s %-14s%s\n' "$OK" "$TICK" "$R" "$1" "$2"; pause 0.07; }
pointer() { printf '  %s%s%s %-14s%s%s%s\n' "$ACC" "$POINT" "$R" "$1" "$B" "$2" "$R"; pause 0.07; }

# A box around some lines. A line that starts with "$ " is a command, shown
# dimmed and indented.
box() {
    local title=$1 inner=$((WIDTH - 6)) line text plain pad
    shift
    printf '\n  %s%s%s %s%s%s %s%s%s\n' "$ACC" "$TL" "$H" "$B" "$title" "$R" \
        "$ACC" "$(repeat "$H" $((inner - ${#title} - 1)))$TR" "$R"
    for line in "$@"; do
        if [[ "$line" == '$ '* ]]; then
            while IFS= read -r text; do
                pad=$((inner - ${#text} - 3))
                printf '  %s%s%s    %s%s%s%*s %s%s%s\n' "$ACC" "$V" "$R" "$D" "$text" "$R" "$pad" '' "$ACC" "$V" "$R"
            done < <(printf '%s\n' "${line#\$ }" | fold -s -w $((inner - 3)))
        else
            while IFS= read -r text; do
                plain=$text
                pad=$((inner - ${#plain}))
                printf '  %s%s%s %s%*s %s%s%s\n' "$ACC" "$V" "$R" "$text" "$pad" '' "$ACC" "$V" "$R"
            done < <(wrap "$line" "$inner")
        fi
    done
    printf '  %s%s%s%s%s\n' "$ACC" "$BL" "$(repeat "$H" $((inner + 2)))" "$BR" "$R"
}

# The timeline: the playhead runs back to the start, or forward to the end.
timeline() {
    local n=$((WIDTH - 8)) i track trail
    track=$(repeat "$TRACK" "$n") trail=$(repeat "$TRAIL" "$n")
    if [ "$FANCY" != 1 ]; then
        printf '  %s\n' "$trail"
        return
    fi
    cursor l
    if [ "$1" = back ]; then
        for ((i = n - 1; i >= 0; i--)); do
            printf '\r  %s%s%s%s%s%s%s%s' "$D" "${track:0:i}" "$R" "$ACC$B" "$HEAD" "$R$ACC" "${trail:i+1}" "$R"
            sleep 0.012
        done
    else
        for ((i = 0; i < n; i++)); do
            printf '\r  %s%s%s%s%s%s%s%s' "$ACC" "${trail:0:i}" "$B" "$HEAD" "$R" "$D" "${track:i+1}" "$R"
            sleep 0.012
        done
    fi
    printf '\n'
    cursor h
}

elapsed() {
    local s=$((SECONDS - $1))
    if [ "$s" -ge 60 ]; then printf '%dm %02ds' $((s / 60)) $((s % 60)); else printf '%ds' "$s"; fi
}

#:## Asking you
#: The script reads every answer from your terminal, even when the script
#: itself arrives through a pipe from curl. Pressing Enter picks the answer
#: shown in capitals.
ask() {
    local question=$1 choices=$2 reply
    printf '\n  %s%s%s %s %s%s%s ' "$ACC" "$POINT" "$R" "$question" "$D" "$choices" "$R" >/dev/tty
    IFS= read -r reply </dev/tty || reply=''
    printf '%s' "${reply,,}"
}

yes_to() {
    while true; do
        case "$(ask "$1" '[Y/n]')" in
            '' | y | yes) return 0 ;;
            n | no) return 1 ;;
        esac
    done
}

#:## Running a step
#: Each step runs one command. While it works, a spinner shows how long it
#: has taken, and everything the command prints goes to a log file instead
#: of filling your screen. If a step fails, you see the end of that log and
#: where to find the rest, and the script stops there. With `--dry-run`, the
#: script shows each command without running it.
run() {
    local doing=$1 did=$2 command=$3 pid rc=0 start=$SECONDS i=0
    printf '\n==> %s\n$ %s\n' "$doing" "$command" >>"$LOG"
    if [ "$DRY_RUN" = 1 ]; then
        printf '  %s%s%s %s\n' "$WARM" "$WOULD" "$R" "$doing"
        quiet "    would run: $command"
        pause 0.15
        return
    fi
    (eval "$command") >>"$LOG" 2>&1 </dev/null &
    pid=$! STEP_PID=$!
    if [ "$FANCY" = 1 ]; then
        cursor l
        while kill -0 "$pid" 2>/dev/null; do
            printf '\r\e[2K  %s %s %s%s%s' "${SPIN[i % ${#SPIN[@]}]}" "$doing" "$D" "$(elapsed "$start")" "$R"
            i=$((i + 1))
            sleep 0.12
        done
        printf '\r\e[2K'
        cursor h
    else
        printf '  %s ...\n' "$doing"
    fi
    wait "$pid" || rc=$?
    STEP_PID=''
    if [ "$rc" -eq 0 ]; then
        printf '  %s%s%s %s %s%s%s\n' "$OK" "$TICK" "$R" "$did" "$D" "$(elapsed "$start")" "$R"
        return
    fi
    printf '  %s%s %s%s\n\n' "$BAD" "$CROSS" "$doing: it stopped with an error." "$R"
    tail -n 12 "$LOG" | while IFS= read -r l; do printf '    %s%s%s\n' "$D" "${l:0:$((WIDTH - 6))}" "$R"; done
    printf '\n'
    say "Everything it printed is in $LOG."
    say "Nothing after this step ran. $SITE/install/ has each way to install Backtrack by hand, and if this looks like a fault in Backtrack, please tell us at $ISSUES."
    KEEP_LOG=1
    exit 1
}

#:## Before it starts
#: The script stops at once if you run it as root, with sudo for example. The
#: Flatpak and the AUR install for the person who runs them, and sudo asks
#: for your password when a step needs it. The script also needs a terminal,
#: because it never installs anything without asking you first.
preflight() {
    if [ "$(id -u)" -eq 0 ]; then
        say "Please run this as yourself, without sudo. When a step needs your password, the script asks for it."
        exit 1
    fi
    if ! { true </dev/tty; } 2>/dev/null; then
        say "This script asks before it changes anything, so it needs a terminal. Please run it from one."
        exit 1
    fi
}

#:## Looking around
#: The script reads `/etc/os-release` to learn which distribution you use and
#: which one it is based on. Then it looks for the file managers Backtrack
#: adds itself to, and for a Backtrack that is already installed.
have() { command -v "$1" >/dev/null 2>&1; }

is_like() {
    case " $OS_ID $OS_LIKE " in *" $1 "*) return 0 ;; esac
    return 1
}

look_around() {
    OS_ID='' OS_LIKE='' OS_NAME=Linux OS_SERIES=''
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        eval "$(
            . /etc/os-release
            printf 'OS_ID=%q OS_LIKE=%q OS_NAME=%q OS_SERIES=%q\n' "${ID:-}" "${ID_LIKE:-}" \
                "${PRETTY_NAME:-${NAME:-Linux}}" "${UBUNTU_CODENAME:-${VERSION_CODENAME:-}}"
        )"
    fi

    PM=''
    for pm in apt-get dnf zypper pacman; do
        if have "$pm"; then PM=$pm; break; fi
    done

    FILE_MANAGERS=()
    have nautilus && FILE_MANAGERS+=(nautilus)
    have dolphin && FILE_MANAGERS+=(dolphin)

    INSTALLED=''
    if have flatpak && flatpak info "$APP_ID" >/dev/null 2>&1; then
        INSTALLED='as the Flatpak'
    elif have backtrack-gtk; then
        INSTALLED='from a package'
    fi

    HELPER=''
    have paru && HELPER=paru
    have yay && HELPER=yay

#: Then it picks the way the install guide would:
#:
#: - Fedora 44 or later, or a system built on it such as Nobara: Backtrack's
#:   COPR repository.
#: - Ubuntu 26.04 or later, or a system built on it such as Linux Mint:
#:   Backtrack's PPA.
#: - Arch Linux, or a system built on it such as EndeavourOS: the AUR. Manjaro
#:   is the exception, because its packages trail Arch's, and so is SteamOS,
#:   whose system is read-only.
#: - Fedora's Atomic desktops, and everything else: the Flatpak.
    local fedora
    fedora=$(rpm -E %fedora 2>/dev/null || true)
    case "$fedora" in '' | *[!0-9]*) fedora=0 ;; esac

    if [ -e /run/ostree-booted ]; then
        ROUTE=flatpak WHY="$OS_NAME installs apps as Flatpaks."
    elif is_like fedora && [ "$PM" = dnf ] && [ "$fedora" -ge "$FEDORA_OLDEST" ]; then
        ROUTE=copr WHY=''
    elif is_like fedora && [ "$fedora" -gt 0 ]; then
        ROUTE=flatpak WHY="Backtrack's Fedora packages need Fedora $FEDORA_OLDEST or later."
    elif is_like ubuntu && [ "$PM" = apt-get ] && [[ "$PPA_SERIES" == *" $OS_SERIES "* ]]; then
        ROUTE=ppa WHY=''
    elif is_like ubuntu; then
        ROUTE=flatpak WHY="Backtrack's Ubuntu packages need Ubuntu 26.04 or later."
    elif is_like manjaro; then
        ROUTE=flatpak WHY="Manjaro's packages trail Arch's, so the AUR's build can break there."
    elif is_like steamos; then
        ROUTE=flatpak WHY="SteamOS keeps its system read-only, so apps come as Flatpaks."
    elif is_like arch && [ "$PM" = pacman ]; then
        ROUTE=aur WHY=''
    else
        ROUTE=flatpak WHY="$OS_NAME has no Backtrack package of its own."
    fi
}

route_name() {
    case "$1" in
        copr) printf "Backtrack's Fedora repository (COPR)" ;;
        ppa) printf "Backtrack's Ubuntu repository (PPA)" ;;
        aur) printf 'the AUR, built with %s' "${HELPER:-makepkg}" ;;
        flatpak) printf 'the Flatpak, from FriendlyHub' ;;
    esac
}

fm_name() {
    case "$1" in nautilus) printf 'GNOME Files' ;; dolphin) printf 'Dolphin' ;; esac
}

desktop_name() {
    local d=${XDG_CURRENT_DESKTOP:-}
    d=${d##*:} d=${d#X-}
    case "$d" in
        KDE) printf 'KDE Plasma' ;;
        '') ;;
        *) printf '%s' "$d" ;;
    esac
}

report() {
    heading "Looking around"
    found "System" "$OS_NAME"
    local desktop fms=''
    desktop=$(desktop_name)
    [ -n "$desktop" ] && found "Desktop" "$desktop"
    if [ "${#FILE_MANAGERS[@]}" -gt 0 ]; then
        fms=$(fm_name "${FILE_MANAGERS[0]}")
        [ "${#FILE_MANAGERS[@]}" -gt 1 ] && fms+=" and $(fm_name "${FILE_MANAGERS[1]}")"
        found "File manager" "$fms"
    fi
    if [ -n "$INSTALLED" ]; then
        found "Backtrack" "already installed, $INSTALLED"
    else
        found "Backtrack" "not installed yet"
    fi
}

#:## Already installed
#: Backtrack should be installed one way only, so if it is already here, the
#: script says how and stops.
already_here() {
    box "Backtrack is already here" \
        "It is installed $INSTALLED, so there's nothing to do. Open it from your apps." \
        "To add it to your file manager's menu, see $SITE/guides/file-manager-integration/"
    printf '\n'
}

#:## Your file manager's menu
#: For each file manager it finds, the script offers Backtrack's items for its
#: right-click menu: Rewind This File…, Restore Previous Version… and the
#: rest. Pressing Enter adds them.
choose_items() {
    WANT=()
    local fm
    for fm in "${FILE_MANAGERS[@]}"; do
        if yes_to "Add Backtrack to the right-click menu in $(fm_name "$fm")?"; then WANT+=("$fm"); fi
    done
}

wants() {
    local fm
    for fm in "${WANT[@]}"; do [ "$fm" = "$1" ] && return 0; done
    return 1
}

#:## The plan
#: The steps depend on the way. Each one is a command you could type
#: yourself, and the script shows them all before it runs any.
#:
#: On Fedora (COPR), it turns on Backtrack's repository, then installs
#: `backtrack`. Fedora adds the items for GNOME Files or Dolphin by itself
#: when that file manager is present, so where you said no, the script leaves
#: them out. If `dnf copr` is missing, it adds that first.
#:
#: On Ubuntu (PPA), it adds Backtrack's repository, then installs `backtrack`
#: and the items you chose, which Ubuntu doesn't add by itself. If
#: `add-apt-repository` is missing, it adds that first.
#:
#: On Arch (AUR) with yay or paru, one command builds and installs
#: everything, without stopping to show you the build files. You can read
#: them first at <https://aur.archlinux.org/packages/backtrack>. Without a
#: helper, the script does what the install guide does: it installs `git` and
#: `base-devel`, downloads the build files to a temporary folder, builds there
#: with `makepkg`, and installs only the packages you chose. The temporary
#: folder is deleted when the script ends.
#:
#: For the Flatpak, it installs Flatpak first if it is missing, then
#: Backtrack for you alone (`--user`), from FriendlyHub. GNOME Files needs
#: `nautilus-python` from your distribution to show Backtrack's items, and a
#: Flatpak can't install that, so the script does. You then switch the items
#: on in Backtrack's Preferences.
# Each step has four parts: what the plan calls it, what the spinner says
# while it runs, what it says once it has, and the command.
STEPS=()
step() { STEPS+=("$1" "$2" "$3" "$4"); }

nautilus_python_present() {
    local f
    for f in /usr/lib*/nautilus/extensions-4/libnautilus-python.so \
        /usr/lib/*-linux-gnu/nautilus/extensions-4/libnautilus-python.so; do
        [ -e "$f" ] && return 0
    done
    return 1
}

pm_install() {
    case "$PM" in
        apt-get) printf 'sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y %s' "$*" ;;
        dnf) printf 'sudo dnf -y install %s' "$*" ;;
        zypper) printf 'sudo zypper --non-interactive install %s' "$*" ;;
        pacman) printf 'sudo pacman -S --needed --noconfirm %s' "$*" ;;
    esac
}

plan() {
    STEPS=() NOTES=() NEW_FLATPAK=0
    local packages=backtrack fm
    for fm in "${WANT[@]}"; do packages+=" backtrack-$fm"; done

    case "$ROUTE" in
        copr)
            if ! dnf copr --help >/dev/null 2>&1; then
                if dnf --version 2>/dev/null | grep -q dnf5; then
                    step "Add dnf's copr command" "Adding dnf's copr command" "Added dnf's copr command" "sudo dnf -y install dnf5-plugins"
                else
                    step "Add dnf's copr command" "Adding dnf's copr command" "Added dnf's copr command" "sudo dnf -y install dnf-plugins-core"
                fi
            fi
            step "Turn on Backtrack's repository" "Turning on Backtrack's repository" "Turned on Backtrack's repository" "sudo dnf -y copr enable $COPR"
            local leave=''
            for fm in "${FILE_MANAGERS[@]}"; do wants "$fm" || leave+=" --exclude=backtrack-$fm"; done
            step "Install Backtrack" "Installing Backtrack" "Installed Backtrack" "sudo dnf -y install $packages$leave"
            ;;
        ppa)
            if ! have add-apt-repository; then
                step "Add add-apt-repository" "Adding add-apt-repository" "Added add-apt-repository" "$(pm_install software-properties-common)"
            fi
            step "Add Backtrack's repository" "Adding Backtrack's repository" "Added Backtrack's repository" "sudo add-apt-repository -y $PPA"
            step "Install Backtrack" "Installing Backtrack" "Installed Backtrack" "$(pm_install "$packages")"
            ;;
        aur)
            if [ -n "$HELPER" ]; then
                local flags='--needed --noconfirm --skipreview'
                [ "$HELPER" = yay ] && flags='--needed --noconfirm --answerdiff None --answerclean None --answeredit None'
                step "Build and install Backtrack" "Building and installing Backtrack (a few minutes)" "Built and installed Backtrack" \
                    "$HELPER -S $flags $packages"
            else
                WORK=$(mktemp -d "${TMPDIR:-/tmp}/backtrack-aur.XXXXXX")
                local here files='' p
                here=$(printf '%q' "$WORK/backtrack")
                for p in $packages; do files+=" $p-[0-9]*.pkg.tar.zst"; done
                step "Install the build tools" "Installing the build tools" "Installed the build tools" "sudo pacman -S --needed --noconfirm git base-devel"
                step "Download Backtrack's build files" "Downloading Backtrack's build files" "Downloaded Backtrack's build files" "git clone --depth 1 $AUR $here"
                step "Build Backtrack" "Building Backtrack (a few minutes)" "Built Backtrack" \
                    "cd $here && PKGDEST=\$PWD PKGEXT=.pkg.tar.zst makepkg -s --noconfirm"
                step "Install Backtrack" "Installing Backtrack" "Installed Backtrack" "cd $here && sudo pacman -U --noconfirm$files"
            fi
            ;;
        flatpak)
            if ! have flatpak; then
                if [ -z "$PM" ]; then
                    say "Backtrack's Flatpak needs Flatpak, which isn't installed. https://flatpak.org/setup/ shows how to install it on $OS_NAME; then run this again."
                    exit 1
                fi
                step "Install Flatpak" "Installing Flatpak" "Installed Flatpak" "$(pm_install flatpak)"
                NEW_FLATPAK=1
            fi
            if wants nautilus && ! nautilus_python_present; then
                local np=''
                case "$PM" in
                    apt-get | zypper) np=python3-nautilus ;;
                    dnf) np=nautilus-python ;;
                    pacman) np=python-nautilus ;;
                esac
                if [ -n "$np" ] && [ ! -e /run/ostree-booted ]; then
                    step "Install nautilus-python, for GNOME Files" "Installing nautilus-python, for GNOME Files" "Installed nautilus-python" "$(pm_install "$np")"
                else
                    NOTES+=("GNOME Files needs nautilus-python from $OS_NAME before it can show Backtrack's items.")
                fi
            fi
            step "Install Backtrack's Flatpak" "Installing Backtrack's Flatpak" "Installed Backtrack's Flatpak" \
                "flatpak install --user -y --noninteractive $FLATPAKREF"
            for fm in "${WANT[@]}"; do
                NOTES+=("Once Backtrack is set up, open Preferences, then General, and click Install beside $(fm_name "$fm").")
            done
            if wants nautilus; then
                NOTES+=("Then quit GNOME Files with nautilus -q, so it shows Backtrack's items when it opens again.")
            fi
            if [ "$NEW_FLATPAK" = 1 ]; then
                NOTES=("Log out and back in, then open Backtrack from your apps to set it up." "${NOTES[@]}")
            fi
            ;;
    esac
}

show_plan() {
    local lines=() i n=1
    for ((i = 0; i < ${#STEPS[@]}; i += 4)); do
        lines+=("$n  ${STEPS[i]}" "\$ ${STEPS[i + 3]}")
        n=$((n + 1))
    done
    for ((i = 0; i < ${#NOTES[@]}; i++)); do lines+=("Afterwards: ${NOTES[i]}"); done
    box "The plan: $(route_name "$ROUTE")" "${lines[@]}"
    if [ -n "$WHY" ]; then quiet "$WHY"; fi
}

#:## Your go-ahead
#: Up to here, nothing has changed. Where Backtrack has a package for your
#: system, you can choose the Flatpak instead, and the script shows the new
#: plan and asks again. If you say no, it stops.
confirm() {
    local answer choices
    while true; do
        plan
        show_plan
        choices='[Y/n]'
        [ "$ROUTE" = flatpak ] || choices='[Y/n, or f for the Flatpak]'
        answer=$(ask "Go ahead?" "$choices")
        while true; do
            case "$answer" in
                '' | y | yes) return ;;
                n | no)
                    printf '\n'
                    say "Nothing has changed. $SITE/install/ has every way to install Backtrack by hand."
                    exit 0
                    ;;
                f | flatpak) [ "$ROUTE" != flatpak ] && break ;;
            esac
            answer=$(ask "Go ahead?" "$choices")
        done
        ROUTE=flatpak WHY="You chose the Flatpak."
    done
}

#:## Your password
#: Most steps install packages, so they need sudo. Unless sudo already works
#: without one, it asks for a password once, before the first step: yours on
#: most systems, root's on openSUSE. The script never sees the password, and
#: it keeps sudo from timing out while a long step such as an AUR build runs.
password() {
    local i needs=0
    for ((i = 3; i < ${#STEPS[@]}; i += 4)); do
        case "${STEPS[i]}" in sudo* | *'&& sudo'* | yay* | paru* | *makepkg*) needs=1 ;; esac
    done
    [ "$needs" = 1 ] && [ "$DRY_RUN" = 0 ] || return 0
    if ! have sudo; then
        say "These steps need sudo, which isn't installed. $SITE/install/ has the commands to run as root yourself."
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        printf '\n'
        say "Some steps need sudo, so it asks for a password now."
        # sudo itself asks, on the terminal, even when the script came through a pipe.
        # shellcheck disable=SC2024
        sudo -v </dev/tty || exit 1
    fi
    (while kill -0 $$ 2>/dev/null; do
        sudo -n -v 2>/dev/null || exit 0
        sleep 50
    done) &
    KEEPALIVE=$!
}

#:## Installing
#: Then the steps run, one after another.
install_all() {
    if [ "$DRY_RUN" = 1 ]; then heading "What it would run"; else heading "Installing"; fi
    local i
    for ((i = 0; i < ${#STEPS[@]}; i += 4)); do
        run "${STEPS[i + 1]}" "${STEPS[i + 2]}" "${STEPS[i + 3]}"
    done
}

#:## Done
#: At the end, the script says what is left to do, if anything, and offers
#: to open Backtrack. It starts at its welcome page, ready to set up.
finish() {
    printf '\n'
    timeline forward
    local lines=()
    if [ "$DRY_RUN" = 1 ]; then
        lines+=("That was a dry run, so nothing changed. Run it without --dry-run to install Backtrack.")
    else
        if [ "${NEW_FLATPAK:-0}" = 1 ]; then
            lines+=("Backtrack is installed.")
        else
            lines+=("Backtrack is installed. Open it from your apps to set it up.")
        fi
    fi
    lines+=("${NOTES[@]}")
    if [ "$ROUTE" != flatpak ] && [ "$DRY_RUN" = 0 ] && wants nautilus; then
        lines+=("GNOME Files shows Backtrack's items the next time it opens.")
    fi
    box "Done" "${lines[@]}"
    quiet "Getting started: $SITE/guides/getting-started/"

    if [ "$DRY_RUN" = 0 ] && [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] && yes_to "Open Backtrack now?"; then
        if [ "$ROUTE" = flatpak ]; then
            setsid -f flatpak run "$APP_ID" >/dev/null 2>&1 </dev/null || true
        else
            setsid -f backtrack-gtk >/dev/null 2>&1 </dev/null || true
        fi
    fi
    printf '\n'
}

#:## The whole run
#: Everything above only defines what to do. This part does it, in order,
#: and its last line starts it. Because that line comes last, a download
#: cut short runs nothing at all.
cleanup() {
    cursor h
    [ -n "${KEEPALIVE:-}" ] && kill "$KEEPALIVE" 2>/dev/null
    [ -n "${WORK:-}" ] && rm -rf "$WORK"
    [ "${KEEP_LOG:-0}" = 1 ] || rm -f "${LOG:-}"
}

# A step runs in the background, where Ctrl+C does not reach it, so it is
# stopped here, with whatever it started.
stopped() {
    if [ -n "${STEP_PID:-}" ]; then
        pkill -TERM -P "$STEP_PID" 2>/dev/null || true
        kill -TERM "$STEP_PID" 2>/dev/null || true
    fi
    printf '\r\e[2K\n'
    say "Stopped. Steps that had finished stay done; $SITE/install/ explains each way to install Backtrack by hand."
    exit 130
}

main() {
    DRY_RUN=0
    local arg
    for arg in "$@"; do
        case "$arg" in
            --dry-run) DRY_RUN=1 ;;
            -h | --help)
                printf 'Usage: install.sh [--dry-run]\nInstalls Backtrack after asking. %s/install-script/ explains it.\n' "$SITE"
                exit 0
                ;;
            *)
                printf 'install.sh: unknown option %s (try --help)\n' "$arg" >&2
                exit 2
                ;;
        esac
    done

    setup_look
    LOG=$(mktemp "${TMPDIR:-/tmp}/backtrack-install.XXXXXX")
    trap cleanup EXIT
    trap stopped INT TERM

    printf '\n  %s%s%s %sBacktrack%s\n' "$ACC" "$REWIND" "$R" "$B" "$R"
    timeline back
    quiet "Hourly backups for the Linux desktop $MID $SITE"
    [ "$DRY_RUN" = 1 ] && printf '  %sDry run: nothing on this computer will change.%s\n' "$WARM" "$R"

    preflight
    look_around
    report
    if [ -n "$INSTALLED" ]; then
        already_here
        exit 0
    fi
    pointer "Best way" "$(route_name "$ROUTE")"
    choose_items
    confirm
    password
    install_all
    finish
}

main "$@"
