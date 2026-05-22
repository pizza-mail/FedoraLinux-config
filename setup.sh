#!/bin/bash
set -e

trap 'echo "ERROR on line $LINENO. Press Enter to exit."; read' ERR

# 1. Enable parallel downloads and update

echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf

sudo dnf update -y

# 2. Add RPM Fusion repos (free + nonfree)
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

# 3. Enable Cisco OpenH264 repo
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

# 4. Install useful packages + appstream data in one transaction
sudo dnf install -y \
    rpmfusion-*-appstream-data \
    libavcodec-freeworld \
    umu-launcher \
    bubblewrap \
    python3-gobject \
    python3-requests \
    python3-pillow \
    p7zip \
    p7zip-plugins \
    wget

# 5. Swap to full ffmpeg (best quality)
sudo dnf swap -y --allowerasing ffmpeg-free ffmpeg

# 6. Update multimedia and sound groups
sudo dnf groupupdate -y multimedia --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin

sudo dnf install -y pipewire-jack-audio-connection-kit

sudo dnf groupupdate -y sound-and-video

# 7. Game launchers + prerequisite 

sudo dnf install -y mesa-vulkan-drivers mesa-vulkan-drivers.i386 vulkan-tools

sudo dnf install steam -y

sudo dnf -y copr enable faugus/faugus-launcher
sudo dnf -y install faugus-launcher

# 8. Flatpak and flatpak apps

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo 

flatpak install flathub dev.vencord.Vesktop -y

flatpak install flathub eu.betterbird.Betterbird -y

# 9. Dual-monitor nightight fix ( rare case for my hardware ) 

sudo mkdir -p /usr/lib/firmware/edid
 
sudo cp /sys/class/drm/card*-HDMI-A-1/edid /usr/lib/firmware/edid/edid-mod.bin

sudo python3 -c "
with open('/usr/lib/firmware/edid/edid-mod.bin', 'rb') as f:
    data = bytearray(f.read())
 
idx = data.find(b'\x01\x01\x01\x01')
if idx != -1:
    data[idx+3] = 0x02
 
    data[127] = 0
    modulo_sum = sum(data[:128]) % 256
    data[127] = (256 - modulo_sum) % 256
 
    with open('/usr/lib/firmware/edid/edid-mod.bin', 'wb') as f:
        f.write(data)
    print('Identity mutated and VESA Checksum corrected!')
else:
    print('Pattern not found!')
"
 
echo 'install_items+=" /usr/lib/firmware/edid/edid-mod.bin "' | sudo tee /etc/dracut.conf.d/99-local-edid.conf
 
sudo grubby --update-kernel=ALL --args="drm.edid_firmware=HDMI-A-1:edid/edid-mod.bin"
 
sudo dracut --force --verbose

# 10. Brave Origin

sudo dnf install dnf-plugins-core -y

sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-nightly.s3.brave.com/brave-browser-nightly.repo

sudo dnf install brave-origin-nightly -y

# 11. Enable custom volume keys

gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['Page_Up']"

gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['Page_Down']"

gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['End']"

# 12. Kernel optimizations

if ! sudo grep -q "^vm.swappiness=" /etc/sysctl.d/99-sysctl.conf; then
    echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
else
    sudo sed -i 's/^vm.swappiness=.*/vm.swappiness=10/' /etc/sysctl.d/99-sysctl.conf
fi

if ! sudo grep -q "^kernel.sysrq=" /etc/sysctl.d/99-sysctl.conf; then
    echo 'kernel.sysrq=1' | sudo tee -a /etc/sysctl.d/99-sysctl.conf
else
    sudo sed -i 's/^kernel.sysrq=.*/kernel.sysrq=1/' /etc/sysctl.d/99-sysctl.conf
fi

sudo sysctl --system

# 13. System debloat

sudo dnf remove -y \
    firefox firefox-langpacks \
    libreoffice* \
    gnome-boxes \
    gnome-tour \
    cheese \
    gnome-weather \
    gnome-maps \
    gnome-characters \
    simple-scan \
    gnome-font-viewer
    
sudo dnf autoremove -y

echo "Setup complete! Please restart your computer to apply all changes."


