//
//  CWColors.swift
//  CrossWave
//

import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        let scanner = Scanner(string: hex)
        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)
        let r = Double((rgbValue & 0xFF0000) >> 16) / 255.0
        let g = Double((rgbValue & 0x00FF00) >> 8) / 255.0
        let b = Double(rgbValue & 0x0000FF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}

enum CW {
    static let bg        = Color(hex: "#0a0a0c")
    static let panel     = Color(hex: "#111114")
    static let border    = Color(hex: "#1e1e24")
    static let amber     = Color(hex: "#f5a623")
    static let amberDim  = Color(hex: "#7a5210")
    static let green     = Color(hex: "#39ff8a")
    static let textPrim  = Color(hex: "#e8e4d8")
    static let textMid   = Color(hex: "#8a867a")
    static let textDim   = Color(hex: "#4a4840")
    static let blue      = Color(hex: "#8ab4ff")
    static let red       = Color(hex: "#ff3b3b")
}
