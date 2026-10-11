# Acer Swift 3 Mic-Mute Key and LED Fix

![Fedora](https://img.shields.io/badge/Fedora-45-294172?style=flat&logo=fedora&logoColor=white)
![GNOME](https://img.shields.io/badge/GNOME-Wayland-4A86CF?style=flat&logo=gnome&logoColor=white)
![Shell](https://img.shields.io/badge/Shell-Bash-4EAA25?style=flat&logo=gnubash&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow?style=flat)

Makes the F4 mic-mute key on the Acer Swift 3 (SF314-44, Ryzen) actually mute
the microphone on Linux, and makes the little LED on the key show whether the
mic is muted.

---

## The problem

On a stock Fedora install, two things are broken:

**1. F4 does nothing.**
The keyboard reports F4 as `KEY_F15` (scancodes `0x66` and `0x5f`) instead of
`KEY_MICMUTE`, and there is no entry for this model in systemd's keyboard
database. GNOME ignores F15, so the mic never mutes.

**2. The LED never lights.**
The LED is wired to GPIO pin 3 (mask `0x04`) on the Realtek ALC256 audio codec,
but the kernel has no quirk for this laptop, so nothing drives it. A kernel
quirk would not be enough anyway: the built-in mic is the AMD ACP digital mic,
a separate device from the Realtek codec, so a kernel LED tied to the codec's
capture switch would follow the wrong microphone.

---

## What this does

- **Key remap:** a udev hwdb rule, matched to the SF314-44 only, turns F4 into
  `KEY_MICMUTE`. GNOME then mutes and unmutes the default mic and shows its
  usual on-screen icon.
- **LED:** a small user service watches the default mic's mute state (through
  `pactl subscribe`) and switches the codec's GPIO pin to match. It re-applies
  the state every 60 seconds in case suspend resets the pin.

Writing to the codec needs root, because the kernel requires `CAP_SYS_RAWIO`
for raw HDA commands, whatever the device file permissions say. So the LED is
switched by a tiny root-owned helper that only accepts `on` or `off`, plus a
sudo rule that lets your user run exactly those two commands without a
password.

---

## Install

```bash
git clone https://github.com/jdtanner/acer-swift-micmute.git
cd acer-swift-micmute
sudo ./install.sh
```

Then **log out and back in** so GNOME picks up the new key.

The installer adds `alsa-tools` (for `hda-verb`) if it is missing.

## Uninstall

```bash
sudo ./uninstall.sh
```

`alsa-tools` is left installed.

---

## Files installed

| File | Purpose |
| --- | --- |
| `/etc/udev/hwdb.d/61-acer-swift-sf314-44-micmute.hwdb` | Remaps F4 to mic-mute |
| `/usr/local/sbin/micmute-led-set` | Root helper: switches the LED `on` or `off` |
| `/etc/sudoers.d/micmute-led` | Lets your user run only that helper, without a password |
| `~/.local/bin/micmute-led-sync` | Watches the mic mute state and calls the helper |
| `~/.config/systemd/user/micmute-led.service` | Starts the watcher with your GNOME session |

---

## Other Acer models

The same approach may work on other Acer laptops with a Realtek codec. To
check yours:

1. Find what F4 sends: `sudo libinput debug-events --show-keycodes`, then press it.
2. Find the LED pin by switching codec GPIOs on one at a time, for example:
   ```bash
   sudo hda-verb /dev/snd/hwC1D0 0x01 SET_GPIO_MASK 0x07
   sudo hda-verb /dev/snd/hwC1D0 0x01 SET_GPIO_DIR 0x07
   sudo hda-verb /dev/snd/hwC1D0 0x01 SET_GPIO_DATA 0x04   # try 0x01, 0x02, 0x04
   ```
   (Check `/proc/asound/cards` for the right card number.)
3. Adjust the DMI match in the `.hwdb` file and the mask in `micmute-led-set`.

## Tested on

- Acer Swift 3 SF314-44, BIOS 1.18
- Fedora 45, kernel 7.2, GNOME on Wayland, PipeWire
