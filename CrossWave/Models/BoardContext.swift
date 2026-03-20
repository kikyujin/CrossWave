//
//  BoardContext.swift
//  CrossWave
//
//  ボード起動パラメータ

import Foundation

/// ログボードに渡す起動パラメータ
struct LogBoardContext {
    let callsignFilter: String?
    let onSelect: ((Int) -> Void)?     // ダブルクリック時にDBのidを渡す。nilなら何も起きない

    static let `default` = LogBoardContext(callsignFilter: nil, onSelect: nil)
}
