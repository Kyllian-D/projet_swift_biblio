import Foundation
import Hummingbird
@preconcurrency import SQLite

// MARK: - Démarrage

// Au lancement via swift run, le répertoire courant est la racine du projet.
// On l'utilise plutôt que de remonter depuis le chemin de l'exécutable, qui varie
// selon la configuration de build et la plateforme.
let workspaceRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourcesAppPath = workspaceRoot.appendingPathComponent("Sources/App").path
let pdfsPath = workspaceRoot.appendingPathComponent("PDFs").path

// Initialiser le schéma de la base de données
let db = try Database.setup()

// Indexer les fichiers PDF dans la base de données
try CSVImporter.indexPDFs(db: db, pdfsPath: pdfsPath)

// Importer les données CSV (une seule fois, quand la base est vide)
try CSVImporter.importIfNeeded(db: db, sourcesPath: sourcesAppPath)

// MARK: - Routeur

let router = Router()

// Servir les fichiers PDF statiques
router.get("/pdfs/:filename") { request, context -> Response in
    guard let filename = context.parameters.get("filename") else {
        return Response(status: .badRequest)
    }
    // Protection contre la traversée de répertoires
    guard !filename.contains(".."), !filename.contains("/") else {
        return Response(status: .badRequest)
    }
    let filePath = "\(pdfsPath)/\(filename)"
    guard FileManager.default.fileExists(atPath: filePath),
        let data = FileManager.default.contents(atPath: filePath)
    else {
        return Response(status: .notFound)
    }
    return Response(
        status: .ok,
        headers: [.contentType: "application/pdf"],
        body: .init(byteBuffer: .init(bytes: data))
    )
}

// GET liste principale
router.get("/") { request, _ -> HTML in
    let categories = try Database.fetchAllCategories(db: db)
    let catFilter = request.uri.queryParameters.get("category").flatMap { Int64($0) }
    let search = request.uri.queryParameters.get("q") ?? ""
    let rows = try Database.fetchEndoscopeRows(db: db, categoryId: catFilter, searchQuery: search)
    let allPdfs = try Database.fetchAllPdfs(db: db)
    return Views.renderIndex(
        rows: rows, categories: categories, activeCategoryId: catFilter, searchQuery: search,
        pdfDocuments: allPdfs, lang: getLang(request))
}

// GET endoscope id page de détail
router.get("/endoscope/:id") { request, context -> HTML in
    guard let idStr = context.parameters.get("id"), let targetId = Int64(idStr),
        let endo = try Database.fetchEndoscope(db: db, id: targetId)
    else {
        return Views.renderNotFound(lang: getLang(request))
    }
    let pdf = try Database.findPdf(db: db, normalisedCardCode: endo.normalisedCardCode)
    let categories = try Database.fetchAllCategories(db: db)
    let allPdfs = try Database.fetchAllPdfs(db: db)
    return Views.renderDetail(
        endoscope: endo, pdf: pdf, categories: categories, pdfDocuments: allPdfs,
        lang: getLang(request))
}

// POST endoscopes rcéation
router.post("/endoscopes/add") { request, _ -> Response in
    let body = try await collectBody(request)
    guard
        let brand = body["brand"], !brand.isEmpty,
        let model = body["model"], !model.isEmpty,
        let catIdStr = body["categoryId"],
        let categoryId = Int64(catIdStr),
        let connRef = body["connectionSetRef"],
        let pentax = body["pentaxItemNumber"],
        let cycle = body["cycleCode"],
        let card = body["connectionCardCode"]
    else {
        return Response(status: .badRequest)
    }
    let notes = body["notes"] ?? ""
    let endo = Endoscope(
        id: nil,
        brand: brand,
        model: model,
        categoryId: categoryId,
        connectionSetRef: connRef,
        pentaxItemNumber: pentax,
        cycleCode: cycle,
        connectionCardCode: card,
        notes: notes
    )
    try Database.insertEndoscope(db: db, e: endo)
    return Response(status: .seeOther, headers: [.location: "/"])
}

//POST endoscope id/update mise à jour
router.post("/endoscope/:id/update") { request, context -> Response in
    guard let idStr = context.parameters.get("id"), let targetId = Int64(idStr),
        var endo = try Database.fetchEndoscope(db: db, id: targetId)
    else {
        return Response(status: .notFound)
    }
    let body = try await collectBody(request)
    if let v = body["brand"], !v.isEmpty { endo.brand = v }
    if let v = body["model"], !v.isEmpty { endo.model = v }
    if let v = body["categoryId"], let i = Int64(v) { endo.categoryId = i }
    if let v = body["connectionSetRef"] { endo.connectionSetRef = v }
    if let v = body["pentaxItemNumber"] { endo.pentaxItemNumber = v }
    if let v = body["cycleCode"] { endo.cycleCode = v }
    if let v = body["connectionCardCode"] { endo.connectionCardCode = v }
    if let v = body["notes"] { endo.notes = v }
    try Database.updateEndoscope(db: db, e: endo)
    return Response(status: .seeOther, headers: [.location: "/endoscope/\(targetId)"])
}

//POST endoscope/:id/delete suppression
router.post("/endoscope/:id/delete") { _, context -> Response in
    guard let idStr = context.parameters.get("id"), let targetId = Int64(idStr) else {
        return Response(status: .badRequest)
    }
    try Database.deleteEndoscope(db: db, id: targetId)
    return Response(status: .seeOther, headers: [.location: "/"])
}

//POST /categories/add création de catégorie
router.post("/categories/add") { request, _ -> Response in
    let body = try await collectBody(request)
    guard let name = body["name"], !name.isEmpty else {
        return Response(status: .badRequest)
    }
    let description = body["description"] ?? ""
    guard !(try Database.categoryExists(db: db, name: name)) else {
        return Response(status: .seeOther, headers: [.location: "/categories"])
    }
    try Database.insertCategory(db: db, name: name, description: description)
    return Response(status: .seeOther, headers: [.location: "/categories"])
}

// GET /categories liste des catégories
router.get("/categories") { request, _ -> HTML in
    let categories = try Database.fetchAllCategories(db: db)
    return Views.renderCategories(categories: categories, lang: getLang(request))
}

// GET définir le cookie de langue
router.get("/lang/:code") { request, context -> Response in
    let code = context.parameters.get("code") == "fr" ? "fr" : "en"
    return Response(
        status: .seeOther,
        headers: [
            .location: "/",
            .setCookie: "lang=\(code); Path=/; Max-Age=31536000; SameSite=Lax",
        ])
}

// POST /category/:id/update  mise à jour de catégorie
router.post("/category/:id/update") { request, context -> Response in
    guard let idStr = context.parameters.get("id"), let targetId = Int64(idStr) else {
        return Response(status: .badRequest)
    }
    let body = try await collectBody(request)
    guard let name = body["name"], !name.isEmpty else {
        return Response(status: .badRequest)
    }
    let description = body["description"] ?? ""
    try Database.updateCategory(db: db, id: targetId, name: name, description: description)
    return Response(status: .seeOther, headers: [.location: "/categories"])
}

//POST /category/:id/delete suppression de catégorie
router.post("/category/:id/delete") { _, context -> Response in
    guard let idStr = context.parameters.get("id"), let targetId = Int64(idStr) else {
        return Response(status: .badRequest)
    }
    try Database.deleteCategory(db: db, id: targetId)
    return Response(status: .seeOther, headers: [.location: "/categories"])
}

//POST /import/csv relancer l'import (utile après réinitialisation)
router.post("/import/csv") { _, _ -> Response in
    // Vider les tables et relancer l'import
    try db.run(Database.endoscopes.delete())
    try db.run(Database.categories.delete())
    try db.run(Database.pdfDocs.delete())
    try CSVImporter.indexPDFs(db: db, pdfsPath: pdfsPath)
    try CSVImporter.importIfNeeded(db: db, sourcesPath: sourcesAppPath)
    return Response(status: .seeOther, headers: [.location: "/"])
}

// MARK: - Démarrage du serveur

let app = Application(
    router: router,
    configuration: .init(address: .hostname("0.0.0.0", port: 8080))
)

print("🔬 EndoScope Library http://localhost:8080")
try await app.runService()

// MARK: - Utilitaires

/// Lit le cookie `lang`. Retourne "fr" ou "en" (par défaut).
func getLang(_ request: Request) -> String {
    guard let cookies = request.headers[.cookie] else { return "en" }
    for part in cookies.split(separator: ";") {
        let kv = part.trimmingCharacters(in: .whitespaces)
        if kv.hasPrefix("lang=") {
            return String(kv.dropFirst(5)).trimmingCharacters(in: .whitespaces) == "fr"
                ? "fr" : "en"
        }
    }
    return "en"
}

/// Lit et décode l'URL d'un corps de formulaire en dictionnaire
func collectBody(_ request: Request) async throws -> [String: String] {
    let buffer = try await request.body.collect(upTo: 1024 * 64)
    let bodyString = String(buffer: buffer)
    var components = URLComponents()
    components.percentEncodedQuery = bodyString
    var dict: [String: String] = [:]
    for item in components.queryItems ?? [] {
        dict[item.name] = item.value ?? ""
    }
    return dict
}
