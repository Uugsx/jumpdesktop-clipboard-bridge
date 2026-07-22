import Cocoa
import Foundation

let jumpBundleId = "com.p5sys.jump.mac.viewer"
let payloadPrefix = "CLIPBOARD_IMAGE_BASE64:"
let acknowledgementPrefix = "CLIPBOARD_IMAGE_ACK:"

class ClipboardAgent: NSObject {
    var lastChangeCount = NSPasteboard.general.changeCount
    private var lastBridgedImageData: Data?
    private var pendingImageData: Data?
    private var pendingPayloadId: String?
    
    override init() {
        super.init()
        
        // Register active application change observer
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(activeAppChanged),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )
        
        // Timer for clipboard checking (every 0.2 seconds)
        Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }

        // Process an existing payload after upgrades instead of waiting for the
        // pasteboard to change again.
        DispatchQueue.main.async { [weak self] in
            self?.processClipboard()
        }
    }
    
    @objc func activeAppChanged(_ notification: Notification) {
        processClipboard()
    }
    
    func checkClipboard() {
        let currentChangeCount = NSPasteboard.general.changeCount
        if currentChangeCount != lastChangeCount {
            lastChangeCount = currentChangeCount
            processClipboard()
        }
    }
    
    func processClipboard() {
        let pasteboard = NSPasteboard.general
        guard let types = pasteboard.types else { return }
        
        let hasImage = types.contains(.tiff) || types.contains(.png)
        let frontmostAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let isJumpActive = (frontmostAppId == jumpBundleId)
        
        var hasBase64Payload = false
        if types.contains(.string), let currentText = pasteboard.string(forType: .string) {
            if currentText.hasPrefix(acknowledgementPrefix),
               let pendingPayloadId,
               currentText.dropFirst(acknowledgementPrefix.count) == pendingPayloadId,
               let pendingImageData {
                // Windows decoded the payload. Restore the original image-only
                // clipboard and prevent Jump Desktop from bouncing text back. Keep
                // the pending state so repeated ACK writes are handled as well.
                removePayload(from: pasteboard, imageData: pendingImageData)
                return
            }

            if currentText.hasPrefix(payloadPrefix) {
                let payloadBody = currentText.dropFirst(payloadPrefix.count)
                if !payloadBody.contains(":"),
                   let imageBytes = Data(base64Encoded: String(payloadBody)),
                   let image = NSImage(data: imageBytes),
                   let tiffData = image.tiffRepresentation {
                    // Recover an image from a legacy payload. If Jump is active,
                    // the next pass republishes it using the acknowledged format.
                    removePayload(from: pasteboard, imageData: tiffData)
                    lastBridgedImageData = nil
                    pendingImageData = nil
                    pendingPayloadId = nil
                    if isJumpActive {
                        DispatchQueue.main.async { [weak self] in
                            self?.processClipboard()
                        }
                    }
                    return
                }

                hasBase64Payload = true
            }
        }
        
        if hasImage {
            guard let tiffData = pasteboard.data(forType: .tiff) else { return }

            // Expose the Base64 text only while Jump Desktop is frontmost.
            // A newly copied image must remain image-only in regular Mac apps.
            if isJumpActive && !hasBase64Payload && lastBridgedImageData != tiffData {
                let payloadId = UUID().uuidString
                var base64String = ""
                if let image = NSImage(data: tiffData),
                   let tiffRepresentation = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    base64String = pngData.base64EncodedString()
                } else {
                    base64String = tiffData.base64EncodedString()
                }
                
                let textPayload = payloadPrefix + payloadId + ":" + base64String
                
                let item = NSPasteboardItem()
                item.setData(tiffData, forType: .tiff)
                item.setString(textPayload, forType: .string)
                
                pasteboard.clearContents()
                pasteboard.writeObjects([item])
                self.lastChangeCount = pasteboard.changeCount
                self.lastBridgedImageData = tiffData
                self.pendingImageData = tiffData
                self.pendingPayloadId = payloadId
            } else if !isJumpActive && hasBase64Payload {
                // Remove payload when any Mac app (other than Jump) becomes active
                removePayload(from: pasteboard, imageData: tiffData)
                pendingImageData = nil
                pendingPayloadId = nil
            }

            if !isJumpActive {
                // Re-entering Jump Desktop should bridge the current image again.
                lastBridgedImageData = nil
            }
        }
    }

    private func removePayload(from pasteboard: NSPasteboard, imageData: Data) {
        let item = NSPasteboardItem()
        item.setData(imageData, forType: .tiff)

        pasteboard.clearContents()
        pasteboard.writeObjects([item])
        lastChangeCount = pasteboard.changeCount
    }
}

var globalAgent: ClipboardAgent?

func main() {
    globalAgent = ClipboardAgent()
    CFRunLoopRun()
}

main()
