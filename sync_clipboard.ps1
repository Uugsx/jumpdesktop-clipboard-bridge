Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Write-Host "Clipboard Sync Monitor started (Base64 Robust Mode)..."
$lastText = ""
$payloadPrefix = "CLIPBOARD_IMAGE_BASE64:"
$acknowledgementPrefix = "CLIPBOARD_IMAGE_ACK:"

while ($true) {
    try {
        if ([System.Windows.Forms.Clipboard]::ContainsText()) {
            $text = [System.Windows.Forms.Clipboard]::GetText()
            if ($text.StartsWith($payloadPrefix) -and $text -ne $lastText) {
                Write-Host "New screenshot detected. Converting..."
                
                $payload = $text.Substring($payloadPrefix.Length)
                $separatorIndex = $payload.IndexOf(":")
                if ($separatorIndex -le 0) {
                    throw "Unsupported payload format. Update the Mac bridge and try again."
                }

                $payloadId = $payload.Substring(0, $separatorIndex)
                $base64 = $payload.Substring($separatorIndex + 1)
                $bytes = [System.Convert]::FromBase64String($base64)
                
                $ms = New-Object System.IO.MemoryStream(,$bytes)
                $img = $null
                try {
                    $sourceImage = [System.Drawing.Image]::FromStream($ms)
                    $img = New-Object System.Drawing.Bitmap($sourceImage)
                    $sourceImage.Dispose()
                    
                    # Acknowledge receipt so the Mac can stop publishing Base64.
                    $acknowledgement = $acknowledgementPrefix + $payloadId
                    $acknowledgementSent = $false
                    for ($i = 0; $i -lt 15; $i++) {
                        try {
                            [System.Windows.Forms.Clipboard]::SetText($acknowledgement)
                            $acknowledgementSent = $true
                        } catch {
                            # Retry while the RDP clipboard is temporarily busy.
                        }
                        Start-Sleep -Milliseconds 100
                    }

                    if (-not $acknowledgementSent) {
                        throw "Could not acknowledge the payload through the clipboard."
                    }

                    # Keep the decoded image active while RDP synchronization settles.
                    $clipboardUpdated = $false
                    for ($i = 0; $i -lt 20; $i++) {
                        try {
                            [System.Windows.Forms.Clipboard]::SetDataObject($img, $true, 10, 100)
                            $clipboardUpdated = $true
                        } catch {
                            # Retry on the next pass when the clipboard is temporarily busy.
                        }
                        Start-Sleep -Milliseconds 100
                    }

                    if (-not $clipboardUpdated) {
                        throw "Could not write the decoded image to the clipboard."
                    }

                    # Mark the payload as handled only after the image was written.
                    $lastText = $text
                    Write-Host "Image is ready in the clipboard."
                } finally {
                    if ($null -ne $img) {
                        $img.Dispose()
                    }
                    $ms.Dispose()
                }
            }
        }
    } catch {
        Write-Warning "Clipboard conversion failed: $($_.Exception.Message). Retrying..."
    }
    Start-Sleep -Milliseconds 100
}
