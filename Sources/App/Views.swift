import Foundation
import Hummingbird

// MARK: - HTML response wrapper

struct HTML: ResponseGenerator {
    let content: String
    func response(from request: Request, context: some RequestContext) throws -> Response {
        Response(
            status: .ok,
            headers: [.contentType: "text/html; charset=utf-8"],
            body: .init(byteBuffer: .init(string: content))
        )
    }
}

// MARK: - Localisation (L10n)

private struct L10n {
    let lang: String
    static func from(_ s: String) -> L10n { L10n(lang: s == "fr" ? "fr" : "en") }
    private var fr: Bool { lang == "fr" }

    var htmlLang: String { lang }
    var pageTitle: String { fr ? "Bibliothèque d'Endoscopes" : "Endoscope Library" }
    var endoscopesNav: String { "Endoscopes" }
    var categoriesNav: String { fr ? "Catégories" : "Categories" }
    var all: String { fr ? "Tout" : "All" }
    var searchPlaceholder: String {
        fr
            ? "Recherche multi-mots : marque, modèle, N° PENTAX, carte… (ordre libre)"
            : "Multi-word search: brand, model, PENTAX N°, card code… (any order)"
    }
    var clearLabel: String { fr ? "✕ Effacer" : "✕ Clear" }
    var addEndoscope: String { fr ? "+ Ajouter un endoscope" : "+ Add Endoscope" }
    var noResults: String { fr ? "Aucun endoscope trouvé." : "No endoscopes found." }
    var thCategory: String { fr ? "Catégorie" : "Category" }
    var thBrand: String { fr ? "Marque" : "Brand" }
    var thModel: String { fr ? "Modèle" : "Model" }
    var thConnRef: String { fr ? "Réf. set de connexion" : "Connection Set Ref" }
    var thPentax: String { fr ? "N° PENTAX" : "PENTAX Item N°" }
    var thCycle: String { fr ? "Code cycle" : "Cycle Code" }
    var thCard: String { fr ? "Carte de connexion" : "Connection Card" }
    var edit: String { fr ? "Modifier" : "Edit" }
    var delete: String { fr ? "Supprimer" : "Delete" }
    var save: String { fr ? "Enregistrer" : "Save" }
    var saveChanges: String { fr ? "Enregistrer les modifications" : "Save Changes" }
    var addBtn: String { fr ? "Ajouter l'endoscope" : "Add Endoscope" }
    var brand: String { fr ? "Marque" : "Brand" }
    var model: String { fr ? "Modèle" : "Model" }
    var category: String { fr ? "Catégorie" : "Category" }
    var connSetRef: String { fr ? "Réf. set de connexion" : "Connection Set Ref" }
    var pentaxItem: String { fr ? "N° article PENTAX" : "PENTAX Item N°" }
    var cycleCode: String { fr ? "Code cycle" : "Cycle Code" }
    var cardCode: String { fr ? "Code carte de connexion" : "Connection Card Code" }
    var cardHint: String {
        fr
            ? "Associe un PDF automatiquement. Format : B05-032_3_302"
            : "Used to auto-match a PDF. Format: B05-032_3_302"
    }
    var notes: String { fr ? "Notes" : "Notes" }
    var backToList: String { fr ? "← Retour à la liste" : "← Back to list" }
    var connCardPdf: String { fr ? "PDF carte de connexion :" : "Connection Card PDF:" }
    var noPdfFound: String {
        fr ? "Aucun PDF trouvé pour le code" : "No matching PDF found for code"
    }
    var editEndoscope: String { fr ? "Modifier l'endoscope" : "Edit Endoscope" }
    var dangerZone: String { fr ? "Zone danger" : "Danger Zone" }
    var deleteThisEndo: String { fr ? "Supprimer cet endoscope" : "Delete this endoscope" }
    func confirmDelete(_ name: String) -> String {
        fr ? "Supprimer définitivement \(name) ?" : "Permanently delete \(name)?"
    }
    var categoriesTitle: String { fr ? "Catégories" : "Categories" }
    var categoriesDesc: String {
        fr
            ? "Gérer les familles d'équipements. Supprimer une catégorie supprime aussi tous ses endoscopes."
            : "Manage sterilisation equipment families. Deleting a category also removes all its endoscopes."
    }
    var addCatTitle: String { fr ? "Ajouter une catégorie" : "Add a new category" }
    var catName: String { fr ? "Nom" : "Name" }
    var catDescLabel: String { fr ? "Description" : "Description" }
    var addCatBtn: String { fr ? "Ajouter la catégorie" : "Add Category" }
    var deleteCatBtn: String { fr ? "Supprimer la catégorie" : "Delete category" }
    var resetTitle: String {
        fr ? "Réinitialiser &amp; réimporter les CSV" : "Reset &amp; re-import CSV data"
    }
    var resetDesc: String {
        fr
            ? "Supprime toutes les données et réimporte depuis les CSV d'origine."
            : "This will delete all current data and re-import from the original CSV files."
    }
    var resetBtn: String { fr ? "Réinitialiser &amp; réimporter" : "Reset &amp; Re-import" }
    var resetConfirm: String {
        fr
            ? "Cela réinitialise TOUTES les données. Continuer ?"
            : "This will reset ALL data. Continue?"
    }
    func confirmDeleteCat(_ name: String) -> String {
        fr
            ? "Supprimer la catégorie \(name) et tous ses endoscopes ?"
            : "Delete category \(name) and all its endoscopes?"
    }
    var notFoundTitle: String { fr ? "404 — Endoscope introuvable" : "404 — Endoscope not found" }
    var backSimple: String { fr ? "← Retour" : "← Back" }
    func endoCount(_ n: Int) -> String {
        fr ? "\(n) endoscope\(n > 1 ? "s" : "")" : "\(n) endoscope(s)"
    }
}

// MARK: - Views

struct Views {

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Shared layout
    // ─────────────────────────────────────────────────────────────────────────

    private static func layout(title: String, body: String, lang: String = "en") -> HTML {
        let t = L10n.from(lang)
        let frStyle =
            lang == "fr"
            ? "font-weight:bold;text-decoration:none"
            : "text-decoration:none;color:#888"
        let enStyle =
            lang == "en"
            ? "font-weight:bold;text-decoration:none"
            : "text-decoration:none;color:#888"
        return HTML(
            content: """
                <!DOCTYPE html>
                <html lang="\(t.htmlLang)">
                <head>
                    <meta charset="utf-8">
                    <meta name="viewport" content="width=device-width, initial-scale=1">
                    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/@picocss/pico@2/css/pico.min.css">
                    <style>
                        :root { --brand: #0077b6; --brand-light: #90e0ef; }
                        nav .brand { font-weight: bold; color: var(--brand); font-size: 1.2rem; }
                        .badge { display: inline-block; padding: 2px 8px; border-radius: 999px; font-size: .75rem; font-weight: 600; background: var(--brand-light); color: #023e8a; }
                        table { font-size: .875rem; }
                        .card-code { font-family: monospace; font-size: .8rem; color: #555; }
                        .pdf-link { font-size: .8rem; }
                        details summary { cursor: pointer; list-style: none; }
                        details summary::-webkit-details-marker { display: none; }
                        details summary::after { display: none !important; }
                        .action-cell { display:flex; gap:.35rem; align-items:center; }
                        .danger { color: #d62828; }
                    </style>
                    <title>\(title) — EndoScope Library</title>
                </head>
                <body>
                    <nav class="container-fluid">
                        <ul>
                            <li><a href="/" class="brand">🔬 EndoScope Library</a></li>
                        </ul>
                        <ul>
                            <li><a href="/">\(t.endoscopesNav)</a></li>
                            <li><a href="/categories">\(t.categoriesNav)</a></li>
                            <li style="display:flex;align-items:center;gap:.5rem;padding-left:.75rem;border-left:1px solid #ccc">
                                <a href="/lang/fr"
                                   title="Français"
                                   onclick="document.cookie='lang=fr; path=/; max-age=31536000; SameSite=Lax'; location.reload(); return false"
                                   style="\(frStyle)">FR</a>
                                <a href="/lang/en"
                                   title="English"
                                   onclick="document.cookie='lang=en; path=/; max-age=31536000; SameSite=Lax'; location.reload(); return false"
                                   style="\(enStyle)">EN</a>
                            </li>
                        </ul>
                    </nav>
                    <main class="container" style="padding-top:1.5rem">
                        \(body)
                    </main>
                </body>
                </html>
                """)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Index — endoscope list
    // ─────────────────────────────────────────────────────────────────────────

    static func renderIndex(
        rows: [EndoscopeRow],
        categories: [Category],
        activeCategoryId: Int64?,
        searchQuery: String,
        pdfDocuments: [PdfDocument],
        lang: String = "en"
    ) -> HTML {
        let t = L10n.from(lang)

        // Category filter pills
        let allPill =
            activeCategoryId == nil && searchQuery.isEmpty
            ? "<a href=\"/\"><strong>\(t.all)</strong></a>"
            : "<a href=\"/\">\(t.all)</a>"
        let pills = categories.map { cat -> String in
            guard let id = cat.id else { return "" }
            let active = activeCategoryId == id && searchQuery.isEmpty
            let label = active ? "<strong>\(escape(cat.name))</strong>" : escape(cat.name)
            return "<a href=\"/?category=\(id)\">\(label)</a>"
        }.joined(separator: " · ")

        // Search bar
        let clearHref = activeCategoryId.map { "/?category=\($0)" } ?? "/"
        let clearBtn =
            searchQuery.isEmpty
            ? ""
            : "<a href='\(clearHref)' role='button' class='outline secondary' style='white-space:nowrap'>\(t.clearLabel)</a>"
        let catHidden =
            activeCategoryId.map { "<input type='hidden' name='category' value='\($0)'>" } ?? ""
        let searchBar = """
            <form action="/" method="get" style="display:flex;gap:.5rem;align-items:center;width:100%;margin-bottom:0">
                <input type="search" name="q"
                    placeholder="\(t.searchPlaceholder)"
                    value="\(escape(searchQuery))"
                    style="flex:1 1 auto;width:0;min-width:0;margin-bottom:0">
                \(catHidden)
                <button type="submit" style="flex:0 0 auto;width:auto;white-space:nowrap;margin-bottom:0">🔍</button>
                \(clearBtn)
            </form>
            """

        // Rows
        let tableRows = rows.map { row -> String in
            let endo = row.endoscope
            let pdfCell: String
            if let pdf = row.pdf {
                pdfCell =
                    "<a href='/pdfs/\(pdf.fileName)' target='_blank' class='pdf-link'>📄 \(escape(pdf.documentKey))</a>"
            } else {
                pdfCell = "<span style='color:#aaa;font-size:.8rem'>—</span>"
            }
            return """
                <tr>
                    <td><span class="badge">\(escape(row.categoryName))</span></td>
                    <td>\(escape(endo.brand))</td>
                    <td><a href="/endoscope/\(endo.id ?? 0)">\(escape(endo.model))</a></td>
                    <td>\(escape(endo.connectionSetRef))</td>
                    <td>\(escape(endo.pentaxItemNumber))</td>
                    <td>\(escape(endo.cycleCode))</td>
                    <td class="card-code">\(escape(endo.connectionCardCode))</td>
                    <td>\(pdfCell)</td>
                    <td class="action-cell">
                        <a href="/endoscope/\(endo.id ?? 0)" role="button" class="outline" style="padding:2px 8px;font-size:.75rem;margin:0">\(t.edit)</a>
                        <form action="/endoscope/\(endo.id ?? 0)/delete" method="post" style="margin:0" onsubmit="return confirm('\(t.confirmDelete(escape(endo.model)))')">
                            <button type="submit" class="outline danger" style="padding:2px 8px;font-size:.75rem;margin:0">\(t.delete)</button>
                        </form>
                    </td>
                </tr>
                """
        }.joined()

        let emptyNote = rows.isEmpty ? "<p style='color:#888'>\(t.noResults)</p>" : ""

        // Add endoscope form (collapsed)
        let categoryOptions = categories.map { cat -> String in
            guard let id = cat.id else { return "" }
            return "<option value='\(id)'>\(escape(cat.name))</option>"
        }.joined()

        var seenKeys = Set<String>()
        let cardOptions =
            "<option value=''>— None —</option>"
            + pdfDocuments.compactMap { pdf -> String? in
                guard seenKeys.insert(pdf.matchKey).inserted else { return nil }
                return "<option value='\(pdf.matchKey)'>\(escape(pdf.matchKey))</option>"
            }.joined()

        let addForm = """
            <details>
                <summary><strong>\(t.addEndoscope)</strong></summary>
                <article>
                <form action="/endoscopes/add" method="post">
                    <div class="grid">
                        <label>\(t.brand)<input type="text" name="brand" required placeholder="e.g. Fujifilm"></label>
                        <label>\(t.model)<input type="text" name="model" required placeholder="e.g. EB-270P"></label>
                        <label>\(t.category)
                            <select name="categoryId" required>\(categoryOptions)</select>
                        </label>
                    </div>
                    <div class="grid">
                        <label>\(t.connSetRef)<input type="text" name="connectionSetRef" placeholder="e.g. AF BR70/A"></label>
                        <label>\(t.pentaxItem)<input type="text" name="pentaxItemNumber" placeholder="e.g. 301218-1"></label>
                        <label>\(t.cycleCode)<input type="text" name="cycleCode" placeholder="e.g. BCU-BCU"></label>
                    </div>
                    <div class="grid">
                        <label>\(t.cardCode)<select name="connectionCardCode">\(cardOptions)</select></label>
                        <label>\(t.notes)<input type="text" name="notes" placeholder="..."></label>
                    </div>
                    <button type="submit">\(t.addBtn)</button>
                </form>
                </article>
            </details>
            """

        let tableSection: String
        if rows.isEmpty {
            tableSection = ""
        } else {
            tableSection =
                "<div style=\"overflow-x:auto\"><table role=\"grid\"><thead><tr>"
                + "<th>\(t.thCategory)</th><th>\(t.thBrand)</th><th>\(t.thModel)</th>"
                + "<th>\(t.thConnRef)</th><th>\(t.thPentax)</th>"
                + "<th>\(t.thCycle)</th><th>\(t.thCard)</th>"
                + "<th>PDF</th><th>Actions</th>"
                + "</tr></thead><tbody>"
                + tableRows
                + "</tbody></table></div>"
        }

        let body = """
            <hgroup>
                <h1>\(t.pageTitle)</h1>
                <p>\(t.endoCount(rows.count)) &nbsp;·&nbsp; \(allPill) · \(pills)</p>
            </hgroup>
            \(searchBar)
            <br>
            \(addForm)
            <br>
            \(emptyNote)
            \(tableSection)
            """

        return layout(title: t.pageTitle, body: body, lang: lang)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Detail / Edit page
    // ─────────────────────────────────────────────────────────────────────────

    static func renderDetail(
        endoscope: Endoscope, pdf: PdfDocument?, categories: [Category],
        pdfDocuments: [PdfDocument], lang: String = "en"
    )
        -> HTML
    {
        let t = L10n.from(lang)
        let id = endoscope.id ?? 0

        let pdfSection: String
        if let pdf = pdf {
            pdfSection = """
                <p>
                    <strong>\(t.connCardPdf)</strong>
                    <a href="/pdfs/\(pdf.fileName)" target="_blank">
                        📄 \(escape(pdf.documentKey)) — version \(pdf.version)
                    </a>
                </p>
                """
        } else {
            pdfSection =
                "<p><strong>\(t.connCardPdf)</strong> <em>\(t.noPdfFound) \(escape(endoscope.connectionCardCode)).</em></p>"
        }

        let categoryOptions = categories.map { cat -> String in
            guard let cid = cat.id else { return "" }
            let selected = cid == endoscope.categoryId ? " selected" : ""
            return "<option value='\(cid)'\(selected)>\(escape(cat.name))</option>"
        }.joined()

        var seenKeys2 = Set<String>()
        let currentNorm = endoscope.normalisedCardCode
        let cardOptions =
            "<option value=''>— None —</option>"
            + pdfDocuments.compactMap { pdf -> String? in
                guard seenKeys2.insert(pdf.matchKey).inserted else { return nil }
                let sel = pdf.matchKey == currentNorm ? " selected" : ""
                return "<option value='\(pdf.matchKey)'\(sel)>\(escape(pdf.matchKey))</option>"
            }.joined()

        let body = """
            <a href="/">\(t.backToList)</a>
            <hgroup style="margin-top:1rem">
                <h2>\(escape(endoscope.brand)) \(escape(endoscope.model))</h2>
                <p>\(t.category): <span class="badge">\(escape(categories.first(where: { $0.id == endoscope.categoryId })?.name ?? "—"))</span></p>
            </hgroup>
            \(pdfSection)
            <article>
                <h3>\(t.editEndoscope)</h3>
                <form action="/endoscope/\(id)/update" method="post">
                    <div class="grid">
                        <label>\(t.brand)<input type="text" name="brand" value="\(escape(endoscope.brand))" required></label>
                        <label>\(t.model)<input type="text" name="model" value="\(escape(endoscope.model))" required></label>
                        <label>\(t.category)
                            <select name="categoryId">\(categoryOptions)</select>
                        </label>
                    </div>
                    <div class="grid">
                        <label>\(t.connSetRef)<input type="text" name="connectionSetRef" value="\(escape(endoscope.connectionSetRef))"></label>
                        <label>\(t.pentaxItem)<input type="text" name="pentaxItemNumber" value="\(escape(endoscope.pentaxItemNumber))"></label>
                        <label>\(t.cycleCode)<input type="text" name="cycleCode" value="\(escape(endoscope.cycleCode))"></label>
                    </div>
                    <div class="grid">
                        <label>\(t.cardCode)
                            <select name="connectionCardCode">\(cardOptions)</select>
                        </label>
                        <label>\(t.notes)<input type="text" name="notes" value="\(escape(endoscope.notes))"></label>
                    </div>
                    <button type="submit">\(t.saveChanges)</button>
                </form>
            </article>
            <article style="border-color:#d62828">
                <h3 class="danger">\(t.dangerZone)</h3>
                <form action="/endoscope/\(id)/delete" method="post"
                      onsubmit="return confirm('\(t.confirmDelete(escape(endoscope.model)))')">
                    <button type="submit" style="background:#d62828;border-color:#d62828">\(t.deleteThisEndo)</button>
                </form>
            </article>
            """

        return layout(title: "\(endoscope.brand) \(endoscope.model)", body: body, lang: lang)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: Categories management page
    // ─────────────────────────────────────────────────────────────────────────

    static func renderCategories(categories: [Category], lang: String = "en") -> HTML {
        let t = L10n.from(lang)
        let rows = categories.map { cat -> String in
            guard let id = cat.id else { return "" }
            return """
                <article>
                    <form action="/category/\(id)/update" method="post" style="display:flex;gap:.5rem;align-items:flex-start;flex-wrap:wrap">
                        <div style="flex:1;min-width:160px">
                            <input type="text" name="name" value="\(escape(cat.name))" required style="margin-bottom:.25rem">
                            <input type="text" name="description" value="\(escape(cat.description))" placeholder="\(t.catDescLabel)">
                        </div>
                        <div style="display:flex;gap:.5rem;align-items:center;padding-top:.25rem">
                            <button type="submit" class="outline" style="padding:4px 12px">\(t.save)</button>
                        </div>
                    </form>
                    <form action="/category/\(id)/delete" method="post" style="margin-top:.5rem"
                          onsubmit="return confirm('\(t.confirmDeleteCat(escape(cat.name)))')">
                        <button type="submit" class="outline danger" style="padding:2px 8px;font-size:.8rem">\(t.deleteCatBtn)</button>
                    </form>
                </article>
                """
        }.joined()

        let body = """
            <a href="/">\(t.backToList)</a>
            <hgroup style="margin-top:1rem">
                <h2>\(t.categoriesTitle)</h2>
                <p>\(t.categoriesDesc)</p>
            </hgroup>
            \(rows)
            <article>
                <h3>\(t.addCatTitle)</h3>
                <form action="/categories/add" method="post">
                    <div class="grid">
                        <label>\(t.catName)<input type="text" name="name" required placeholder="e.g. NovaTYPHOON"></label>
                        <label>\(t.catDescLabel)<input type="text" name="description" placeholder="..."></label>
                    </div>
                    <button type="submit">\(t.addCatBtn)</button>
                </form>
            </article>
            <article>
                <h3>\(t.resetTitle)</h3>
                <p>\(t.resetDesc)</p>
                <form action="/import/csv" method="post"
                      onsubmit="return confirm('\(t.resetConfirm)')">
                    <button type="submit" style="background:#d62828;border-color:#d62828">\(t.resetBtn)</button>
                </form>
            </article>
            """

        return layout(title: t.categoriesTitle, body: body, lang: lang)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: 404
    // ─────────────────────────────────────────────────────────────────────────

    static func renderNotFound(lang: String = "en") -> HTML {
        let t = L10n.from(lang)
        return layout(
            title: t.notFoundTitle,
            body: "<h2>\(t.notFoundTitle)</h2><a href='/'>\(t.backSimple)</a>", lang: lang)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: HTML escape helper
    // ─────────────────────────────────────────────────────────────────────────

    private static func escape(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}
