//
//  LogbookAPI.swift
//  CrossWave
//

import Foundation
import SwiftUI
import Combine

@MainActor
class LogbookAPI: ObservableObject {
    @Published var records: [QSORecord] = []
    @Published var total: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

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

    func fetchQSO(limit: Int = 200, offset: Int = 0, order: String = "asc") async {
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
