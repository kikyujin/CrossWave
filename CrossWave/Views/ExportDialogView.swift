//
//  ExportDialogView.swift
//  CrossWave
//
//  CSVエクスポートダイアログ

import SwiftUI
import UniformTypeIdentifiers

// fileExporter用のDocumentラッパー
struct CSVFile: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        self.data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct ExportDialogView: View {
    var records: [QSORecord] = []
    @Environment(\.dismiss) private var dismiss

    @State private var noFromText = ""
    @State private var noToText = ""
    @State private var isExporting = false
    @State private var resultMessage: String?
    @State private var resultIsError = false
    @State private var csvFile: CSVFile?
    @State private var showFileExporter = false

    private let fieldBg = Color(hex: "#0d0d18")
    private let fieldBorder = Color(hex: "#2a2a44")

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("EXPORT CSV")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(CW.amber)
                Spacer()
                Button { dismiss() } label: {
                    Text("\u{2715}")
                        .foregroundColor(CW.textDim)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Color(hex: "#161628"))
            .overlay(
                Rectangle().frame(height: 2).foregroundColor(CW.amber),
                alignment: .top
            )
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(CW.border),
                alignment: .bottom
            )

            // フィールド
            VStack(alignment: .leading, spacing: 16) {
                Text("NO範囲を指定（空欄で全件）")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CW.textDim)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FROM NO")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(CW.textDim)
                        TextField("1", text: $noFromText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 120)
                            .background(fieldBg)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(fieldBorder))
                            .cornerRadius(2)
                            .onChange(of: noFromText) {
                                noFromText = noFromText.filter(\.isNumber)
                            }
                    }

                    Text("\u{2192}")
                        .foregroundColor(CW.textDim)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TO NO")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(CW.textDim)
                        TextField("999", text: $noToText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 120)
                            .background(fieldBg)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(fieldBorder))
                            .cornerRadius(2)
                            .onChange(of: noToText) {
                                noToText = noToText.filter(\.isNumber)
                            }
                    }
                }

                if let msg = resultMessage {
                    Text(msg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(resultIsError ? CW.red : CW.green)
                }
            }
            .padding(20)

            // アクションバー
            HStack {
                Button {
                    Task { await doExport() }
                } label: {
                    Text(isExporting ? "EXPORTING..." : "EXPORT")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(CW.amber)
                        .cornerRadius(2)
                }
                .buttonStyle(.plain)
                .disabled(isExporting)
                .opacity(isExporting ? 0.4 : 1.0)

                Button { dismiss() } label: {
                    Text("CANCEL")
                        .font(.system(size: 11, design: .monospaced))
                        .tracking(2)
                        .foregroundColor(CW.textMid)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(CW.border))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(hex: "#161628"))
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(CW.border),
                alignment: .top
            )
        }
        .frame(width: 420)
        .background(Color(hex: "#1a1a2e"))
        .onAppear { applyPreset() }
        .fileExporter(
            isPresented: $showFileExporter,
            document: csvFile,
            contentType: .commaSeparatedText,
            defaultFilename: "qso_export.csv"
        ) { result in
            switch result {
            case .success(let url):
                resultMessage = "Exported to \(url.lastPathComponent)"
                resultIsError = false
                // エクスポート成功時にTOの値を保存
                if let toValue = Int(noToText) {
                    UserDefaults.standard.set(toValue, forKey: AppConstants.lastExportedIdTo)
                }
            case .failure(let error):
                resultMessage = error.localizedDescription
                resultIsError = true
            }
            isExporting = false
        }
    }

    private func applyPreset() {
        let lastTo = UserDefaults.standard.integer(forKey: AppConstants.lastExportedIdTo)
        if lastTo > 0 {
            noFromText = "\(lastTo + 1)"
        } else {
            noFromText = "1"
        }
        if !records.isEmpty {
            noToText = "\(records.count)"
        }
    }

    private func doExport() async {
        isExporting = true
        resultMessage = nil

        // 表示NO範囲でrecords配列をスライス（1始まり）
        let from = Int(noFromText) ?? 1
        let to = Int(noToText) ?? records.count

        guard !records.isEmpty else {
            resultMessage = "No records to export"
            resultIsError = true
            isExporting = false
            return
        }

        let startIdx = max(from - 1, 0)
        let endIdx = min(to - 1, records.count - 1)

        guard startIdx <= endIdx else {
            resultMessage = "Invalid range"
            resultIsError = true
            isExporting = false
            return
        }

        // 表示NOに対応するレコードを1つ1つ取り出してCSV生成
        let slice = Array(records[startIdx...endIdx])
        let csvString = buildCSV(from: slice, startNo: from)

        // Windows旧ツール互換のためShift_JISで出力
        guard let csvData = csvString.data(using: .shiftJIS) else {
            resultMessage = "Failed to encode CSV"
            resultIsError = true
            isExporting = false
            return
        }

        csvFile = CSVFile(data: csvData)
        showFileExporter = true
    }

    private func buildCSV(from recs: [QSORecord], startNo: Int) -> String {
        var lines: [String] = []
        for r in recs {
            let fields = [
                hamlogQuote(r.callsign),
                hamlogQuote(r.date),
                hamlogQuote(r.time),
                hamlogQuote(r.hisRst),
                hamlogQuote(r.myRst),
                hamlogQuote(r.freq),
                hamlogQuote(r.mode),
                hamlogQuote(r.code),
                hamlogQuote(r.gridLocator),
                hamlogQuote(r.qslStatus),
                hamlogQuote(r.name),
                hamlogQuote(r.qth),
                hamlogQuote(r.remarks1),
                hamlogQuote(r.remarks2),
                hamlogQuote("\(r.flag)"),
                hamlogQuote(r.user)
            ]
            lines.append(fields.joined(separator: ","))
        }
        return lines.joined(separator: "\r\n")
    }

    /// HAMLOG互換クォーティング: スペースまたは % を含む場合のみダブルクォート
    private func hamlogQuote(_ value: String) -> String {
        if value.contains(" ") || value.contains("%") || value.contains(",") || value.contains("\"") {
            return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
        }
        return value
    }
}
