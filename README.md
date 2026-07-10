# Jump Desktop Clipboard Image Sync Bridge

[Читать на русском (Russian Version)](README_RU.md)

This project provides a simple and fast workaround to enable direct copy-pasting of screenshots and images between macOS and a remote Windows session in **Jump Desktop**.

## The Problem
Jump Desktop does not support direct clipboard synchronization of image data (e.g., copying a screenshot on macOS and pasting it into Windows). It only synchronizes text clipboard entries.

## The Solution
This bridge solves the limitation by utilizing Jump Desktop's fast text synchronization:
1. **On macOS**: A background daemon monitors the clipboard. When you copy an image (e.g., taking a screenshot), it automatically converts the image to a Base64-encoded string and puts it in the clipboard as both an image (for Mac apps) and text (for the RDP session).
2. **Jump Desktop**: Automatically syncs the text payload to the Windows remote session clipboard instantly.
3. **On Windows**: A lightweight PowerShell script monitors the Windows clipboard. When it detects the encoded image text, it decodes it back to a raw image, replacing the text in the clipboard.

Now you can press `Ctrl + V` inside Windows (Outlook, Word, Explorer, Telegram) and the image will be pasted immediately!

---

## Installation & Setup

### 1. macOS Setup (Local Machine)
Run the following commands in the Terminal on your Mac:

```bash
# Clone the repository (or download the files)
cd jumpdesktop-clipboard-bridge

# Make installer executable and run it
chmod +x install.sh
./install.sh
```

This compiles the Swift helper daemon, saves it to `~/.jump_clipboard_bridge/`, and adds it to your macOS LaunchAgents so it runs in the background automatically upon login.

### 2. Windows Setup (Remote Machine)
No administrator rights are required on the remote Windows computer.

1. Copy the `sync_clipboard.ps1` script to your Windows machine (e.g., to the Desktop).
2. **How to run**: Right-click `sync_clipboard.ps1` and select **Run with PowerShell**.
3. Leave the PowerShell window open/minimized in the background.

*Tip: If you accidentally click inside the PowerShell window and its title starts with "Select" or "Выбрать", it will pause the script. Press `Enter` or `Esc` in the window to resume it. You can disable this by right-clicking the window title -> Properties -> unchecking "QuickEdit Mode".*

---

## How to Use
1. Take a screenshot on your Mac (e.g., using default macOS shortcuts or Flameshot) so it is copied to the clipboard.
2. Switch to your Jump Desktop session.
3. Press `Ctrl + V` inside any application (such as Outlook email editor, Word, or File Explorer). The screenshot will be pasted instantly.

---

## Uninstallation (macOS)
To stop and remove the Mac daemon:
```bash
launchctl unload ~/Library/LaunchAgents/com.jump.clipboard-bridge.plist
rm -f ~/Library/LaunchAgents/com.jump.clipboard-bridge.plist
rm -rf ~/.jump_clipboard_bridge
```
