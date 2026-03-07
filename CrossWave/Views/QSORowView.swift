//
//  QSORowView.swift
//  CrossWave
//

import SwiftUI

struct QSORowView: View {
    let record: QSORecord
    let displayNo: Int
    let isEven: Bool
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 0) {
            // NO (表示インデックス)
            Text("\(displayNo)")
                .frame(width: 45, alignment: .leading)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(CW.textDim)

            // CALL
            Text(record.callsign)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 14, weight: .bold, design: .monospaced))
                .tracking(2)
                .foregroundColor(isHovered ? CW.amber : CW.amber.opacity(0.85))
                .shadow(color: isHovered ? CW.amber.opacity(0.5) : .clear, radius: 8)

            // DATE
            Text(record.date)
                .frame(width: 80, alignment: .leading)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.textMid)

            // TIME
            Text(record.time)
                .frame(width: 70, alignment: .leading)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.textMid)

            // HIS RST
            Text(record.hisRst)
                .frame(width: 32, alignment: .center)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.green)

            // MY RST
            Text(record.myRst)
                .frame(width: 32, alignment: .center)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.green)

            // FREQ
            Text(record.freq)
                .frame(width: 65, alignment: .leading)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.amber)

            // MODE
            Text(record.mode)
                .frame(width: 50, alignment: .leading)
                .font(.system(size: 11, design: .monospaced))
                .tracking(2)
                .foregroundColor(CW.blue)

            // CODE
            Text(record.code)
                .frame(width: 75, alignment: .leading)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(CW.textMid)

            // QSL (独立バッジ)
            qslBadge
                .frame(width: 42, alignment: .leading)

            // NAME
            Text(record.name)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 12))
                .foregroundColor(CW.textPrim)
                .lineLimit(1)

            // QTH
            Text(record.qth)
                .frame(width: 150, alignment: .leading)
                .font(.system(size: 11))
                .foregroundColor(CW.textMid)
                .lineLimit(1)

            // REM1
            Text(record.remarks1)
                .frame(width: 120, alignment: .leading)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(CW.textDim)
                .lineLimit(1)

            // REM2
            Text(record.remarks2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(CW.textDim)
                .lineLimit(1)
        }
        .padding(.horizontal, 24)
        .frame(height: 40)
        .background(
            isHovered
                ? CW.amber.opacity(0.04)
                : (isEven ? Color.clear : Color.white.opacity(0.01))
        )
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(Color(hex: "#15151a")),
            alignment: .bottom
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }

    @ViewBuilder
    private var qslBadge: some View {
        let status = record.qslStatus
        Text(status)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(1)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(badgeBg(status))
            .foregroundColor(badgeFg(status))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(badgeBorder(status), lineWidth: 1)
            )
            .cornerRadius(2)
    }

    private func badgeBg(_ s: String) -> Color {
        switch s {
        case "J":  return CW.green.opacity(0.15)
        case "JE": return CW.blue.opacity(0.15)
        default:   return CW.textDim.opacity(0.3)
        }
    }

    private func badgeFg(_ s: String) -> Color {
        switch s {
        case "J":  return CW.green
        case "JE": return CW.blue
        default:   return CW.textDim
        }
    }

    private func badgeBorder(_ s: String) -> Color {
        switch s {
        case "J":  return CW.green.opacity(0.3)
        case "JE": return CW.blue.opacity(0.3)
        default:   return CW.border
        }
    }
}
