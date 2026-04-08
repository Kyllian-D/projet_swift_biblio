import Foundation
import SQLite

// Connection utilise une file série interne, il est donc sur de la marquer Sendable
extension Connection: @unchecked @retroactive Sendable {}

struct Database {

    // MARK: - Descripteurs de tables

    // categories
    static let categories = Table("categories")
    static let catId = Expression<Int64>("id")
    static let catName = Expression<String>("name")
    static let catDescription = Expression<String>("description")

    // endoscopes
    static let endoscopes = Table("endoscopes")
    static let endId = Expression<Int64>("id")
    static let endBrand = Expression<String>("brand")
    static let endModel = Expression<String>("model")
    static let endCategoryId = Expression<Int64>("category_id")
    static let endConnSetRef = Expression<String>("connection_set_ref")
    static let endPentaxItem = Expression<String>("pentax_item_number")
    static let endCycleCode = Expression<String>("cycle_code")
    static let endCardCode = Expression<String>("connection_card_code")
    static let endNotes = Expression<String>("notes")

    // pdf_documents
    static let pdfDocs = Table("pdf_documents")
    static let pdfId = Expression<Int64>("id")
    static let pdfFileName = Expression<String>("file_name")
    static let pdfMatchKey = Expression<String>("match_key")
    static let pdfDocumentKey = Expression<String>("document_key")
    static let pdfVersion = Expression<Int>("version")

    // MARK: - Initialisation

    static func setup() throws -> Connection {
        let db = try Connection("db.sqlite3")

        // table categories
        try db.run(
            categories.create(ifNotExists: true) { t in
                t.column(catId, primaryKey: .autoincrement)
                t.column(catName, unique: true)
                t.column(catDescription, defaultValue: "")
            })

        // table endoscopes
        try db.run(
            endoscopes.create(ifNotExists: true) { t in
                t.column(endId, primaryKey: .autoincrement)
                t.column(endBrand)
                t.column(endModel)
                t.column(endCategoryId)
                t.column(endConnSetRef)
                t.column(endPentaxItem)
                t.column(endCycleCode)
                t.column(endCardCode)
                t.column(endNotes, defaultValue: "")
            })

        // table pdf_documents
        try db.run(
            pdfDocs.create(ifNotExists: true) { t in
                t.column(pdfId, primaryKey: .autoincrement)
                t.column(pdfFileName)
                t.column(pdfMatchKey)
                t.column(pdfDocumentKey)
                t.column(pdfVersion)
            })

        return db
    }

    // MARK: - CRUD Catégories

    @discardableResult
    static func insertCategory(db: Connection, name: String, description: String) throws -> Int64 {
        try db.run(categories.insert(catName <- name, catDescription <- description))
    }

    static func fetchAllCategories(db: Connection) throws -> [Category] {
        try db.prepare(categories.order(catName)).map { row in
            Category(id: row[catId], name: row[catName], description: row[catDescription])
        }
    }

    static func fetchCategory(db: Connection, id targetId: Int64) throws -> Category? {
        let query = categories.filter(catId == targetId)
        return try db.pluck(query).map { row in
            Category(id: row[catId], name: row[catName], description: row[catDescription])
        }
    }

    static func categoryExists(db: Connection, name: String) throws -> Bool {
        try db.scalar(categories.filter(catName == name).count) > 0
    }

    static func updateCategory(
        db: Connection, id targetId: Int64, name: String, description: String
    ) throws {
        let row = categories.filter(catId == targetId)
        try db.run(row.update(catName <- name, catDescription <- description))
    }

    static func deleteCategory(db: Connection, id targetId: Int64) throws {
        // Supprimer également les endoscopes appartenant à cette catégorie
        try db.run(endoscopes.filter(endCategoryId == targetId).delete())
        try db.run(categories.filter(catId == targetId).delete())
    }

    // MARK: - CRUD Endoscopes

    @discardableResult
    static func insertEndoscope(db: Connection, e: Endoscope) throws -> Int64 {
        try db.run(
            endoscopes.insert(
                endBrand <- e.brand,
                endModel <- e.model,
                endCategoryId <- e.categoryId,
                endConnSetRef <- e.connectionSetRef,
                endPentaxItem <- e.pentaxItemNumber,
                endCycleCode <- e.cycleCode,
                endCardCode <- e.connectionCardCode,
                endNotes <- e.notes
            ))
    }

    static func fetchAllEndoscopes(db: Connection) throws -> [Endoscope] {
        try db.prepare(endoscopes.order(endBrand, endModel)).map { row in
            endoscopeFrom(row)
        }
    }

    static func fetchEndoscopes(db: Connection, categoryId: Int64) throws -> [Endoscope] {
        try db.prepare(endoscopes.filter(endCategoryId == categoryId).order(endBrand, endModel)).map
        { row in
            endoscopeFrom(row)
        }
    }

    static func fetchEndoscope(db: Connection, id targetId: Int64) throws -> Endoscope? {
        try db.pluck(endoscopes.filter(endId == targetId)).map { row in endoscopeFrom(row) }
    }

    static func updateEndoscope(db: Connection, e: Endoscope) throws {
        guard let targetId = e.id else { return }
        let row = endoscopes.filter(endId == targetId)
        try db.run(
            row.update(
                endBrand <- e.brand,
                endModel <- e.model,
                endCategoryId <- e.categoryId,
                endConnSetRef <- e.connectionSetRef,
                endPentaxItem <- e.pentaxItemNumber,
                endCycleCode <- e.cycleCode,
                endCardCode <- e.connectionCardCode,
                endNotes <- e.notes
            ))
    }

    static func deleteEndoscope(db: Connection, id targetId: Int64) throws {
        try db.run(endoscopes.filter(endId == targetId).delete())
    }

    static func searchEndoscopes(db: Connection, query: String, categoryId: Int64? = nil) throws
        -> [Endoscope]
    {
        // Recherche multi-tokens souple, chaque token doit apparaître dans au moins un champ.
        // La correspondance est insensible à la casse, partielle (sous-chaîne) et insensible à la ponctuation.
        // Tous les résultats correspondants sont retournés triés par pertinence.
        // Si categoryId est fourni, la recherche est limitée à cette catégorie.
        let normalize: (String) -> String = { s in
            s.lowercased()
                .components(separatedBy: CharacterSet.alphanumerics.inverted)
                .joined()
        }

        // Découper sur tout caractère non-alphanumérique (gère les espaces encodés en '+', tirets, etc.)
        let tokens =
            query
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty }

        guard !tokens.isEmpty else {
            if let catId = categoryId { return try fetchEndoscopes(db: db, categoryId: catId) }
            return try fetchAllEndoscopes(db: db)
        }

        let cats = try fetchAllCategories(db: db)
        let catMap = Dictionary(
            uniqueKeysWithValues: cats.compactMap { c -> (Int64, String)? in
                guard let id = c.id else { return nil }
                return (id, c.name)
            })

        let pool: [Endoscope]
        if let catId = categoryId {
            pool = try fetchEndoscopes(db: db, categoryId: catId)
        } else {
            pool = try db.prepare(endoscopes.order(endBrand, endModel)).map { row in
                endoscopeFrom(row)
            }
        }

        typealias Scored = (endo: Endoscope, hits: Int)

        let scored: [Scored] = pool.compactMap { endo in
            let rawFields = [
                endo.brand, endo.model, endo.pentaxItemNumber,
                endo.cycleCode, endo.connectionCardCode, endo.connectionSetRef,
                endo.notes, catMap[endo.categoryId] ?? "",
            ]
            let fields = rawFields.map { normalize($0) }

            let hits = tokens.filter { token in
                fields.contains { $0.contains(token) }
            }.count

            guard hits > 0 else { return nil }
            return (endo, hits)
        }

        // Toujours retourner tous les résultats correspondants triés par pertinence (plus de tokens = en premier)
        return scored.sorted { $0.hits > $1.hits }.map { $0.endo }
    }

    // Construit un Endoscope à partir d'une Row
    private static func endoscopeFrom(_ row: Row) -> Endoscope {
        Endoscope(
            id: row[endId],
            brand: row[endBrand],
            model: row[endModel],
            categoryId: row[endCategoryId],
            connectionSetRef: row[endConnSetRef],
            pentaxItemNumber: row[endPentaxItem],
            cycleCode: row[endCycleCode],
            connectionCardCode: row[endCardCode],
            notes: row[endNotes]
        )
    }

    // MARK: - Index des documents PDF

    static func upsertPdf(db: Connection, pdf: PdfDocument) throws {
        // Remplacer l'entrée existante avec le même document_key
        try db.run(
            pdfDocs.insert(
                or: .replace,
                pdfFileName <- pdf.fileName,
                pdfMatchKey <- pdf.matchKey,
                pdfDocumentKey <- pdf.documentKey,
                pdfVersion <- pdf.version
            ))
    }

    static func fetchAllPdfs(db: Connection) throws -> [PdfDocument] {
        try db.prepare(pdfDocs.order(pdfMatchKey, pdfVersion.desc)).map { row in
            PdfDocument(
                id: row[pdfId],
                fileName: row[pdfFileName],
                matchKey: row[pdfMatchKey],
                documentKey: row[pdfDocumentKey],
                version: row[pdfVersion]
            )
        }
    }

    /// Retourne le PDF le plus récent dont le matchKey correspond au code de carte normalisé.
    static func findPdf(db: Connection, normalisedCardCode: String) throws -> PdfDocument? {
        let query =
            pdfDocs
            .filter(pdfMatchKey == normalisedCardCode)
            .order(pdfVersion.desc)
            .limit(1)
        return try db.pluck(query).map { row in
            PdfDocument(
                id: row[pdfId],
                fileName: row[pdfFileName],
                matchKey: row[pdfMatchKey],
                documentKey: row[pdfDocumentKey],
                version: row[pdfVersion]
            )
        }
    }

    // MARK: - Commodité, lignes avec données jointes

    static func fetchEndoscopeRows(
        db: Connection, categoryId: Int64? = nil, searchQuery: String = ""
    ) throws -> [EndoscopeRow] {
        let cats = try fetchAllCategories(db: db)
        let catMap = Dictionary(
            uniqueKeysWithValues: cats.compactMap { c -> (Int64, String)? in
                guard let id = c.id else { return nil }
                return (id, c.name)
            })

        let items: [Endoscope]
        if !searchQuery.isEmpty {
            items = try searchEndoscopes(db: db, query: searchQuery, categoryId: categoryId)
        } else if let catId = categoryId {
            items = try fetchEndoscopes(db: db, categoryId: catId)
        } else {
            items = try fetchAllEndoscopes(db: db)
        }

        return try items.map { endo in
            let pdf = try findPdf(db: db, normalisedCardCode: endo.normalisedCardCode)
            return EndoscopeRow(
                endoscope: endo,
                categoryName: catMap[endo.categoryId] ?? "—",
                pdf: pdf
            )
        }
    }
}
