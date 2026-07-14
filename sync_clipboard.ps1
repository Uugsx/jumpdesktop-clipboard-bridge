Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Clipboard Sync Monitor started (Base64 Stable DIB Mode)..."
$lastText = ""

while ($true) {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
            if ($text.StartsWith("CLIPBOARD_IMAGE_BASE64:") -and $text -ne $lastText) {
                Write-Host "Converting new screenshot..."
                $lastText = $text
                
                $base64 = $text.Substring(23) # Length of "CLIPBOARD_IMAGE_BASE64:"
                $bytes = [System.Convert]::FromBase64String($base64)
                
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                $img = [System.Drawing.Image]::FromStream($ms)
                
                # Get raw DIB (Device Independent Bitmap) bytes for Outlook compatibility.
                # DIB is the BMP file bytes minus the 14-byte BMP file header.
                $bmpStream = New-Object System.IO.MemoryStream
                $img.Save($bmpStream, [System.Drawing.Imaging.ImageFormat]::Bmp)
                $bmpBytes = $bmpStream.ToArray()
                $bmpStream.Dispose()
                
                $dibBytes = New-Object byte[] ($bmpBytes.Length - 14)
                [System.Array]::Copy($bmpBytes, 14, $dibBytes, 0, $dibBytes.Length)
                
                # Create a DataObject containing Bitmap, DIB, and a dummy text space " "
                # 1. The DIB format ensures Outlook/Word can paste the image.
                # 2. The text space " " prevents Jump Desktop from overwriting our image with the Base64 text.
                $data = New-Object System.Windows.Forms.DataObject
                $data.SetImage($img)
                $data.SetData("DeviceIndependentBitmap", $dibBytes)
                $data.SetText(" ")
                
                [System.Windows.Forms.Clipboard]::SetDataObject($data, $true)
                
                $img.Dispose()
                $ms.Dispose()
                
                Write-Host "Converted successfully!"
            }
        }
    } catch {
        # Clipboard was busy, retry in next loop
    }
    Start-Sleep -Milliseconds 100
}
