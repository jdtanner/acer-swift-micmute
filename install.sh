#!/bin/bash
# Acer Swift SF314-44 mic-mute key and LED fix
# Author: John Hill-Tanner
#
# Run with sudo from the repository root: sudo ./install.sh

set -e
cd "$(dirname "$0")"

# --- Pre-flight checks ---

if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run this script with sudo."
    exit 1
fi

if [ -z "$SUDO_USER" ]; then
    echo "ERROR: SUDO_USER is not set. Please run with sudo rather than as root directly."
    exit 1
fi

if [ "$(cat /sys/class/dmi/id/product_name)" != "Swift SF314-44" ]; then
    echo "WARNING: This laptop is '$(cat /sys/class/dmi/id/product_name)', not a Swift SF314-44."
    echo "         The key remap only matches the SF314-44, and the LED pin may differ."
    read -r -p "Continue anyway? [y/N] " answer
    [[ $answer == [yY] ]] || exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_UID=$(id -u "$SUDO_USER")

# --- 1. hda-verb, used to switch the LED pin on the Realtek codec ---

if ! command -v hda-verb >/dev/null; then
    echo "Installing alsa-tools (for hda-verb)..."
    dnf install -y alsa-tools
fi

# alsa-tools also brings mixer apps for pro sound cards, which are no use here.
# Hide their launchers from the app grid for this user (the apps stay installed).
echo "Hiding alsa-tools launchers from the app grid..."
for f in $(rpm -ql alsa-tools | grep '\.desktop$'); do
    target="$USER_HOME/.local/share/applications/$(basename "$f")"
    { cat "$f"; echo "NoDisplay=true"; } > "$target.tmp"
    install -D -m 644 -o "$SUDO_USER" -g "$SUDO_USER" "$target.tmp" "$target"
    rm -f "$target.tmp"
done

# --- 2. Remap F4 from F15 to micmute ---

echo "Installing key remap..."
install -m 644 files/61-acer-swift-sf314-44-micmute.hwdb /etc/udev/hwdb.d/
systemd-hwdb update
udevadm trigger --subsystem-match=input --action=change

# --- 3. Root helper that switches the LED, and a sudo rule for it ---

echo "Installing LED helper..."
install -m 755 files/micmute-led-set /usr/local/sbin/
echo "$SUDO_USER ALL=(root) NOPASSWD: /usr/local/sbin/micmute-led-set on, /usr/local/sbin/micmute-led-set off" \
    > /etc/sudoers.d/micmute-led
chmod 440 /etc/sudoers.d/micmute-led
visudo -cf /etc/sudoers.d/micmute-led

# --- 4. User service that keeps the LED in step with the mic ---

echo "Installing LED sync service for $SUDO_USER..."
install -D -m 755 -o "$SUDO_USER" -g "$SUDO_USER" files/micmute-led-sync "$USER_HOME/.local/bin/micmute-led-sync"
install -D -m 644 -o "$SUDO_USER" -g "$SUDO_USER" files/micmute-led.service "$USER_HOME/.config/systemd/user/micmute-led.service"
sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user daemon-reload
sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user enable --now micmute-led.service

echo
echo "Done. Log out and back in so GNOME picks up the new F4 key."
