import Cocoa
import Foundation

func getPasteboardChangeCount() -> Int {
    return NSPasteboard.general.changeCount
}

func processClipboard() {
    let pasteboard = NSPasteboard.general
    guard let types = pasteboard.types else { return }
    
    let hasImage = types.contains(.tiff) || types.contains(.png)
    
    var isProcessed = false
    if types.contains(.string), let currentText = pasteboard.string(forType: .string) {
        if currentText.hasPrefix("CLIPBOARD_IMAGE_BASE64:") {
            isProcessed = true
        }
    }
    
    if hasImage && !isProcessed {
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
    }
}

func main() {
    var lastChangeCount = getPasteboardChangeCount()
    while true {
        let currentChangeCount = getPasteboardChangeCount()
        if currentChangeCount != lastChangeCount {
            processClipboard()
            lastChangeCount = getPasteboardChangeCount()
        }
        Thread.sleep(forTimeInterval: 0.1)
    }
}

main()
