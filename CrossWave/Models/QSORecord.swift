//
//  QSORecord.swift
//  CrossWave
//

import Foundation

struct QSORecord: Identifiable, Codable {
    let id: Int
    let callsign: String
    let date: String
    let time: String
    let hisRst: String
    let myRst: String
    let freq: String
    let mode: String
    let code: String
    let gridLocator: String
    let qslStatus: String
    let name: String
    let qth: String
    let remarks1: String
    let remarks2: String
    let flag: Int
    let user: String
    let source: String

    enum CodingKeys: String, CodingKey {
        case id, callsign, date, time, freq, mode, code, name, qth, flag, user, source
        case hisRst      = "his_rst"
        case myRst       = "my_rst"
        case gridLocator = "grid_locator"
        case qslStatus   = "qsl_status"
        case remarks1, remarks2
    }
}

struct QSOResponse: Codable {
    let total: Int
    let qso: [QSORecord]
}

struct ImportResult: Codable {
    let status: String
    let imported: Int
    let skipped: Int
    let errors: Int
    let errorDetails: [String]?

    enum CodingKeys: String, CodingKey {
        case status, imported, skipped, errors
        case errorDetails = "error_details"
    }
}

struct CallsignCandidate: Codable, Identifiable {
    let callsign: String
    let name: String
    let qth: String
    let code: String

    var id: String { callsign }
}

struct QSOInput: Codable {
    let callsign: String
    let date: String
    let time: String
    let freq: String
    let mode: String
    let hisRst: String
    let myRst: String
    let code: String
    let qslStatus: String
    let name: String
    let qth: String
    let remarks1: String
    let remarks2: String

    enum CodingKeys: String, CodingKey {
        case callsign, date, time, freq, mode, code, name, qth, remarks1, remarks2
        case hisRst    = "his_rst"
        case myRst     = "my_rst"
        case qslStatus = "qsl_status"
    }
}
