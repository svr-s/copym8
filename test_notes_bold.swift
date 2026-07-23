import Cocoa

let pb = NSPasteboard.general
pb.clearContents()

let htmlString = "<html><body><p>Normal text without any bold tags.</p></body></html>"
let htmlData = htmlString.data(using: .utf8)!

if let htmlDoc = try? XMLDocument(xmlString: htmlString, options: .documentTidyHTML) {
    let xmlStr = htmlDoc.xmlString
    let cleanHtmlStr = xmlStr.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", with: "")
    if let outData = cleanHtmlStr.data(using: .utf8) {
        pb.setData(outData, forType: .html)
        print("XHTML set on PB")
    }
}
pb.setString("Fallback plain text", forType: .string)
