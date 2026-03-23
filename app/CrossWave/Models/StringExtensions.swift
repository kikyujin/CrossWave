//
//  StringExtensions.swift
//  CrossWave
//
//  全角→半角変換

import Foundation

extension String {
    func toHalfWidth() -> String {
        var result = self
        // 全角英数字・記号 (U+FF01〜U+FF5E) → 半角 (U+0021〜U+007E)
        result = result.unicodeScalars.map { scalar in
            if scalar.value >= 0xFF01 && scalar.value <= 0xFF5E {
                return String(UnicodeScalar(scalar.value - 0xFEE0)!)
            }
            return String(scalar)
        }.joined()
        // 全角スペース→半角スペース
        result = result.replacingOccurrences(of: "\u{3000}", with: " ")
        return result
    }
}
