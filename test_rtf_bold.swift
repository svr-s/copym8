import Cocoa

let rtfString = "{\\rtf1\\ansi\\ansicpg1252\\cocoartf2757\n\\cocoatextscaling0\\cocoaplatform0{\\fonttbl\\f0\\fswiss\\fcharset0 Helvetica;}\n{\\colortbl;\\red255\\green255\\blue255;\\red0\\green0\\blue238;}\n{\\*\\expandedcolortbl;;\\cssrgb\\c0\\c0\\c93333;}\n\\paperw11900\\paperh16840\\margl1440\\margr1440\\vieww11520\\viewh8400\\viewkind0\n\\pard\\tx720\\tx1440\\tx2160\\tx2880\\tx3600\\tx4320\\tx5040\\tx5760\\tx6480\\tx7200\\tx7920\\tx8640\\pardirnatural\\partightenfactor0\n\n\\f0\\fs24 \\cf0 Hello \\b {\\field{\\*\\fldinst{HYPERLINK \"https://google.com\"}}{\\fldrslt \\cf2 \\ul \\ulc2 Google}}}"
let rtfData = rtfString.data(using: .utf8)!

if let attrString = try? NSMutableAttributedString(data: rtfData, options: [.documentType: NSAttributedString.DocumentType.rtf], documentAttributes: nil) {
    attrString.enumerateAttribute(.link, in: NSRange(location: 0, length: attrString.length), options: []) { value, range, _ in
        if value != nil {
            attrString.removeAttribute(.link, range: range)
            attrString.removeAttribute(.foregroundColor, range: range)
            attrString.removeAttribute(.underlineStyle, range: range)
        }
    }
    
    if let outRtf = try? attrString.data(from: NSRange(location: 0, length: attrString.length), documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]) {
        let outStr = String(data: outRtf, encoding: .utf8) ?? ""
        print("Output RTF contains bold? \(outStr.contains("\\b "))")
        print(outStr.prefix(200))
    }
}
