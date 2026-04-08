import Foundation
import SQLite

/// Gère l'import unique des données CSV et l'indexation du dossier PDF dans SQLite.
struct CSVImporter {

    // MARK: - Indexation du dossier PDF

    /// Parcourt le dossier PDFs/, analyse chaque nom de fichier pour en extraire le matchKey et la version,
    /// puis insère ou met à jour chaque PDF dans la table pdf_documents.
    ///
    /// Exemple de format : b01_002_3_303_v03connectioncard301008...pdf
    /// On extrait jusqu'au token de version inclus : b01_002_3_303_v03
    /// matchKey = B01_002_3_303
    /// documentKey = B01_002_3_303_V03
    /// version = 3
    static func indexPDFs(db: Connection, pdfsPath: String) throws {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(atPath: pdfsPath) else { return }

        for fileName in files where fileName.lowercased().hasSuffix(".pdf") {
            guard let parsed = parsePdfFileName(fileName) else { continue }
            let pdf = PdfDocument(
                id: nil,
                fileName: fileName,
                matchKey: parsed.matchKey,
                documentKey: parsed.documentKey,
                version: parsed.version
            )
            try Database.upsertPdf(db: db, pdf: pdf)
        }
    }

    /// Analyse un nom de fichier PDF et retourne (matchKey, documentKey, version).
    /// Exemple : "b01_002_3_303_v03connectioncard..." → ("B01_002_3_303", "B01_002_3_303_V03", 3)
    static func parsePdfFileName(_ fileName: String) -> (
        matchKey: String, documentKey: String, version: Int
    )? {
        // Construire une copie de travail en minuscules sans l'extension .pdf
        let base = fileName.lowercased()

        // capture tout jusqu'à _v suivi d'au moins un chiffre
        // ex b01_002_3_303_v03  →  préfixe = b01_002_3_303, vStr = 03
        guard let range = base.range(of: #"_v(\d+)"#, options: .regularExpression) else {
            return nil
        }

        // le préfixe est tout ce qui se trouve avant le token _v
        let prefixEnd = base.distance(from: base.startIndex, to: range.lowerBound)
        let prefixRaw = String(base.prefix(prefixEnd))

        // extract the version digits
        let vStr = String(base[range]).dropFirst(2)  // supprimer "_v"
        guard let version = Int(vStr) else { return nil }

        let matchKey = prefixRaw.uppercased()
        let documentKey = "\(prefixRaw)_v\(vStr)".uppercased()

        return (matchKey: matchKey, documentKey: documentKey, version: version)
    }

    // MARK: - Import CSV

    /// Ne s'exécute que si la base de données est vide (nombre de catégories == 0).
    static func importIfNeeded(db: Connection, sourcesPath: String) throws {
        let count = try db.scalar(Database.categories.count)
        guard count == 0 else { return }

        // Insérer les trois catégories de base
        let aquaId = try Database.insertCategory(
            db: db, name: "AquaTYPHOON", description: "Water-based sterilisation connection sets")
        let plasmaId = try Database.insertCategory(
            db: db, name: "PlasmaTYPHOON", description: "Plasma sterilisation connection sets")
        let plusId = try Database.insertCategory(
            db: db, name: "PlasmaTYPHOON+",
            description: "Plasma+ sterilisation connection sets (enhanced)")

        // Importer le CSV AquaTYPHOON (une catégorie par ligne)
        let aquaPath = "\(sourcesPath)/aqua_connection_cards.csv"
        let aquaItems = try parseAquaCSV(path: aquaPath, categoryId: aquaId)
        for item in aquaItems { try Database.insertEndoscope(db: db, e: item) }

        // Importer le CSV PlasmaTYPHOON / PlasmaTYPHOON+ (deux catégories par ligne)
        let plasmaPath = "\(sourcesPath)/plasma_connection_cards.csv"
        let (plasmaItems, plusItems) = try parsePlasmaCSV(
            path: plasmaPath, plasmaId: plasmaId, plusId: plusId)
        for item in plasmaItems { try Database.insertEndoscope(db: db, e: item) }
        for item in plusItems { try Database.insertEndoscope(db: db, e: item) }
    }

    // MARK: - Parseur CSV Aqua
    // Format (séparé par des points-virgulescar csv) :
    // Col 0 : Marque
    // Col 1 : Modèle d'endoscope
    // Col 2 : Référence set de connexion
    // Col 3 : N° article PENTAX
    // Col 4 : Code cycle
    // Col 5 : Code carte de connexion

    private static func parseAquaCSV(path: String, categoryId: Int64) throws -> [Endoscope] {
        let raw = try String(contentsOfFile: path, encoding: .utf8)
        // Découper sur \n en gérant aussi \r\n
        let lines = raw.components(separatedBy: .newlines)
        var results: [Endoscope] = []

        for (index, line) in lines.enumerated() {
            // Ignorer les deux lignes d'en-tête et les lignes vides
            guard index >= 2, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let cols = splitCSVLine(line)
            guard cols.count >= 6 else { continue }

            let brand = cols[0].trimmed
            let model = cols[1].trimmed
            guard !brand.isEmpty, !model.isEmpty else { continue }

            results.append(
                Endoscope(
                    id: nil,
                    brand: brand,
                    model: model,
                    categoryId: categoryId,
                    connectionSetRef: cols[2].trimmed,
                    pentaxItemNumber: cols[3].trimmed,
                    cycleCode: cols[4].trimmed,
                    connectionCardCode: cols[5].trimmed,
                    notes: ""
                ))
        }
        return results
    }

    // MARK: - Parseur CSV Plasma
    // Format (séparé par des points-virgules) :
    // Col 0 : Marque
    // Col 1 : Modèle d'endoscope

    // PlasmaTYPHOON
    // Col 2 : Référence set de connexion
    // Col 3 : N° article PENTAX
    // Col 4 : Code cycle
    // Col 5 : Code carte de connexion

    // PlasmaTYPHOON+
    // Col 6 : Référence set de connexion
    // Col 7 : N° article PENTAX
    // Col 8 : Code cycle
    // Col 9 : Code carte de connexion

    private static func parsePlasmaCSV(path: String, plasmaId: Int64, plusId: Int64) throws -> (
        [Endoscope], [Endoscope]
    ) {
        let raw = try String(contentsOfFile: path, encoding: .utf8)
        let lines = raw.components(separatedBy: .newlines)
        var plasma: [Endoscope] = []
        var plus: [Endoscope] = []

        for (index, line) in lines.enumerated() {
            guard index >= 2, !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }

            let cols = splitCSVLine(line)
            guard cols.count >= 6 else { continue }

            let brand = cols[0].trimmed
            let model = cols[1].trimmed
            guard !brand.isEmpty, !model.isEmpty else { continue }

            // Entrée PlasmaTYPHOON
            plasma.append(
                Endoscope(
                    id: nil,
                    brand: brand,
                    model: model,
                    categoryId: plasmaId,
                    connectionSetRef: cols[2].trimmed,
                    pentaxItemNumber: cols[3].trimmed,
                    cycleCode: cols[4].trimmed,
                    connectionCardCode: cols[5].trimmed,
                    notes: ""
                ))

            // Entrée PlasmaTYPHOON+ (colonnes 6-9, si présentes)
            if cols.count >= 10 {
                let plusCard = cols[9].trimmed
                if !plusCard.isEmpty {
                    plus.append(
                        Endoscope(
                            id: nil,
                            brand: brand,
                            model: model,
                            categoryId: plusId,
                            connectionSetRef: cols[6].trimmed,
                            pentaxItemNumber: cols[7].trimmed,
                            cycleCode: cols[8].trimmed,
                            connectionCardCode: plusCard,
                            notes: ""
                        ))
                }
            }
        }
        return (plasma, plus)
    }

    // MARK: - Utilitaires

    /// Découpe une ligne délimitée par des points-virgules
    private static func splitCSVLine(_ line: String) -> [String] {
        line.components(separatedBy: ";")
    }
}

extension String {
    /// Supprime les espaces et sauts de ligne en début et fin de chaîne
    fileprivate var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
