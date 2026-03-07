//
//  StatsBarView.swift
//  CrossWave
//

import SwiftUI

struct StatsBarView: View {
    let records: [QSORecord]
    let total: Int

    private var latestDate: String {
        records.last?.date ?? "--"
    }

    private var latestTime: String {
        records.last?.time ?? "--:--"
    }

    private var latestCall: String {
        records.last?.callsign ?? "--"
    }

    private var topBand: String {
        guard !records.isEmpty else { return "--" }
        let counts = Dictionary(grouping: records, by: \.freq)
        return counts.max(by: { $0.value.count < $1.value.count })?.key ?? "--"
    }

    private var qslPending: Int {
        records.filter { $0.qslStatus == "N" }.count
    }

    var body: some View {
        HStack(spacing: 0) {
            statItem(label: "TOTAL QSO",   value: "\(total)",    sub: "ALL TIME")
            separator()
            statItem(label: "LATEST DATE", value: latestDate,    sub: "YY/MM/DD")
            separator()
            statItem(label: "BAND",        value: topBand,       sub: "MHz")
            separator()
            statItem(label: "LAST QSO",    value: latestTime,    sub: latestCall)
            separator()
            statItem(label: "QSL PENDING", value: "\(qslPending)", sub: "UNCONFIRMED",
                     valueColor: qslPending > 0 ? CW.red : CW.amber)
        }
        .fixedSize(horizontal: false, vertical: true)  // ← 高さを内容に合わせる
        .background(CW.panel)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(CW.border),
            alignment: .bottom
        )
    }

    private func separator() -> some View {
        Rectangle()
            .fill(CW.border)
            .frame(width: 1)
            .padding(.vertical, 8)  // ← Divider()だと親に高さを合わせるので Rectangle に変更
    }

    private func statItem(label: String, value: String, sub: String, valueColor: Color = CW.amber) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .tracking(3)
                .foregroundColor(CW.textDim)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .monospaced))
                    .foregroundColor(valueColor)
                    .tracking(1)
                Text(sub)
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1)
                    .foregroundColor(CW.textMid)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
