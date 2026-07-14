Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Clipboard Sync Monitor started (Base64 Robust Mode)..."
$lastText = ""

while ($true) {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
            if ($text.StartsWith("CLIPBOARD_IMAGE_BASE64:") -and $text -ne $lastText) {
                Write-Host "New screenshot detected. Converting..."
                $lastText = $text
                
                $base64 = $text.Substring(23) # Length of "CLIPBOARD_IMAGE_BASE64:"
                $bytes = [System.Convert]::FromBase64String($base64)
                
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                $img = [System.Drawing.Image]::FromStream($ms)
                
                # Write the image to the clipboard repeatedly for 1.5 seconds.
                # This overrides any RDP clipboard sync feedback loops or clear events,
                # ensuring the image is active when the user presses Ctrl+V.
                for ($i = 0; $i -lt 15; $i++) {
                    [System.Windows.Forms.Clipboard]::SetImage($img)
                    Start-Sleep -Milliseconds 100
                }
                
                $img.Dispose()
                $ms.Dispose()
                
                Write-Host "Pasted successfully!"
            }
        }
    } catch {
        # Clipboard was busy, retry in next loop
    }
    Start-Sleep -Milliseconds 100
}
