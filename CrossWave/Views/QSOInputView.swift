//
//  QSOInputView.swift
//  CrossWave
//
//  QSO入力ダイアログ

import SwiftUI
import Combine

struct QSOInputView: View {
    let onClose: () -> Void
    var onTitleChange: ((String) -> Void)? = nil

    // フィールド
    @State private var callsign = ""
    @State private var dateDisplay = ""
    @State private var timeDisplay = ""
    @State private var timeZone = "J"
    @State private var freq = "430"
    @State private var mode = "FM"
    @State private var hisRst = "59"
    @State private var myRst = "59"
    @State private var code = ""
    @State private var qsl = "J"
    @State private var name = ""
    @State private var qth = ""
    @State private var rem1 = ""
    @State private var rem2 = ""

    // 時計
    @State private var currentTime = ""
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // コールサイン補完
    @State private var candidates: [CallsignCandidate] = []
    @State private var showCandidates = false
    @State private var searchTask: Task<Void, Never>?
    @State private var suppressSearch = false

    // 保存処理
    @State private var isSaving = false
    @State private var saveError: String?

    // Esc確認ダイアログ
    @State private var showDiscardAlert = false

    // プリセット
    private let freqPresets = ["144", "430", "1200", "50", "28", "21", "14", "7", "3.5", "1.9"]
    private let modePresets = ["FM", "SSB", "CW", "AM", "FT8", "FT4", "RTTY", "SSTV"]

    // カラー
    private let dialogBg = Color(hex: "#1a1a2e")
    private let headerBg = Color(hex: "#161628")
    private let dialogBorder = Color(hex: "#3a3a5c")
    private let fieldBg = Color(hex: "#0d0d18")
    private let fieldBorder = Color(hex: "#2a2a44")

    // フォーカス管理
    @FocusState private var focusedField: InputField?
    enum InputField: Hashable {
        case callsign, date, time, freq, mode, hisRst, myRst, code, qsl, name, qth, rem1, rem2
    }

    // 再入防止
    @State private var isFormattingDate = false
    @State private var isFormattingTime = false

    // パイルアップモード: CALLSIGNだけでSave可能
    private var canSave: Bool {
        !callsign.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        !callsign.isEmpty || !name.isEmpty || !qth.isEmpty ||
        !rem1.isEmpty || !rem2.isEmpty || !code.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 12) {
                // 行1: CALLSIGN / DATE / TIME / FREQ / MODE
                HStack(alignment: .top, spacing: 10) {
                    fieldGroup(label: "CALLSIGN", width: 180) {
                        TextField("JS2OIA", text: $callsign)
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundColor(CW.amber)
                            .focused($focusedField, equals: .callsign)
                            .onSubmit { handleEnter() }
                            .onChange(of: callsign) {
                                callsign = callsign.toHalfWidth().uppercased()
                                let title = callsign.isEmpty ? "NEW QSO" : "QSO: \(callsign)"
                                onTitleChange?(title)
                                triggerCallsignSearch()
                            }
                            .popover(isPresented: $showCandidates, arrowEdge: .bottom) {
                                candidateList
                            }
                    }

                    fieldGroup(label: "DATE", width: 100) {
                        TextField("26/03/07", text: $dateDisplay)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .focused($focusedField, equals: .date)
                            .onSubmit { handleEnter() }
                            .onChange(of: dateDisplay) { formatDate() }
                    }

                    fieldGroup(label: "TIME", width: 85) {
                        HStack(spacing: 4) {
                            TextField("08:57", text: $timeDisplay)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundColor(CW.textPrim)
                                .focused($focusedField, equals: .time)
                                .onSubmit { handleEnter() }
                                .onChange(of: timeDisplay) { formatTime() }

                            Button(timeZone) {
                                timeZone = timeZone == "J" ? "U" : "J"
                            }
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(timeZone == "J" ? CW.amber : CW.blue)
                            .frame(width: 22, height: 28)
                            .background(fieldBg)
                            .overlay(RoundedRectangle(cornerRadius: 2).stroke(CW.border))
                            .buttonStyle(.plain)
                        }
                    }

                    ComboField(label: "FREQ", text: $freq, presets: freqPresets, width: 110) {
                        focusedField = .mode
                    }

                    ComboField(label: "MODE", text: $mode, presets: modePresets, width: 100, uppercase: true) {
                        focusedField = .hisRst
                    }

                    Spacer()
                }

                // 行2: HIS / MY / CODE / QSL
                HStack(alignment: .top, spacing: 10) {
                    fieldGroup(label: "HIS", width: 60) {
                        TextField("59", text: $hisRst)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.green)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .hisRst)
                            .onSubmit { handleEnter() }
                            .onChange(of: hisRst) {
                                hisRst = String(hisRst.toHalfWidth().filter(\.isNumber).prefix(3))
                            }
                    }

                    fieldGroup(label: "MY", width: 60) {
                        TextField("59", text: $myRst)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.green)
                            .multilineTextAlignment(.center)
                            .focused($focusedField, equals: .myRst)
                            .onSubmit { handleEnter() }
                            .onChange(of: myRst) {
                                myRst = String(myRst.toHalfWidth().filter(\.isNumber).prefix(3))
                            }
                    }

                    fieldGroup(label: "JCC/JCG", width: 100) {
                        TextField("2034", text: $code)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .focused($focusedField, equals: .code)
                            .onSubmit { handleEnter() }
                            .onChange(of: code) {
                                code = code.toHalfWidth()
                            }
                    }

                    fieldGroup(label: "QSL", width: 70) {
                        TextField("J", text: $qsl)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .focused($focusedField, equals: .qsl)
                            .onSubmit { handleEnter() }
                            .onChange(of: qsl) {
                                qsl = qsl.toHalfWidth().uppercased()
                            }
                    }

                    Spacer()
                }

                // 行3: NAME / QTH
                HStack(alignment: .top, spacing: 10) {
                    fieldGroup(label: "NAME") {
                        TextField("氏名", text: $name)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .focused($focusedField, equals: .name)
                            .onSubmit { handleEnter() }
                    }
                    fieldGroup(label: "QTH") {
                        TextField("QTH", text: $qth)
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .focused($focusedField, equals: .qth)
                            .onSubmit { handleEnter() }
                    }
                }

                // 行4: REM1
                fieldGroup(label: "REMARKS 1") {
                    TextField("Remarks 1", text: $rem1)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(CW.textPrim)
                        .focused($focusedField, equals: .rem1)
                        .onSubmit { handleEnter() }
                }

                // 行5: REM2
                fieldGroup(label: "REMARKS 2") {
                    TextField("%愛知県弥富市 %Rig#46", text: $rem2)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(CW.textPrim)
                        .focused($focusedField, equals: .rem2)
                        .onSubmit { handleEnter() }
                }
            }
            .padding(20)

            actionBar
        }
        .frame(width: 820)
        .background(dialogBg)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(dialogBorder, lineWidth: 1)
        )
        .overlay(
            Rectangle().frame(height: 2).foregroundColor(CW.amber),
            alignment: .top
        )
        .cornerRadius(4)
        .onReceive(timer) { _ in updateClock() }
        .onAppear {
            guard dateDisplay.isEmpty else { return }
            updateClock()
            setInitialDateTime()
            focusedField = .callsign
        }
        .onExitCommand {
            if hasChanges {
                showDiscardAlert = true
            } else {
                onClose()
            }
        }
        .alert("入力を破棄しますか？", isPresented: $showDiscardAlert) {
            Button("破棄", role: .destructive) { onClose() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力中のデータは保存されません。")
        }
    }

    // MARK: - Enter Handler

    private func handleEnter() {
        switch focusedField {
        case .callsign:
            // 補完候補があれば先頭を確定
            if showCandidates, let first = candidates.first {
                suppressSearch = true
                callsign = first.callsign
                if !first.name.isEmpty { name = first.name }
                if !first.qth.isEmpty { qth = first.qth }
                if !first.code.isEmpty { code = first.code }
                showCandidates = false
            }
            searchTask?.cancel()
            showCandidates = false
            focusedField = .date

        case .date:    focusedField = .time
        case .time:    focusedField = .freq
        case .freq:    focusedField = .mode
        case .mode:    focusedField = .hisRst
        case .hisRst:  focusedField = .myRst
        case .myRst:   focusedField = .code
        case .code:    focusedField = .qsl
        case .qsl:     focusedField = .name
        case .name:    focusedField = .qth
        case .qth:     focusedField = .rem1
        case .rem1:    focusedField = .rem2

        case .rem2:
            // 最終フィールド → SAVE
            if canSave {
                Task { await saveQSO() }
            }

        case nil:
            break
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("NEW QSO")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundColor(CW.amber)

            Spacer()

            Text(currentTime)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.green)
                .tracking(2)

            Button { onClose() } label: {
                Text("✕")
                    .foregroundColor(CW.textDim)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(headerBg)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(CW.border),
            alignment: .bottom
        )
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack {
            Button {
                Task { await saveQSO() }
            } label: {
                Text(isSaving ? "SAVING..." : "SAVE QSO")
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundColor(.black)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 9)
                    .background(CW.amber)
                    .cornerRadius(2)
            }
            .buttonStyle(.plain)
            .disabled(!canSave || isSaving)
            .opacity(canSave && !isSaving ? 1.0 : 0.4)
            .keyboardShortcut(.return, modifiers: .command)

            Button { clearForm() } label: {
                Text("CLEAR")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(2)
                    .foregroundColor(CW.textMid)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(CW.border))
            }
            .buttonStyle(.plain)

            Spacer()

            if let err = saveError {
                Text(err)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(CW.red)
                    .lineLimit(1)
            }

            Text("⌘Enter → Save  ·  Enter → 次  ·  Esc → キャンセル")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(CW.textDim)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(headerBg)
        .overlay(
            Rectangle().frame(height: 1).foregroundColor(CW.border),
            alignment: .top
        )
    }

    // MARK: - Field Group

    @ViewBuilder
    private func fieldGroup<Content: View>(
        label: String,
        width: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .tracking(3)
                .foregroundColor(CW.textDim)
                .textCase(.uppercase)

            content()
                .textFieldStyle(.plain)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(width: width)
                .background(fieldBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(fieldBorder, lineWidth: 1)
                )
                .cornerRadius(2)
        }
    }

    // MARK: - Date/Time Formatting

    private func formatDate() {
        guard !isFormattingDate else { return }
        isFormattingDate = true
        defer { isFormattingDate = false }

        let half = dateDisplay.toHalfWidth()
        let digits = half.filter { $0.isNumber }
        let capped = String(digits.prefix(6))

        switch capped.count {
        case 0...2:
            dateDisplay = capped
        case 3...4:
            dateDisplay = capped.prefix(2) + "/" + capped.dropFirst(2)
        case 5...6:
            let yy = capped.prefix(2)
            let mm = capped.dropFirst(2).prefix(2)
            let dd = capped.dropFirst(4).prefix(2)
            dateDisplay = "\(yy)/\(mm)/\(dd)"
        default:
            break
        }
    }

    private func formatTime() {
        guard !isFormattingTime else { return }
        isFormattingTime = true
        defer { isFormattingTime = false }

        let half = timeDisplay.toHalfWidth()
        let digits = half.filter { $0.isNumber }
        let capped = String(digits.prefix(4))

        switch capped.count {
        case 0...2:
            timeDisplay = capped
        case 3...4:
            let hh = capped.prefix(2)
            let mm = capped.dropFirst(2).prefix(2)
            timeDisplay = "\(hh):\(mm)"
        default:
            break
        }
    }

    // MARK: - Callsign Completion

    private var candidateList: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(candidates) { c in
                Button {
                    suppressSearch = true
                    callsign = c.callsign
                    if !c.name.isEmpty { name = c.name }
                    if !c.qth.isEmpty { qth = c.qth }
                    if !c.code.isEmpty { code = c.code }
                    showCandidates = false
                    focusedField = .date
                } label: {
                    HStack(spacing: 8) {
                        Text(c.callsign)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(CW.amber)
                            .frame(width: 100, alignment: .leading)
                        Text(c.name)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CW.textPrim)
                            .frame(width: 80, alignment: .leading)
                            .lineLimit(1)
                        Text(c.qth)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(CW.textDim)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.clear)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
        .frame(width: 360)
        .background(Color(hex: "#1a1a2e"))
    }

    private func triggerCallsignSearch() {
        if suppressSearch {
            suppressSearch = false
            return
        }

        searchTask?.cancel()

        let query = callsign.trimmingCharacters(in: .whitespaces)
        guard query.count >= 2 else {
            candidates = []
            showCandidates = false
            return
        }

        searchTask = Task {
            // デバウンス: 200ms待ってから検索
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }

            let api = LogbookAPI()
            let results = await api.searchCallsign(prefix: query)
            guard !Task.isCancelled else { return }

            candidates = results
            showCandidates = !results.isEmpty
        }
    }

    // MARK: - Save

    private func buildInput() -> QSOInput {
        // TIME に timezone suffix を付与（"08:57" + "J" → "08:57J"）
        let timeValue = timeDisplay + timeZone

        return QSOInput(
            callsign: callsign.trimmingCharacters(in: .whitespaces),
            date: dateDisplay,
            time: timeValue,
            freq: freq,
            mode: mode,
            hisRst: hisRst,
            myRst: myRst,
            code: code,
            qslStatus: qsl,
            name: name,
            qth: qth,
            remarks1: rem1,
            remarks2: rem2
        )
    }

    private func saveQSO() async {
        isSaving = true
        saveError = nil

        do {
            let api = LogbookAPI()
            _ = try await api.createQSO(buildInput())
            NotificationCenter.default.post(name: .qsoUpdated, object: nil)
            onClose()
        } catch {
            saveError = error.localizedDescription
        }

        isSaving = false
    }

    // MARK: - Helpers

    private func updateClock() {
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        f.timeZone = TimeZone(identifier: "Asia/Tokyo")
        currentTime = f.string(from: now) + "J"
    }

    private func setInitialDateTime() {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone(identifier: "Asia/Tokyo")!
        let comps = cal.dateComponents(in: tz, from: now)
        let yy = String(format: "%02d", (comps.year ?? 2026) % 100)
        let mm = String(format: "%02d", comps.month ?? 1)
        let dd = String(format: "%02d", comps.day ?? 1)
        let hh = String(format: "%02d", comps.hour ?? 0)
        let mi = String(format: "%02d", comps.minute ?? 0)
        dateDisplay = "\(yy)/\(mm)/\(dd)"
        timeDisplay = "\(hh):\(mi)"
        timeZone = "J"
    }

    private func clearForm() {
        callsign = ""
        freq = "430"
        mode = "FM"
        hisRst = "59"
        myRst = "59"
        code = ""
        qsl = "J"
        name = ""
        qth = ""
        rem1 = ""
        rem2 = ""
        setInitialDateTime()
        focusedField = .callsign
    }
}
