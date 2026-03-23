//
//  ContentView.swift
//  CrossWave
//

import SwiftUI

struct ContentView: View {
    @StateObject private var api = LogbookAPI()
    @ObservedObject var panelController: FloatingPanelControllerWrapper

    /// ボード起動パラメータ
    var context: LogBoardContext = .default

    /// 初期ピン状態（コントロールボードから開いた場合 true）
    var initialPinned: Bool = false

    /// フィルタ適用済みレコード
    private var displayRecords: [QSORecord] {
        guard let filter = context.callsignFilter, !filter.isEmpty else {
            return api.records
        }
        let upper = filter.uppercased()
        return api.records.filter { $0.callsign.uppercased().contains(upper) }
    }

    @State private var isPinned = false

    var body: some View {
        VStack(spacing: 0) {
            // 統計バー
            StatsBarView(records: displayRecords, total: context.callsignFilter != nil ? displayRecords.count : api.total, hamlogStatus: api.hamlogStatus)

            // ログ一覧
            if api.isLoading {
                Spacer()
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(CW.amber)
                Spacer()
            } else if displayRecords.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text(context.callsignFilter != nil ? "NO MATCHING QSO" : "NO QSO DATA")
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
                QSOListView(
                    records: displayRecords,
                    onSelect: context.onSelect,
                    onEdit: context.callsignFilter == nil ? { id in panelController.openEdit(id: id) } : nil,
                    showContextMenu: context.callsignFilter == nil
                )
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
                    panelController.openExport(records: api.records)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                        Text("EXPORT")
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(2)
                    }
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if let panel = NSApp.keyWindow {
                        panelController.togglePin(panel)
                        isPinned.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isPinned ? "pin.fill" : "pin")
                            .foregroundColor(isPinned ? CW.amber : nil)
                        Text(isPinned ? "PINNED" : "PIN")
                            .font(.system(size: 11, design: .monospaced))
                            .tracking(2)
                    }
                }
            }
        }
        .task {
            await api.fetchQSO()
        }
        .onAppear {
            isPinned = initialPinned
            api.startHamlogPolling()
        }
        .onDisappear {
            api.stopHamlogPolling()
        }
        .onReceive(NotificationCenter.default.publisher(for: .qsoUpdated)) { _ in
            Task { await api.fetchQSO() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hamlogStatusUpdated)) { notification in
            if let raw = notification.userInfo?["status"] as? String,
               let status = HamlogStatus(rawValue: raw) {
                api.hamlogStatus = status
            }
        }
        .focusable()
        .onKeyPress(.return) {
            panelController.openNew()
            return .handled
        }
        .onExitCommand {
            // ピン留め中はESCで閉じない
            guard !isPinned else { return }
            if let panel = NSApp.keyWindow as? NSPanel {
                panel.close()
            }
        }
    }

    private var footerBar: some View {
        HStack {
            Text("CROSSWAVE v0.1 — open-logbook")
                .font(.system(size: 10, design: .monospaced))
                .tracking(2)
                .foregroundColor(CW.textDim)
            Spacer()
            Text("\(context.callsignFilter != nil ? displayRecords.count : api.total) QSOs")
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
    ContentView(panelController: FloatingPanelControllerWrapper(), context: .default)
        .frame(width: 1000, height: 600)
}
