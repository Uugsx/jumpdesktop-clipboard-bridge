import Cocoa
import Foundation

let jumpBundleId = "com.p5sys.jump.mac.viewer"

class ClipboardAgent: NSObject {
    var lastChangeCount = NSPasteboard.general.changeCount
    
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
            if currentText.hasPrefix("CLIPBOARD_IMAGE_BASE64:") {
                hasBase64Payload = true
            }
        }
        
        if hasImage {
            // Expose the Base64 text only while Jump Desktop is frontmost.
            // A newly copied image must remain image-only in regular Mac apps.
            if isJumpActive && !hasBase64Payload {
                guard let tiffData = pasteboard.data(forType: .tiff) else { return }
                
                var base64String = ""
                if let image = NSImage(data: tiffData),
                   let tiffRepresentation = image.tiffRepresentation,
                   let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
                   let pngData = bitmapImage.representation(using: .png, properties: [:]) {
                    base64String = pngData.base64EncodedString()
                } else {
                    base64String = tiffData.base64EncodedString()
                }
                
                let textPayload = "CLIPBOARD_IMAGE_BASE64:" + base64String
                
                let item = NSPasteboardItem()
                item.setData(tiffData, forType: .tiff)
                item.setString(textPayload, forType: .string)
                
                pasteboard.clearContents()
                pasteboard.writeObjects([item])
                self.lastChangeCount = pasteboard.changeCount
            } else if !isJumpActive && hasBase64Payload {
                // Remove payload when any Mac app (other than Jump) becomes active
                guard let tiffData = pasteboard.data(forType: .tiff) else { return }
                
                let item = NSPasteboardItem()
                item.setData(tiffData, forType: .tiff)
                
                pasteboard.clearContents()
                pasteboard.writeObjects([item])
                self.lastChangeCount = pasteboard.changeCount
            }
        }
    }
}

var globalAgent: ClipboardAgent?

func main() {
    globalAgent = ClipboardAgent()
    CFRunLoopRun()
}

main()
