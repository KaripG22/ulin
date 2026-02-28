#!/bin/bash
set -e

echo "================================================================"
echo " 🎮 UNIVERSAL LINUX GAMING SETUP (ULIN) - V2.0 FAIL-SAFE"
echo "================================================================"

# ------------------------------------------------------------------------------
# FIX 1: THE AHCI GATEKEEPER
# ------------------------------------------------------------------------------
echo "🚨 CRITICAL BIOS CHECK:"
echo "If your motherboard storage controller is set to RAID, VMD, or Intel RST,"
echo "Windows will literally be blind and crash during the bootloader phase."

read -p "Have you verified your BIOS storage is set to AHCI/NVMe? (yes/no): " ahci_confirm
if [ "$ahci_confirm" != "yes" ]; then
    echo "❌ Please reboot, change BIOS storage to AHCI, and run this script again."
    exit 1
fi

# ------------------------------------------------------------------------------
# PHASE 1 & 2A: SYSTEM STATE DETECTION & HIBERNATION SWAPPER
# ------------------------------------------------------------------------------
WINDOWS_EXISTS=false
WIN_BOOT_ID=""

if efibootmgr | grep -iq "Windows Boot Manager"; then
    WINDOWS_EXISTS=true
    WIN_BOOT_ID=$(efibootmgr | grep -i "Windows Boot Manager" | head -n 1 | awk '{print $1}' | tr -dc '0-9A-F')
fi

if sudo blkid | grep -iq 'TYPE="ntfs"'; then
    WINDOWS_EXISTS=true
fi

if [ "$WINDOWS_EXISTS" = true ]; then
    echo "✅ Windows is already installed! Installing Hibernation Swapper..."
    SWAPPER_SCRIPT="/usr/local/bin/hibernate-to-windows.sh"
    sudo tee "$SWAPPER_SCRIPT" > /dev/null << EOF
#!/bin/bash
sudo efibootmgr --bootnext ${WIN_BOOT_ID}
systemctl hibernate
EOF
    sudo chmod +x "$SWAPPER_SCRIPT"

    DESKTOP_FILE="$HOME/Desktop/Play_Windows_Games.desktop"
    tee "$DESKTOP_FILE" > /dev/null << EOF
[Desktop Entry]
Version=1.0
Name=Play Windows Games
Exec=pkexec /usr/local/bin/hibernate-to-windows.sh
Icon=applications-games
Terminal=false
Type=Application
EOF
    chmod +x "$DESKTOP_FILE"
    echo "🎉 SUCCESS! Desktop shortcut created."
    exit 0
fi

# ------------------------------------------------------------------------------
# PHASE 2B: BARE-METAL DEPLOYMENT
# ------------------------------------------------------------------------------
read -p "📂 Enter the path to your Windows 11 ISO: " WINDOWS_ISO
if [ ! -f "$WINDOWS_ISO" ]; then
    echo "❌ Error: ISO file not found!"
    exit 1
fi

lsblk -d -p -o NAME,SIZE,MODEL | grep -v "loop"
read -p "⚠️ Type the exact drive to WIPE and install to: " TARGET_DRIVE
read -p "🚨 FINAL WARNING: Type 'DESTROY' to wipe $TARGET_DRIVE and begin: " confirm
if [ "$confirm" != "DESTROY" ]; then
    echo "Aborted."
    exit 1
fi

WIN_SIZE="150GiB"

echo "📦 Installing required deployment tools..."
sudo apt-get update -qq
sudo apt-get install -y wimtools ntfs-3g parted > /dev/null

echo "🔗 Mounting ISO temporarily to read versions..."
sudo mkdir -p /mnt/iso
sudo mount -o loop "$WINDOWS_ISO" /mnt/iso

# ------------------------------------------------------------------------------
# FIX 2: THE WIM INDEX ROULETTE
# ------------------------------------------------------------------------------
echo "💿 Scanning Windows ISO for available editions..."

sudo wiminfo /mnt/iso/sources/install.wim | grep -E "Index:|Name:"
echo "----------------------------------------------------------------"
read -p "Enter the Index number for the edition you want (e.g., 6 for Pro): " WIM_INDEX

echo "🪚 Wiping drive and creating Dual-Boot layout..."
sudo parted -s "$TARGET_DRIVE" mklabel gpt
sudo parted -s "$TARGET_DRIVE" mkpart "EFI" fat32 1MiB 513MiB
sudo parted -s "$TARGET_DRIVE" set 1 esp on
sudo parted -s "$TARGET_DRIVE" mkpart "Windows" ntfs 513MiB "$WIN_SIZE"
sudo parted -s "$TARGET_DRIVE" mkpart "LinuxSpace" ext4 "$WIN_SIZE" 100%

echo "🧹 Formatting partitions..."
sudo mkfs.fat -F32 "${TARGET_DRIVE}p1"
sudo mkfs.ntfs -f -L "WINDOWS" "${TARGET_DRIVE}p2"

echo "🔗 Mounting new partitions..."
sudo mkdir -p /mnt/windows /mnt/efi
sudo mount "${TARGET_DRIVE}p2" /mnt/windows
sudo mount "${TARGET_DRIVE}p1" /mnt/efi

echo "⏳ Extracting Windows directly to bare metal..."
sudo wimlib-imagex apply /mnt/iso/sources/install.wim $WIM_INDEX /mnt/windows

# ------------------------------------------------------------------------------
# PHASE 3: THE TROJAN HORSE & FAIL-SAFES
# ------------------------------------------------------------------------------
echo "🛠️ Preparing Windows PE bootloader Trojan Horse..."
sudo cp /mnt/iso/sources/boot.wim /tmp/boot.wim

cat << 'EOF' | sed 's/$/\r/' > /tmp/startnet.cmd
@echo off
echo Generating Windows Bootloader for Bare Metal...
bcdboot C:\Windows
echo Complete! Rebooting into Windows 11...
wpeutil reboot
EOF

cat << 'EOF' > /tmp/update_commands.txt
add /tmp/startnet.cmd \Windows\System32\startnet.cmd
EOF

sudo wimlib-imagex update /tmp/boot.wim 2 < /tmp/update_commands.txt

echo "🚚 Copying boot files to EFI partition..."
sudo cp -r /mnt/iso/efi /mnt/efi/
sudo mkdir -p /mnt/efi/sources
sudo cp /tmp/boot.wim /mnt/efi/sources/boot.wim

# ------------------------------------------------------------------------------
# FIX 3: THE UEFI FALLBACK PATH (Anti-NVRAM Lock)
# ------------------------------------------------------------------------------
echo "🛡️ Setting up UEFI Fallback Path..."
sudo mkdir -p /mnt/efi/EFI/BOOT
# Motherboards inherently look for BOOTX64.EFI if NVRAM entries fail
sudo cp /mnt/iso/efi/boot/bootx64.efi /mnt/efi/EFI/BOOT/BOOTX64.EFI

sudo efibootmgr --create --disk "$TARGET_DRIVE" --part 1 --label "Windows Setup Generator" --loader '\efi\boot\bootx64.efi' || echo "⚠️ efibootmgr failed, but UEFI fallback is in place!"

# ------------------------------------------------------------------------------
# FIX 4: THE BITLOCKER KILLSWITCH IN UNATTEND.XML
# ------------------------------------------------------------------------------
echo "📝 Injecting Auto-Login and BitLocker Killswitch..."
sudo mkdir -p /mnt/windows/Windows/Panther

cat << 'EOF' | sudo tee /mnt/windows/Windows/Panther/unattend.xml > /dev/null
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
                <HideOEMRegistrationScreen>true</HideOEMRegistrationScreen>
                <HideOnlineAccountScreens>true</HideOnlineAccountScreens>
                <HideWirelessSetupInOOBE>true</HideWirelessSetupInOOBE>
                <ProtectYourPC>3</ProtectYourPC>
            </OOBE>
            <UserAccounts>
                <LocalAccounts>
                    <LocalAccount wcm:action="add">
                        <Name>Gamer</Name>
                        <Group>Administrators</Group>
                        <Password><Value></Value><PlainText>true</PlainText></Password>
                    </LocalAccount>
                </LocalAccounts>
            </UserAccounts>
            <AutoLogon>
                <Password><Value></Value><PlainText>true</PlainText></Password>
                <Enabled>true</Enabled>
                <LogonCount>9999999</LogonCount>
                <Username>Gamer</Username>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <CommandLine>reg add "HKLM\SYSTEM\CurrentControlSet\Control\BitLocker" /v "PreventDeviceEncryption" /t REG_DWORD /d 1 /f</CommandLine>
                    <Description>Disable Auto BitLocker</Description>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
EOF

echo "🧽 Cleaning up..."
sudo umount /mnt/iso /mnt/windows /mnt/efi

echo "======================================================================"
echo "🎉 DEPLOYMENT COMPLETE! YOUR SYSTEM IS READY."
echo "======================================================================"
