//
//  ContentView.swift
//  CrossWave
//

import SwiftUI

struct ContentView: View {
    @StateObject private var api = LogbookAPI()
    @ObservedObject var panelController: FloatingPanelControllerWrapper


    var body: some View {
        VStack(spacing: 0) {
            // 統計バー
            StatsBarView(records: api.records, total: api.total)

            // ログ一覧
            if api.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(CW.amber)
                Spacer()
            } else if api.records.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("NO QSO DATA")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .tracking(4)
                        .foregroundColor(CW.textDim)
                    if let err = api.errorMessage {
                        Text(err)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CW.red.opacity(0.7))
                    }
                }
                Spacer()
            } else {
                QSOListView(records: api.records)
            }

            // フッター
            footerBar
        }
        .background(CW.bg)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    panelController.openNew()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("NEW QSO")
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(2)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    panelController.openExport()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("EXPORT")
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(2)
                    }
                }
            }
        }
        .task {
            await api.fetchQSO()
        }
        .onReceive(NotificationCenter.default.publisher(for: .qsoUpdated)) { _ in
            Task { await api.fetchQSO() }
        }
    }

    private var footerBar: some View {
        HStack {
            Text("CROSSWAVE v0.1 — open-logbook")
                .font(.system(size: 10, design: .monospaced))
                .tracking(2)
                .foregroundColor(CW.textDim)
            Spacer()
            Text("\(api.total) QSOs")
                .font(.system(size: 10, design: .monospaced))
                .tracking(2)
                .foregroundColor(CW.amberDim)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(CW.border),
            alignment: .top
        )
    }
}

#Preview {
    ContentView(panelController: FloatingPanelControllerWrapper())
        .frame(width: 1000, height: 600)
}
