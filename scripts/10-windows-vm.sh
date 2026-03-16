#!/usr/bin/env bash
set -euo pipefail

info()  { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()  { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }

VM_DIR="$HOME/VMs"
VM_NAME="win11"
DISK="$VM_DIR/$VM_NAME.qcow2"
DISK_SIZE="80G"
VIRTIO_ISO="$VM_DIR/virtio-win.iso"
VIRTIO_URL="https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/stable-virtio/virtio-win.iso"
WIN_ISO="$VM_DIR/Win11_Enterprise_Eval.iso"

# --- Install QEMU/KVM + virt-manager ---
info "Installing QEMU/KVM and virt-manager..."
sudo dnf install -y @virtualization qemu-kvm libvirt virt-manager virt-install \
    virt-viewer edk2-ovmf swtpm qemu-img spice-gtk-tools

# --- Enable libvirtd ---
info "Enabling libvirtd..."
sudo systemctl enable --now libvirtd
sudo virsh net-start default 2>/dev/null || true
sudo virsh net-autostart default 2>/dev/null || true

# --- Add user to libvirt group ---
if ! groups "$USER" 2>/dev/null | grep -q libvirt; then
    info "Adding $USER to libvirt group..."
    sudo usermod -aG libvirt "$USER"
else
    info "$USER already in libvirt group."
fi

# --- Create VM directory and grant qemu access ---
mkdir -p "$VM_DIR"
sudo setfacl -m u:qemu:x "$HOME"
sudo setfacl -R -m u:qemu:rx "$VM_DIR"

# --- Download VirtIO drivers ISO ---
if [[ ! -f "$VIRTIO_ISO" ]]; then
    info "Downloading VirtIO Windows drivers (~750 MB)..."
    curl -fLo "$VIRTIO_ISO" "$VIRTIO_URL"
else
    info "VirtIO drivers ISO already present."
fi

# --- Check for Windows 11 ISO (requires manual browser download) ---
if [[ ! -f "$WIN_ISO" ]]; then
    warn "Windows 11 ISO not found at $WIN_ISO"
    info ""
    info "Download it manually from Microsoft's Evaluation Center:"
    info "  https://www.microsoft.com/en-us/evalcenter/download-windows-11-enterprise"
    info ""
    info "Then move/rename it to: $WIN_ISO"
    info "Re-run this script afterward to create the VM."
    exit 0
fi

# --- Create VM disk ---
if [[ ! -f "$DISK" ]]; then
    info "Creating $DISK_SIZE VM disk at $DISK..."
    qemu-img create -f qcow2 "$DISK" "$DISK_SIZE"
else
    info "VM disk already exists at $DISK."
fi

# --- Create the Windows 11 VM ---
if ! sudo virsh dominfo "$VM_NAME" &>/dev/null; then
    info "Creating Windows 11 VM ($VM_NAME)..."
    virt-install \
        --connect qemu:///system \
        --name "$VM_NAME" \
        --ram 8192 \
        --vcpus 4 \
        --cpu host-passthrough \
        --os-variant win11 \
        --disk path="$DISK",format=qcow2,bus=virtio \
        --cdrom "$WIN_ISO" \
        --disk path="$VIRTIO_ISO",device=cdrom \
        --network network=default,model=virtio \
        --graphics spice,listen=none \
        --video qxl \
        --channel spicevmc \
        --boot uefi \
        --tpm backend.type=emulator,backend.version=2.0,model=tpm-crb \
        --noautoconsole \
        --wait 0
    info "VM '$VM_NAME' created. Open virt-manager to complete Windows installation."
else
    info "VM '$VM_NAME' already exists."
fi

info "Windows VM setup complete."
info ""
info "Next steps:"
info "  1. Open virt-manager (or run: virt-manager)"
info "  2. Start the '$VM_NAME' VM and complete Windows installation"
info "  3. During disk selection, load VirtIO drivers from the second CD drive"
info "     (Browse to virtio-win CD > amd64 > w11)"
info "  4. After install, mount the VirtIO CD inside Windows and run virtio-win-guest-tools.exe"
