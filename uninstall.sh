#!/bin/bash
# Removes everything install.sh added (alsa-tools is left installed)
# Run with sudo: sudo ./uninstall.sh

if [ "$EUID" -ne 0 ] || [ -z "$SUDO_USER" ]; then
    echo "ERROR: Please run this script with sudo."
    exit 1
fi

USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
USER_UID=$(id -u "$SUDO_USER")

sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user disable --now micmute-led.service
/usr/local/sbin/micmute-led-set off

rm -f "$USER_HOME/.config/systemd/user/micmute-led.service" \
      "$USER_HOME/.local/bin/micmute-led-sync" \
      /etc/sudoers.d/micmute-led \
      /usr/local/sbin/micmute-led-set \
      /etc/udev/hwdb.d/61-acer-swift-sf314-44-micmute.hwdb

# Unhide the alsa-tools launchers that install.sh hid
for f in $(rpm -ql alsa-tools 2>/dev/null | grep '\.desktop$'); do
    rm -f "$USER_HOME/.local/share/applications/$(basename "$f")"
done

sudo -u "$SUDO_USER" XDG_RUNTIME_DIR="/run/user/$USER_UID" systemctl --user daemon-reload
systemd-hwdb update
udevadm trigger --subsystem-match=input --action=change

echo "Removed. Log out and back in to finish."
