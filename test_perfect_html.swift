import Cocoa

let pb = NSPasteboard.general
pb.clearContents()

let htmlString = "<html><head><meta charset=\"utf-8\"></head><body><h1>Title</h1><p><b>Hello</b> <a href=\"https://google.com\">Google</a></p></body></html>"
let htmlData = htmlString.data(using: .utf8)!

if let htmlString = String(data: htmlData, encoding: .utf8),
   let htmlDoc = try? XMLDocument(xmlString: htmlString, options: .documentTidyHTML) {
    
    let xmlStr = htmlDoc.xmlString
    let cleanStr = xmlStr.replacingOccurrences(of: "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n", with: "")
    
    if let outData = cleanStr.data(using: .utf8) {
        pb.setData(outData, forType: .html)
        print("Generated HTML and set in PB")
    }
}
pb.setString("Fallback plain text", forType: .string)
