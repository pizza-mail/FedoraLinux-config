#!/bin/bash
set -e

trap 'echo "ERROR on line $LINENO. Press Enter to exit."; read' ERR

# 1. Enable parallel downloads and update
echo "max_parallel_downloads=10" | sudo tee -a /etc/dnf/dnf.conf

sudo dnf update -y

# 2. Add RPM Fusion repos + other repos
sudo dnf install -y \
    https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
    https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf install dnf-plugins-core -y

# 3. Enable Cisco OpenH264 repo
sudo dnf config-manager setopt fedora-cisco-openh264.enabled=1

# 4. Install system packages, codecs, and explicit python dependencies
sudo dnf install -y \
    git \
    make \
    scdoc \
    python3-build \
    python3-hatchling \
    python3-installer \
    python3-pip \
    python3-filelock \
    python3-packaging \
    rpmfusion-*-appstream-data \
    libavcodec-freeworld \
    bubblewrap \
    python3-gobject \
    python3-requests \
    python3-pillow \
    7zip \
    wget

# 5. Umu-launcher Build & Native Setup
pushd /tmp > /dev/null

rm -rf umu-launcher

git clone https://github.com/Open-Wine-Components/umu-launcher.git
  
pushd umu-launcher > /dev/null

python3 -m build --wheel --no-isolation

sudo python3 -m pip install dist/*.whl --break-system-packages

popd > /dev/null

rm -rf umu-launcher

popd > /dev/null


# 6. Swap to full ffmpeg (best quality)
sudo dnf swap -y --allowerasing ffmpeg-free ffmpeg || sudo dnf install -y ffmpeg

# 7. Update multimedia and sound groups
sudo dnf group upgrade -y multimedia --setopt="install_weak_deps=False" \
    --exclude=PackageKit-gstreamer-plugin --skip-unavailable

sudo dnf install -y pipewire-jack-audio-connection-kit

sudo dnf group upgrade -y sound-and-video --skip-unavailable

amixer -D hw:Generic_1 sset "Auto-Mute Mode" Disabled

sudo alsactl store

# 8. Game launchers + prerequisite 
sudo dnf install -y mesa-vulkan-drivers mesa-vulkan-drivers.i686 vulkan-tools

sudo dnf install steam -y

sudo dnf -y copr enable faugus/faugus-launcher
sudo dnf -y install faugus-launcher

# 9. Flatpak and flatpak apps
flatpak remote-delete --force flathub || true

flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

flatpak install flathub dev.vencord.Vesktop -y

flatpak install flathub eu.betterbird.Betterbird -y

flatpak uninstall --unused

# 10. Dual-monitor nightight fix ( rare case for my hardware ) 
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

# 11. Brave Origin
sudo dnf config-manager addrepo --from-repofile=https://brave-browser-rpm-nightly.s3.brave.com/brave-browser-nightly.repo

sudo dnf install brave-origin-nightly -y

# 12. Enable custom volume keys
gsettings set org.gnome.settings-daemon.plugins.media-keys volume-up "['Page_Up']"

gsettings set org.gnome.settings-daemon.plugins.media-keys volume-down "['Page_Down']"

gsettings set org.gnome.settings-daemon.plugins.media-keys volume-mute "['End']"

# 13. Kernel optimizations
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

# 14. System debloat
sudo dnf remove -y firefox firefox-langpacks
sudo dnf remove -y libreoffice*
    
sudo dnf autoremove -y
sudo dnf clean all

#14. Clipboard
gsettings set org.gnome.shell.keybindings show-screenshot-ui "['<Ctrl>bracketleft']"

sudo dnf install libgda libgda-sqlite gsound -y

curl -L https://github.com/boerdereinar/copyous/releases/latest/download/copyous@boerdereinar.dev.zip -o /tmp/copyous.zip

mkdir -p ~/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev

unzip -o /tmp/copyous.zip -d ~/.local/share/gnome-shell/extensions/copyous@boerdereinar.dev/

rm /tmp/copyous.zip

echo "Setup complete! Please restart your computer to apply all changes."

# Note to self, run this after the restart is done.
# gnome-extensions enable copyous@boerdereinar.dev


