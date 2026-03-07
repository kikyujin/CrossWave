//
//  ControlBoardView.swift
//  CrossWave
//
//  コントロールボード: アプリのルート画面

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ControlBoardView: View {
    @ObservedObject var panelController: FloatingPanelControllerWrapper

    // インポート状態
    @State private var isImporting = false
    @State private var importMessage: String?
    @State private var importIsError = false

    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Text("CROSSWAVE")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .tracking(6)
                    .foregroundColor(CW.amber)

                Spacer()

                Text("CONTROL")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(4)
                    .foregroundColor(CW.textDim)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 20)
            .overlay(
                Rectangle().frame(height: 2).foregroundColor(CW.amber),
                alignment: .top
            )
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(CW.border),
                alignment: .bottom
            )

            Spacer()

            // メインボタン
            VStack(spacing: 20) {
                // ログボードを開く
                controlButton(
                    icon: "list.bullet.rectangle",
                    title: "LOG BOARD",
                    subtitle: "QSOログ一覧を表示"
                ) {
                    openLogBoard()
                }

                // NEW QSO
                controlButton(
                    icon: "plus.circle",
                    title: "NEW QSO",
                    subtitle: "新規QSO入力 (⌘N)"
                ) {
                    panelController.openNew()
                }

                Divider()
                    .background(CW.border)
                    .padding(.horizontal, 60)

                // CSVインポート
                controlButton(
                    icon: "square.and.arrow.down",
                    title: "CSV IMPORT",
                    subtitle: "HAMLOG CSVを取り込み",
                    isLoading: isImporting
                ) {
                    importCSV()
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // ステータス表示
            if let msg = importMessage {
                HStack {
                    Image(systemName: importIsError ? "exclamationmark.triangle" : "checkmark.circle")
                        .foregroundColor(importIsError ? CW.red : CW.green)
                    Text(msg)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(importIsError ? CW.red : CW.green)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(
                    Rectangle().frame(height: 1).foregroundColor(CW.border),
                    alignment: .top
                )
            }

            // フッター
            HStack {
                Text("CROSSWAVE v0.1 — open-logbook")
                    .font(.system(size: 10, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(CW.textDim)
                Spacer()
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 10)
            .overlay(
                Rectangle().frame(height: 1).foregroundColor(CW.border),
                alignment: .top
            )
        }
        .background(CW.bg)
    }

    // MARK: - Actions

    private func openLogBoard() {
        let logView = ContentView(panelController: panelController)
        panelController.openPanel(
            content: logView,
            title: "LOG BOARD",
            width: 1200,
            height: 700
        )
    }

    private func importCSV() {
        let panel = NSOpenPanel()
        panel.title = "HAMLOG CSVを選択"
        panel.allowedContentTypes = [.commaSeparatedText, .plainText]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let fileURL = panel.url else { return }

        isImporting = true
        importMessage = nil

        Task {
            do {
                let api = LogbookAPI()
                let result = try await api.importCSV(fileURL: fileURL)
                importMessage = "\(result.imported) imported, \(result.skipped) skipped, \(result.errors) errors"
                importIsError = result.errors > 0
                NotificationCenter.default.post(name: .qsoUpdated, object: nil)
            } catch {
                importMessage = error.localizedDescription
                importIsError = true
            }
            isImporting = false
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func controlButton(
        icon: String,
        title: String,
        subtitle: String,
        isLoading: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .controlSize(.small)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(CW.amber)
                        .frame(width: 28, height: 28)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(3)
                        .foregroundColor(CW.textPrim)
                    Text(subtitle)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(CW.textDim)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(CW.textDim)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(CW.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(CW.border, lineWidth: 1)
            )
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}
