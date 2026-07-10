import Cocoa
import Foundation

let jumpBundleId = "com.p5sys.jump.mac.viewer"

func getPasteboardChangeCount() -> Int {
    return NSPasteboard.general.changeCount
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
        if isJumpActive && !hasBase64Payload {
            print("Jump Desktop active. Writing Base64 representation...")
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
            
        } else if !isJumpActive && hasBase64Payload {
            print("Jump Desktop inactive. Removing Base64 representation...")
            guard let tiffData = pasteboard.data(forType: .tiff) else { return }
            
            let item = NSPasteboardItem()
            item.setData(tiffData, forType: .tiff)
            
            pasteboard.clearContents()
            pasteboard.writeObjects([item])
        }
    }
}

func main() {
    print("Starting Swift Clipboard App-Aware Bridge Daemon...")
    var lastChangeCount = getPasteboardChangeCount()
    var lastFrontmostAppId: String? = nil
    
    while true {
        let currentChangeCount = getPasteboardChangeCount()
        let currentFrontmostAppId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        
        if currentChangeCount != lastChangeCount || currentFrontmostAppId != lastFrontmostAppId {
            processClipboard()
            lastChangeCount = getPasteboardChangeCount()
            lastFrontmostAppId = currentFrontmostAppId
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

main()
