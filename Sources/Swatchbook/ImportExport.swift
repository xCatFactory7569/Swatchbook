import SwiftUI
import AppKit

// MARK: - File format used for JSON export and backups

struct ExportFile: Codable {
    var format = "swatchbook"
    var version = 1
    var palettes: [Palette]
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json, ase, css, text
    var id: String { rawValue }

    var label: String {
        switch self {
        case .json: return "Swatchbook JSON (.json)"
        case .ase: return "Adobe Swatch Exchange (.ase)"
        case .css: return "CSS Variables (.css)"
        case .text: return "Plain Text (.txt)"
        }
    }

    var fileExtension: String {
        switch self {
        case .json: return "json"
        case .ase: return "ase"
        case .css: return "css"
        case .text: return "txt"
        }
    }
}

// MARK: - Exporting

enum Exporter {
    static func data(for palettes: [Palette], format: ExportFormat) -> Data? {
        switch format {
        case .json:
            var list = palettes
            for i in list.indices { list[i].lastOpened = nil }
            let enc = JSONEncoder()
            enc.outputFormatting = [.prettyPrinted, .sortedKeys]
            return try? enc.encode(ExportFile(palettes: list))
        case .ase:
            return ASE.encode(palettes)
        case .css:
            return css(palettes).data(using: .utf8)
        case .text:
            return text(palettes).data(using: .utf8)
        }
    }

    static func slugify(_ s: String) -> String {
        var out = ""
        var lastDash = false
        for ch in s.lowercased() {
            if ch.isLetter || ch.isNumber {
                out.append(ch)
                lastDash = false
            } else if !lastDash && !out.isEmpty {
                out.append("-")
                lastDash = true
            }
        }
        while out.hasSuffix("-") { out.removeLast() }
        return out.isEmpty ? "color" : out
    }

    static func css(_ palettes: [Palette]) -> String {
        var out = ":root {\n"
        for (pi, p) in palettes.enumerated() {
            if pi > 0 { out += "\n" }
            out += "  /* \(p.name.isEmpty ? "Untitled" : p.name) */\n"
            var used = Set<String>()
            for (i, c) in p.colors.enumerated() {
                let colorPart = slugify(c.name.isEmpty ? "color-\(i + 1)" : c.name)
                var slug = slugify(p.name.isEmpty ? "palette" : p.name) + "-" + colorPart
                if used.contains(slug) { slug += "-\(i + 1)" }
                used.insert(slug)
                out += "  --\(slug): #\(c.hex);\n"
            }
        }
        out += "}\n"
        return out
    }

    static func text(_ palettes: [Palette]) -> String {
        var out = ""
        for (i, p) in palettes.enumerated() {
            if palettes.count > 1 {
                if i > 0 { out += "\n" }
                out += "# \(p.name.isEmpty ? "Untitled" : p.name)\n"
            }
            for c in p.colors {
                out += c.name.isEmpty ? "#\(c.hex)\n" : "\(c.name) #\(c.hex)\n"
            }
        }
        return out
    }
}

// MARK: - Adobe Swatch Exchange (.ase)

enum ASE {
    static func encode(_ palettes: [Palette]) -> Data {
        var d = Data()
        func p16(_ v: Int) {
            d.append(UInt8((v >> 8) & 255))
            d.append(UInt8(v & 255))
        }
        func p32(_ v: Int) {
            for s in [24, 16, 8, 0] { d.append(UInt8((v >> s) & 255)) }
        }
        func units(_ s: String) -> [UInt16] { Array(s.utf16) + [0] }
        func putName(_ u: [UInt16]) { for x in u { p16(Int(x)) } }

        d.append(contentsOf: [0x41, 0x53, 0x45, 0x46])          // "ASEF"
        p16(1); p16(0)                                           // version 1.0
        p32(palettes.reduce(0) { $0 + 2 + $1.colors.count })     // number of blocks

        for p in palettes {
            let gn = units(p.name.isEmpty ? "Untitled" : p.name)
            p16(0xC001); p32(2 + gn.count * 2); p16(gn.count); putName(gn)      // group start
            for c in p.colors {
                let nm = units(c.displayName)
                let v = Hex.rgb(c.hex)
                p16(0x0001)
                p32(2 + nm.count * 2 + 4 + 12 + 2)
                p16(nm.count); putName(nm)
                d.append(contentsOf: Array("RGB ".utf8))
                for f in [v.r, v.g, v.b] { p32(Int(Float(f).bitPattern)) }
                p16(2)                                                          // "normal" color
            }
            p16(0xC002); p32(0)                                                 // group end
        }
        return d
    }

    static func decode(_ data: Data, fallbackName: String) -> [Palette]? {
        let b = [UInt8](data)
        guard b.count >= 12, b[0] == 0x41, b[1] == 0x53, b[2] == 0x45, b[3] == 0x46 else { return nil }

        func u16(_ o: Int) -> Int { (Int(b[o]) << 8) | Int(b[o + 1]) }
        func u32(_ o: Int) -> Int {
            (Int(b[o]) << 24) | (Int(b[o + 1]) << 16) | (Int(b[o + 2]) << 8) | Int(b[o + 3])
        }
        func f32(_ o: Int) -> Double { Double(Float(bitPattern: UInt32(truncatingIfNeeded: u32(o)))) }
        func text(_ o: Int, _ units: Int) -> String {
            var u: [UInt16] = []
            for k in 0..<units { u.append(UInt16(truncatingIfNeeded: u16(o + k * 2))) }
            if u.last == 0 { u.removeLast() }
            return String(decoding: u, as: UTF16.self)
        }
        func byte(_ x: Double) -> Int { Int((min(max(x, 0), 1) * 255).rounded()) }

        let blockCount = u32(8)
        var pos = 12
        var seen = 0
        var palettes: [Palette] = []
        var current: Palette? = nil
        var loose = Palette(name: fallbackName)

        while seen < blockCount, pos + 6 <= b.count {
            let type = u16(pos)
            let length = u32(pos + 2)
            let body = pos + 6
            guard body + length <= b.count else { break }

            switch type {
            case 0xC001:                                   // group start
                if length >= 2 {
                    let n = u16(body)
                    if body + 2 + n * 2 <= body + length {
                        current = Palette(name: text(body + 2, n))
                    }
                }
            case 0xC002:                                   // group end
                if let c = current {
                    palettes.append(c)
                    current = nil
                }
            case 0x0001:                                   // color entry
                guard length >= 2 else { break }
                let n = u16(body)
                let modelAt = body + 2 + n * 2
                guard modelAt + 4 <= body + length else { break }
                let model = String(decoding: b[modelAt..<(modelAt + 4)], as: UTF8.self)
                let v = modelAt + 4
                var rgb: (Double, Double, Double)? = nil
                switch model {
                case "RGB " where v + 12 <= body + length:
                    rgb = (f32(v), f32(v + 4), f32(v + 8))
                case "CMYK" where v + 16 <= body + length:
                    let c = f32(v), m = f32(v + 4), y = f32(v + 8), k = f32(v + 12)
                    rgb = ((1 - c) * (1 - k), (1 - m) * (1 - k), (1 - y) * (1 - k))
                case "Gray" where v + 4 <= body + length:
                    let g = f32(v)
                    rgb = (g, g, g)
                default:
                    break
                }
                if let (r, g, bl) = rgb {
                    let hex = String(format: "%02X%02X%02X", byte(r), byte(g), byte(bl))
                    let color = SwatchColor(name: text(body + 2, n), hex: hex)
                    if current != nil {
                        current!.colors.append(color)
                    } else {
                        loose.colors.append(color)
                    }
                }
            default:
                break
            }
            pos = body + length
            seen += 1
        }

        if let c = current { palettes.append(c) }
        if !loose.colors.isEmpty { palettes.insert(loose, at: 0) }
        return palettes.filter { !$0.colors.isEmpty }
    }
}

// MARK: - Importing

enum Importer {
    /// Reads a Swatchbook JSON file (export or backup).
    static func decodeSwatchbook(_ data: Data) -> [Palette]? {
        if let file = try? JSONDecoder().decode(ExportFile.self, from: data), file.format == "swatchbook" {
            return file.palettes
        }
        if let arr = try? JSONDecoder().decode([Palette].self, from: data),
           arr.contains(where: { !$0.colors.isEmpty }) {
            return arr
        }
        return nil
    }

    static func palettes(from url: URL) -> [Palette] {
        let base = url.deletingPathExtension().lastPathComponent
        guard let data = try? Data(contentsOf: url) else { return [] }
        switch url.pathExtension.lowercased() {
        case "json":
            return (decodeSwatchbook(data) ?? []).filter { !$0.colors.isEmpty }
        case "ase":
            return ASE.decode(data, fallbackName: base) ?? []
        case "clr":
            if let p = colorList(url: url, name: base) { return [p] }
            return []
        default:
            if let text = String(data: data, encoding: .utf8),
               let p = TextImport.palette(from: text, name: base) {
                return [p]
            }
            return []
        }
    }

    static func colorList(url: URL, name: String) -> Palette? {
        guard let list = NSColorList(name: name, fromFile: url.path) else { return nil }
        var p = Palette(name: name)
        for key in list.allKeys {
            guard let color = list.color(withKey: key) else { continue }
            p.colors.append(SwatchColor(name: key, hex: Hex.from(color)))
        }
        return p.colors.isEmpty ? nil : p
    }
}

enum TextImport {
    /// Finds #RRGGBB colors in any text file (CSS, notes, CSV...). Uses names found next to them.
    static func palette(from text: String, name: String) -> Palette? {
        guard let hexRe = try? NSRegularExpression(pattern: "#([0-9A-Fa-f]{6})\\b"),
              let varRe = try? NSRegularExpression(pattern: "--([A-Za-z0-9_-]+)\\s*:") else { return nil }
        var colors: [SwatchColor] = []
        let junk = CharacterSet(charactersIn: " \t:=,;-–—•*\"'/(){}[]")

        for line in text.components(separatedBy: .newlines) {
            let ns = line as NSString
            let full = NSRange(location: 0, length: ns.length)
            let matches = hexRe.matches(in: line, range: full)
            for m in matches {
                let hex = ns.substring(with: m.range(at: 1)).uppercased()
                var label = ""
                if matches.count == 1 {
                    if let v = varRe.firstMatch(in: line, range: full) {
                        label = ns.substring(with: v.range(at: 1))
                            .replacingOccurrences(of: "-", with: " ")
                            .replacingOccurrences(of: "_", with: " ")
                            .capitalized
                    } else {
                        label = ns.substring(to: m.range.location).trimmingCharacters(in: junk)
                    }
                }
                if label.count > 40 { label = "" }
                colors.append(SwatchColor(name: label, hex: hex))
            }
        }
        if colors.isEmpty { return nil }
        var p = Palette(name: name)
        p.colors = colors
        return p
    }
}

// MARK: - Reading colors from the clipboard (paste to add)

enum ColorParser {
    /// Returns hex strings ("RRGGBB") found in the text, in order. Understands #HEX, rgb() and hsl().
    static func extract(_ text: String) -> [String] {
        var found: [(Int, String)] = []
        let ns = text as NSString
        let all = NSRange(location: 0, length: ns.length)

        func scan(_ pattern: String, _ handler: (NSTextCheckingResult) -> String?) {
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return }
            for m in re.matches(in: text, range: all) {
                if let hex = handler(m) { found.append((m.range.location, hex)) }
            }
        }
        func group(_ m: NSTextCheckingResult, _ i: Int) -> String { ns.substring(with: m.range(at: i)) }
        func clamp255(_ x: Double) -> Int { Int(min(max(x, 0), 255).rounded()) }
        func hexString(_ r: Int, _ g: Int, _ b: Int) -> String { String(format: "%02X%02X%02X", r, g, b) }

        scan("#([0-9a-f]{6})\\b") { m in group(m, 1).uppercased() }
        scan("#([0-9a-f]{3})\\b") { m in
            group(m, 1).uppercased().map { "\($0)\($0)" }.joined()
        }
        scan("rgba?\\(\\s*(\\d{1,3})\\s*[, ]\\s*(\\d{1,3})\\s*[, ]\\s*(\\d{1,3})") { m in
            hexString(clamp255(Double(group(m, 1)) ?? 0),
                      clamp255(Double(group(m, 2)) ?? 0),
                      clamp255(Double(group(m, 3)) ?? 0))
        }
        scan("hsla?\\(\\s*(\\d{1,3}(?:\\.\\d+)?)(?:deg)?\\s*[, ]\\s*(\\d{1,3}(?:\\.\\d+)?)%\\s*[, ]\\s*(\\d{1,3}(?:\\.\\d+)?)%") { m in
            let h = (Double(group(m, 1)) ?? 0) / 360
            let s = min(max((Double(group(m, 2)) ?? 0) / 100, 0), 1)
            let l = min(max((Double(group(m, 3)) ?? 0) / 100, 0), 1)
            let q = l < 0.5 ? l * (1 + s) : l + s - l * s
            let p = 2 * l - q
            func channel(_ tIn: Double) -> Double {
                var t = tIn
                if t < 0 { t += 1 }
                if t > 1 { t -= 1 }
                if t < 1.0 / 6 { return p + (q - p) * 6 * t }
                if t < 1.0 / 2 { return q }
                if t < 2.0 / 3 { return p + (q - p) * (2.0 / 3 - t) * 6 }
                return p
            }
            return hexString(clamp255(channel(h + 1.0 / 3) * 255),
                             clamp255(channel(h) * 255),
                             clamp255(channel(h - 1.0 / 3) * 255))
        }

        // A bare 6-digit hex on its own ("7435C7")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if found.isEmpty, trimmed.count == 6, let hex = Hex.normalize(trimmed) {
            found.append((0, hex))
        }
        return found.sorted { $0.0 < $1.0 }.map { $0.1 }
    }
}

// MARK: - Import / export actions (open and save panels)

extension Store {
    func importPalettes() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose palette files: Swatchbook .json, Adobe .ase, macOS .clr, or any text/CSS file with #hex colors"
        guard panel.runModal() == .OK else { return }

        var imported: [Palette] = []
        for url in panel.urls { imported += Importer.palettes(from: url) }
        guard !imported.isEmpty else {
            showToast("No colors found in that file")
            return
        }

        registerPalettesUndo("Import Palettes")
        let existing = Set(palettes.map { $0.name.lowercased() })
        var added: [Palette] = []
        for p in imported {
            var np = Palette(name: p.name.isEmpty ? "Imported" : p.name,
                             colors: p.colors.map { SwatchColor(name: $0.name, hex: $0.hex) },
                             notes: p.notes,
                             locked: p.locked)
            if existing.contains(np.name.lowercased()) { np.name += " (imported)" }
            added.append(np)
        }
        palettes.append(contentsOf: added)
        selectedID = added.first?.id
        showToast("Imported \(added.count) palette\(added.count == 1 ? "" : "s")")
    }

    func exportPalettes(all: Bool, format: ExportFormat) {
        let list: [Palette]
        if all {
            list = palettes
        } else if let p = selected {
            list = [p]
        } else {
            showToast("Select a palette first")
            return
        }
        guard !list.isEmpty else { return }

        let panel = NSSavePanel()
        let baseName = all ? "Swatchbook Palettes" : (list[0].name.isEmpty ? "Palette" : list[0].name)
        panel.nameFieldStringValue = baseName.replacingOccurrences(of: "/", with: "-") + "." + format.fileExtension
        panel.message = "Export as \(format.label)"
        guard panel.runModal() == .OK, let url = panel.url,
              let data = Exporter.data(for: list, format: format) else { return }
        do {
            try data.write(to: url, options: .atomic)
            showToast("Exported \(list.count) palette\(list.count == 1 ? "" : "s")")
        } catch {
            showToast("Export failed")
        }
    }
}
