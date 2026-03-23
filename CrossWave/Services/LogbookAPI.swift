//
//  LogbookAPI.swift
//  CrossWave
//

import Foundation
import SwiftUI
import Combine

// MARK: - HAMLOG Status

enum HamlogStatus: String {
    case ready       // bham接続OK、HAMLOG稼働中
    case unavailable // bham接続なし or HAMLOG停止中
    case unknown     // 未確認（起動直後）
}

@MainActor
class LogbookAPI: ObservableObject {
    @Published var records: [QSORecord] = []
    @Published var total: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var hamlogStatus: HamlogStatus = .unknown

    // HAMLOG ポーリングはクラス共有（タイマー1本だけ）
    private static var hamlogTimer: Timer?
    private static var hamlogPollingRefCount = 0

    func importCSV(fileURL: URL) async throws -> ImportResult {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/import/csv") else {
            throw URLError(.badURL)
        }

        let boundary = UUID().uuidString
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let fileData = try Data(contentsOf: fileURL)
        let fileName = fileURL.lastPathComponent

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return try JSONDecoder().decode(ImportResult.self, from: data)
    }

    func exportCSV(idFrom: Int?, idTo: Int?) async throws -> Data {
        var urlString = "\(AppConstants.baseURL)/api/qso/export/csv"
        var params: [String] = []
        if let from = idFrom { params.append("id_from=\(from)") }
        if let to = idTo { params.append("id_to=\(to)") }
        if !params.isEmpty { urlString += "?" + params.joined(separator: "&") }

        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let msg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: msg])
        }

        return data
    }

    func searchCallsign(prefix: String) async -> [CallsignCandidate] {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/callsign_cache?q=\(prefix)&limit=10") else {
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return try JSONDecoder().decode([CallsignCandidate].self, from: data)
        } catch {
            return []
        }
    }

    func createQSO(_ input: QSOInput) async throws -> QSORecord {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/qso") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }

        return try JSONDecoder().decode(QSORecord.self, from: data)
    }

    func fetchQSO(id: Int) async throws -> QSORecord {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/qso/\(id)") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }

        return try JSONDecoder().decode(QSORecord.self, from: data)
    }

    // MARK: - Update QSO

    func updateQSO(id: Int, input: QSOInput) async throws -> QSORecord {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/qso/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(input)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode >= 400 {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw NSError(domain: "API", code: httpResponse.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: body])
        }

        return try JSONDecoder().decode(QSORecord.self, from: data)
    }

    // MARK: - Delete QSO

    func deleteQSO(id: Int) async throws {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/qso/\(id)") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        if httpResponse.statusCode == 404 {
            throw NSError(domain: "LogbookAPI", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Record not found"
            ])
        }

        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - HAMLOG Status Polling

    func fetchHamlogStatus() async -> HamlogStatus {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/hamlog/status") else {
            return .unavailable
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "ready" {
                return .ready
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    func startHamlogPolling() {
        // 即座に1回取得（各インスタンスの hamlogStatus を更新）
        Task {
            hamlogStatus = await fetchHamlogStatus()
        }
        // タイマーは1本だけ（参照カウントで管理）
        LogbookAPI.hamlogPollingRefCount += 1
        guard LogbookAPI.hamlogTimer == nil else { return }
        LogbookAPI.hamlogTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in
                // 全インスタンスではなく、通知で更新を伝える
                let status = await LogbookAPI.fetchHamlogStatusShared()
                NotificationCenter.default.post(
                    name: .hamlogStatusUpdated,
                    object: nil,
                    userInfo: ["status": status.rawValue]
                )
            }
        }
    }

    func stopHamlogPolling() {
        LogbookAPI.hamlogPollingRefCount -= 1
        if LogbookAPI.hamlogPollingRefCount <= 0 {
            LogbookAPI.hamlogTimer?.invalidate()
            LogbookAPI.hamlogTimer = nil
            LogbookAPI.hamlogPollingRefCount = 0
        }
    }

    /// タイマーコールバック用（インスタンス不要）
    private static func fetchHamlogStatusShared() async -> HamlogStatus {
        guard let url = URL(string: "\(AppConstants.baseURL)/api/hamlog/status") else {
            return .unavailable
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let status = json["status"] as? String,
               status == "ready" {
                return .ready
            }
            return .unavailable
        } catch {
            return .unavailable
        }
    }

    // MARK: - Callsign Lookup (HAMLOG)

    struct CallsignLookupResult: Codable {
        let source: String      // "cache", "hamlog", "none"
        let callsign: String
        let name: String?
        let qth: String?
        let code: String?
    }

    func lookupCallsign(_ callsign: String) async -> CallsignLookupResult? {
        guard !callsign.isEmpty,
              let encoded = callsign.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(AppConstants.baseURL)/api/callsign/lookup?q=\(encoded)") else {
            return nil
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            return try decoder.decode(CallsignLookupResult.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - QSO Fetch (list)

    func fetchQSO(limit: Int = 9999, offset: Int = 0, order: String = "asc") async {
        isLoading = true
        errorMessage = nil

        guard let url = URL(string: "\(AppConstants.baseURL)/api/qso?limit=\(limit)&offset=\(offset)&order=\(order)") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response = try JSONDecoder().decode(QSOResponse.self, from: data)
            records = response.qso
            total = response.total
        } catch {
            errorMessage = error.localizedDescription
            records = []
            total = 0
        }

        isLoading = false
    }
}
