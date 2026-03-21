import Foundation
import UniformTypeIdentifiers

/// Drag-and-drop transfer payload for banks
struct BankTransferPayload: Codable {
    let bankName: String
    let catalogIndex: Int
    let sourceImagePath: String
    
    var jsonData: Data? {
        try? JSONEncoder().encode(self)
    }
    
    static func from(data: Data) -> BankTransferPayload? {
        try? JSONDecoder().decode(BankTransferPayload.self, from: data)
    }
}

extension UTType {
    static var emaxBank: UTType {
        UTType(exportedAs: "ai.vintage.emaxforge.bank")
    }
}
