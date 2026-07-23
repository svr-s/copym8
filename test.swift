import Foundation
let doc = try XMLDocument(xmlString: "<html><a>Hello</a></html>", options: .documentTidyHTML)
let nodes = try doc.nodes(forXPath: "//a")
let link = nodes[0]
if let parent = link.parent {
    let index = link.index
    parent.replaceChild(at: index, with: XMLNode(kind: .text))
}
