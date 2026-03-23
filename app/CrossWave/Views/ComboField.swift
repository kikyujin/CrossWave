//
//  ComboField.swift
//  CrossWave
//
//  FREQ / MODE 用のComboBox風コンポーネント
//  プリセット選択 + 自由入力

import SwiftUI

struct ComboField: View {
    let label: String
    @Binding var text: String
    let presets: [String]
    let width: CGFloat
    var uppercase: Bool = false
    var onSubmit: (() -> Void)? = nil

    @State private var showingPopover = false
    @FocusState private var isFocused: Bool

    private let fieldBg = Color(hex: "#0d0d18")
    private let fieldBorder = Color(hex: "#2a2a44")

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .tracking(3)
                .foregroundColor(CW.textDim)
                .textCase(.uppercase)

            HStack(spacing: 0) {
                TextField("", text: $text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(CW.textPrim)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit { onSubmit?() }
                    .onChange(of: text) {
                        let half = text.toHalfWidth()
                        text = uppercase ? half.uppercased() : half
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 7)

                Button {
                    showingPopover.toggle()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9))
                        .foregroundColor(CW.textDim)
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingPopover, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(presets, id: \.self) { preset in
                            Button {
                                text = preset
                                showingPopover = false
                            } label: {
                                Text(preset)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(text == preset ? CW.amber : CW.textPrim)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(text == preset ? CW.amber.opacity(0.08) : Color.clear)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(width: width)
                    .background(Color(hex: "#1a1a2e"))
                }
            }
            .frame(width: width)
            .background(fieldBg)
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .stroke(isFocused ? CW.amber : fieldBorder, lineWidth: 1)
            )
            .shadow(color: isFocused ? CW.amber.opacity(0.12) : .clear, radius: 4)
            .cornerRadius(2)
        }
    }
}
