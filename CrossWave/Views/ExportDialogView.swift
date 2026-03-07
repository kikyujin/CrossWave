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
    @Environment(\.dismiss) private var dismiss

    @State private var idFromText = ""
    @State private var idToText = ""
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
                Text("ID範囲を指定（空欄で全件）")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(CW.textDim)

                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("FROM ID")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(CW.textDim)
                        TextField("1", text: $idFromText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 120)
                            .background(fieldBg)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(fieldBorder))
                            .cornerRadius(2)
                            .onChange(of: idFromText) {
                                idFromText = idFromText.filter(\.isNumber)
                            }
                    }

                    Text("\u{2192}")
                        .foregroundColor(CW.textDim)
                        .padding(.top, 16)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("TO ID")
                            .font(.system(size: 9, design: .monospaced))
                            .tracking(3)
                            .foregroundColor(CW.textDim)
                        TextField("999", text: $idToText)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 7)
                            .frame(width: 120)
                            .background(fieldBg)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(fieldBorder))
                            .cornerRadius(2)
                            .onChange(of: idToText) {
                                idToText = idToText.filter(\.isNumber)
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
            case .failure(let error):
                resultMessage = error.localizedDescription
                resultIsError = true
            }
            isExporting = false
        }
    }

    private func doExport() async {
        isExporting = true
        resultMessage = nil

        let idFrom = Int(idFromText)
        let idTo = Int(idToText)

        do {
            let api = LogbookAPI()
            let csvData = try await api.exportCSV(idFrom: idFrom, idTo: idTo)
            csvFile = CSVFile(data: csvData)
            showFileExporter = true
            // isExporting は fileExporter の完了コールバックで false にする
        } catch {
            resultMessage = error.localizedDescription
            resultIsError = true
            isExporting = false
        }
    }
}
