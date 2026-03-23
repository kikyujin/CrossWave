//
//  QSOListView.swift
//  CrossWave
//

import SwiftUI

struct QSOListView: View {
    let records: [QSORecord]
    var onSelect: ((Int) -> Void)? = nil
    var onEdit: ((Int) -> Void)? = nil
    /// true のとき右クリメニュー（Edit / Delete）を表示
    var showContextMenu: Bool = false

    @State private var showDeleteConfirmation = false
    @State private var deleteTargetRecord: QSORecord? = nil

    var body: some View {
        VStack(spacing: 0) {
            // カラムヘッダー
            columnHeader

            // ログ行（最下部にスクロール）
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            rowView(record: record, index: index)
                        }
                    }
                }
                .onChange(of: records.count) {
                    if let lastID = records.last?.id {
                        proxy.scrollTo(lastID, anchor: .bottom)
                    }
                }
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        if let lastID = records.last?.id {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .alert("Delete QSO", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let record = deleteTargetRecord {
                    Task {
                        await performDelete(record)
                    }
                }
            }
        } message: {
            if let record = deleteTargetRecord {
                Text("Delete QSO with \(record.callsign) on \(record.date) \(record.time)?")
            }
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func rowView(record: QSORecord, index: Int) -> some View {
        let row = QSORowView(record: record, displayNo: index + 1, isEven: index % 2 == 0)
            .id(record.id)
            .onTapGesture(count: 2) {
                onSelect?(record.id)
            }

        if showContextMenu {
            row.contextMenu {
                Button {
                    onEdit?(record.id)
                } label: {
                    Label("Edit QSO", systemImage: "pencil")
                }

                Divider()

                Button(role: .destructive) {
                    deleteTargetRecord = record
                    showDeleteConfirmation = true
                } label: {
                    Label("Delete QSO", systemImage: "trash")
                }
            }
        } else {
            row
        }
    }

    // MARK: - Delete

    private func performDelete(_ record: QSORecord) async {
        print("[DELETE] id=\(record.id) callsign=\(record.callsign)")
        do {
            let api = LogbookAPI()
            try await api.deleteQSO(id: record.id)
            NotificationCenter.default.post(name: .qsoUpdated, object: nil)
        } catch {
            print("[DELETE] Failed: \(error)")
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerLabel("NO", width: 45)
            headerLabel("CALL", width: 120)
            headerLabel("DATE", width: 80)
            headerLabel("TIME", width: 70)
            headerLabel("HIS", width: 32)
            headerLabel("MY", width: 32)
            headerLabel("FREQ", width: 65)
            headerLabel("MODE", width: 50)
            headerLabel("CODE", width: 75)
            headerLabel("QSL", width: 42)
            headerLabel("NAME", width: 120)
            headerLabel("QTH", width: 150)
            headerLabel("REM1", width: 120)
            headerLabel("REM2", width: nil)
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(hex: "#0d0d10"))
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(CW.border),
            alignment: .bottom
        )
    }

    private func headerLabel(_ text: String, width: CGFloat?) -> some View {
        Text(text)
            .font(.system(size: 9, design: .monospaced))
            .tracking(3)
            .foregroundColor(CW.textDim)
            .frame(width: width, alignment: .leading)
    }
}
