//
//  AppConstants.swift
//  CrossWave
//

import Foundation

enum AppConstants {
    static let baseURL = "http://localhost:8670"

    // UserDefaults keys
    static let lastExportedIdTo = "lastExportedIdTo"
}

extension Notification.Name {
    static let qsoUpdated = Notification.Name("qso.updated")
    static let qsoInject = Notification.Name("qso.inject")
}
