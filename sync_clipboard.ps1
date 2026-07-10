Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Clipboard Sync Monitor started (Base64 Mode)..."
$lastText = ""

while ($true) {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
            if ($text.StartsWith("CLIPBOARD_IMAGE_BASE64:") -and $text -ne $lastText) {
                
                $base64 = $text.Substring(23) # Length of "CLIPBOARD_IMAGE_BASE64:"
                $bytes = [System.Convert]::FromBase64String($base64)
                
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                $img = [System.Drawing.Image]::FromStream($ms)
                
                [System.Windows.Forms.Clipboard]::SetImage($img)
                
                $img.Dispose()
                $ms.Dispose()
                
                Write-Host "New screenshot converted to Windows clipboard!"
                $lastText = $text
            }
        }
    } catch {
        # Clipboard was busy, retry in next loop
    }
    Start-Sleep -Milliseconds 100
}
