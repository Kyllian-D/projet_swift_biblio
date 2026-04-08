import Foundation

// MARK: - Category model
struct Category: Codable, Sendable {
    let id: Int64?
    var name: String  // e.g. "AquaTYPHOON"
    var description: String  // short description
}

// MARK: - Endoscope model
struct Endoscope: Codable, Sendable {
    let id: Int64?
    var brand: String  // e.g. "Fujifilm"
    var model: String  // e.g. "EB-270P"
    var categoryId: Int64  // FK → categories.id
    var connectionSetRef: String  // e.g. "AF BR70/A"
    var pentaxItemNumber: String  // e.g. "301218-1"
    var cycleCode: String  // e.g. "BCU-BCU"
    var connectionCardCode: String  // e.g. "B05-032_3_302"  (raw from CSV)
    var notes: String  // free text, optional info

    // Derived: normalised card code used to match a PDF (upper-case, dashes→underscores)
    var normalisedCardCode: String {
        connectionCardCode
            .replacingOccurrences(of: "-", with: "_")
            .uppercased()
    }
}

// MARK: - PDF document index entry
struct PdfDocument: Codable, Sendable {
    let id: Int64?
    var fileName: String  // e.g. "b01_002_3_303_v03connectioncard..."
    var matchKey: String  // e.g. "B01_002_3_303"  (prefix up to the version token, upper-case)
    var documentKey: String  // e.g. "B01_002_3_303_V03"  (includes version, upper-case)
    var version: Int  // e.g. 3
}

// MARK: - View-model helper: endoscope + its category name + optional PDF
struct EndoscopeRow: Sendable {
    let endoscope: Endoscope
    let categoryName: String
    let pdf: PdfDocument?
}
