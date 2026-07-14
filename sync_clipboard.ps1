Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Clipboard Sync Monitor started (Base64 Dual-Format with Native DIB)..."
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
                
                # Get raw BMP bytes
                $bmpStream = New-Object System.IO.MemoryStream
                $img.Save($bmpStream, [System.Drawing.Imaging.ImageFormat]::Bmp)
                $bmpBytes = $bmpStream.ToArray()
                $bmpStream.Dispose()
                
                # CF_DIB format MUST be written as a .NET MemoryStream (not a byte array)
                # to prevent .NET binary serialization, making it readable by native Windows apps like Outlook.
                $dibStream = New-Object System.IO.MemoryStream
                $dibStream.Write($bmpBytes, 14, $bmpBytes.Length - 14)
                $dibStream.Position = 0
                
                # Create a DataObject containing Bitmap, Native DIB, and the original text
                $data = New-Object System.Windows.Forms.DataObject
                $data.SetImage($img)
                $data.SetData("DeviceIndependentBitmap", $dibStream)
                $data.SetText($text)
                
                [System.Windows.Forms.Clipboard]::SetDataObject($data, $true)
                
                $img.Dispose()
                $ms.Dispose()
                $dibStream.Dispose()
                
                Write-Host "Converted successfully!"
            }
        }
    } catch {
        # Clipboard was busy, retry in next loop
    }
    Start-Sleep -Milliseconds 100
}
