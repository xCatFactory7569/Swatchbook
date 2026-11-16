import Foundation

/// Suggests a friendly name for a color by finding the closest one in a built-in list.
/// Works fully offline.
enum ColorNamer {
    private static let table: [(String, UInt32)] = [
        // Standard web color names
        ("Alice Blue", 0xF0F8FF), ("Antique White", 0xFAEBD7), ("Aqua", 0x00FFFF),
        ("Aquamarine", 0x7FFFD4), ("Azure", 0xF0FFFF), ("Beige", 0xF5F5DC),
        ("Bisque", 0xFFE4C4), ("Black", 0x000000), ("Blanched Almond", 0xFFEBCD),
        ("Blue", 0x0000FF), ("Blue Violet", 0x8A2BE2), ("Brown", 0xA52A2A),
        ("Burly Wood", 0xDEB887), ("Cadet Blue", 0x5F9EA0), ("Chartreuse", 0x7FFF00),
        ("Chocolate", 0xD2691E), ("Coral", 0xFF7F50), ("Cornflower Blue", 0x6495ED),
        ("Cornsilk", 0xFFF8DC), ("Crimson", 0xDC143C), ("Dark Blue", 0x00008B),
        ("Dark Cyan", 0x008B8B), ("Dark Goldenrod", 0xB8860B), ("Dark Gray", 0xA9A9A9),
        ("Dark Green", 0x006400), ("Dark Khaki", 0xBDB76B), ("Dark Magenta", 0x8B008B),
        ("Dark Olive Green", 0x556B2F), ("Dark Orange", 0xFF8C00), ("Dark Orchid", 0x9932CC),
        ("Dark Red", 0x8B0000), ("Dark Salmon", 0xE9967A), ("Dark Sea Green", 0x8FBC8F),
        ("Dark Slate Blue", 0x483D8B), ("Dark Slate Gray", 0x2F4F4F), ("Dark Turquoise", 0x00CED1),
        ("Dark Violet", 0x9400D3), ("Deep Pink", 0xFF1493), ("Deep Sky Blue", 0x00BFFF),
        ("Dim Gray", 0x696969), ("Dodger Blue", 0x1E90FF), ("Firebrick", 0xB22222),
        ("Floral White", 0xFFFAF0), ("Forest Green", 0x228B22), ("Fuchsia", 0xFF00FF),
        ("Gainsboro", 0xDCDCDC), ("Ghost White", 0xF8F8FF), ("Gold", 0xFFD700),
        ("Goldenrod", 0xDAA520), ("Gray", 0x808080), ("Green", 0x008000),
        ("Green Yellow", 0xADFF2F), ("Honeydew", 0xF0FFF0), ("Hot Pink", 0xFF69B4),
        ("Indian Red", 0xCD5C5C), ("Indigo", 0x4B0082), ("Ivory", 0xFFFFF0),
        ("Khaki", 0xF0E68C), ("Lavender", 0xE6E6FA), ("Lavender Blush", 0xFFF0F5),
        ("Lawn Green", 0x7CFC00), ("Lemon Chiffon", 0xFFFACD), ("Light Blue", 0xADD8E6),
        ("Light Coral", 0xF08080), ("Light Cyan", 0xE0FFFF), ("Light Goldenrod", 0xFAFAD2),
        ("Light Gray", 0xD3D3D3), ("Light Green", 0x90EE90), ("Light Pink", 0xFFB6C1),
        ("Light Salmon", 0xFFA07A), ("Light Sea Green", 0x20B2AA), ("Light Sky Blue", 0x87CEFA),
        ("Light Slate Gray", 0x778899), ("Light Steel Blue", 0xB0C4DE), ("Light Yellow", 0xFFFFE0),
        ("Lime", 0x00FF00), ("Lime Green", 0x32CD32), ("Linen", 0xFAF0E6),
        ("Maroon", 0x800000), ("Medium Aquamarine", 0x66CDAA), ("Medium Blue", 0x0000CD),
        ("Medium Orchid", 0xBA55D3), ("Medium Purple", 0x9370DB), ("Medium Sea Green", 0x3CB371),
        ("Medium Slate Blue", 0x7B68EE), ("Medium Spring Green", 0x00FA9A),
        ("Medium Turquoise", 0x48D1CC), ("Medium Violet Red", 0xC71585), ("Midnight Blue", 0x191970),
        ("Mint Cream", 0xF5FFFA), ("Misty Rose", 0xFFE4E1), ("Moccasin", 0xFFE4B5),
        ("Navajo White", 0xFFDEAD), ("Navy", 0x000080), ("Old Lace", 0xFDF5E6),
        ("Olive", 0x808000), ("Olive Drab", 0x6B8E23), ("Orange", 0xFFA500),
        ("Orange Red", 0xFF4500), ("Orchid", 0xDA70D6), ("Pale Goldenrod", 0xEEE8AA),
        ("Pale Green", 0x98FB98), ("Pale Turquoise", 0xAFEEEE), ("Pale Violet Red", 0xDB7093),
        ("Papaya Whip", 0xFFEFD5), ("Peach Puff", 0xFFDAB9), ("Peru", 0xCD853F),
        ("Pink", 0xFFC0CB), ("Plum", 0xDDA0DD), ("Powder Blue", 0xB0E0E6),
        ("Purple", 0x800080), ("Rebecca Purple", 0x663399), ("Red", 0xFF0000),
        ("Rosy Brown", 0xBC8F8F), ("Royal Blue", 0x4169E1), ("Saddle Brown", 0x8B4513),
        ("Salmon", 0xFA8072), ("Sandy Brown", 0xF4A460), ("Sea Green", 0x2E8B57),
        ("Seashell", 0xFFF5EE), ("Sienna", 0xA0522D), ("Silver", 0xC0C0C0),
        ("Sky Blue", 0x87CEEB), ("Slate Blue", 0x6A5ACD), ("Slate Gray", 0x708090),
        ("Snow", 0xFFFAFA), ("Spring Green", 0x00FF7F), ("Steel Blue", 0x4682B4),
        ("Tan", 0xD2B48C), ("Teal", 0x008080), ("Thistle", 0xD8BFD8),
        ("Tomato", 0xFF6347), ("Turquoise", 0x40E0D0), ("Violet", 0xEE82EE),
        ("Wheat", 0xF5DEB3), ("White", 0xFFFFFF), ("White Smoke", 0xF5F5F5),
        ("Yellow", 0xFFFF00), ("Yellow Green", 0x9ACD32),
        // Extra friendly names
        ("Charcoal", 0x36454F), ("Jet", 0x343434), ("Onyx", 0x353839),
        ("Ebony", 0x555D50), ("Mint", 0x3EB489), ("Sage", 0x9CAF88),
        ("Emerald", 0x50C878), ("Jade", 0x00A86B), ("Ruby", 0xE0115F),
        ("Cherry", 0xDE3163), ("Rose", 0xFF007F), ("Burgundy", 0x800020),
        ("Wine", 0x722F37), ("Cobalt", 0x0047AB), ("Sapphire", 0x0F52BA),
        ("Cerulean", 0x007BA7), ("Ultramarine", 0x3F00FF), ("Periwinkle", 0xCCCCFF),
        ("Lilac", 0xC8A2C8), ("Mauve", 0xE0B0FF), ("Amethyst", 0x9966CC),
        ("Mustard", 0xFFDB58), ("Amber", 0xFFBF00), ("Saffron", 0xF4C430),
        ("Peach", 0xFFE5B4), ("Apricot", 0xFBCEB1), ("Terracotta", 0xE2725B),
        ("Rust", 0xB7410E), ("Copper", 0xB87333), ("Bronze", 0xCD7F32),
        ("Cream", 0xFFFDD0), ("Sand", 0xC2B280), ("Taupe", 0x483C32),
        ("Espresso", 0x3C2415), ("Moss", 0x8A9A5B), ("Forest", 0x014421),
        ("Denim", 0x1560BD), ("Electric Violet", 0x8F00FF), ("Royal Purple", 0x7851A9),
        ("Cornflower", 0x9AB8F0), ("Ocean Blue", 0x1F4E8C), ("Night Blue", 0x0B1B3A)
    ]

    static func name(for hex: String) -> String {
        let v = Hex.rgb(hex)
        let r = Int((v.r * 255).rounded())
        let g = Int((v.g * 255).rounded())
        let b = Int((v.b * 255).rounded())

        var best = "Color"
        var bestDistance = Int.max
        for (name, value) in table {
            let c = Int(value)
            let cr = (c >> 16) & 255
            let cg = (c >> 8) & 255
            let cb = c & 255
            // "Redmean" distance: a cheap measure that follows how we see color differences
            let rmean = (r + cr) / 2
            let dr = r - cr, dg = g - cg, db = b - cb
            let distance = (((512 + rmean) * dr * dr) >> 8) + 4 * dg * dg + (((767 - rmean) * db * db) >> 8)
            if distance < bestDistance {
                bestDistance = distance
                best = name
            }
        }
        return best
    }
}
