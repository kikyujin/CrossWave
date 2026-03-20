//
//  QSOListView.swift
//  CrossWave
//

import SwiftUI

struct QSOListView: View {
    let records: [QSORecord]
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // カラムヘッダー
            columnHeader

            // ログ行（最下部にスクロール）
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                            QSORowView(record: record, displayNo: index + 1, isEven: index % 2 == 0)
                                .id(record.id)
                                .onTapGesture(count: 2) {
                                    onSelect?(record.id)
                                }
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
