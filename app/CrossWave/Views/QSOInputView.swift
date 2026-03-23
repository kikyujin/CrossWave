//
//  QSOInputView.swift
//  CrossWave
//
//  QSO入力ダイアログ

import SwiftUI
import Combine

struct QSOInputView: View {
    var boardMode: QSOBoardMode = .new
    let onClose: () -> Void
    var onTitleChange: ((String) -> Void)? = nil
    var onOpenLog: ((LogBoardContext) -> NSPanel?)? = nil
    var onActivate: (() -> Void)? = nil
    var onCheckPinned: ((NSPanel) -> Bool)? = nil

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

    // ボード識別子（複数QSOボード同時起動時の通知ルーティング用）
    @State private var boardId = UUID()

    // 子ボード参照（クローズ時に一緒に閉じる）
    @State private var childPanels: [NSPanel] = []

    // NOWボタンで時刻を手動更新したか
    @State private var didUpdateDateTime = false

    // 編集モード: ロード時の元データ（変更検知用）
    @State private var originalRecord: QSORecord? = nil

    // パイルアップモード: CALLSIGNだけでSave可能
    private var canSave: Bool {
        !callsign.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasChanges: Bool {
        if let orig = originalRecord {
            // 編集モード: 元データと比較
            return callsign != orig.callsign ||
                dateDisplay != orig.date ||
                (timeDisplay + timeZone) != orig.time ||
                freq != orig.freq || mode != orig.mode ||
                hisRst != orig.hisRst || myRst != orig.myRst ||
                code != orig.code || qsl != orig.qslStatus ||
                name != orig.name || qth != orig.qth ||
                rem1 != orig.remarks1 || rem2 != orig.remarks2
        }
        // 新規モード: 何か入力があるか
        return !callsign.isEmpty || !name.isEmpty || !qth.isEmpty ||
            !rem1.isEmpty || !rem2.isEmpty || !code.isEmpty ||
            didUpdateDateTime
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

                    // NOWボタン: DATE/TIMEを現在時刻で更新
                    VStack(alignment: .leading, spacing: 4) {
                        Text(" ")
                            .font(.system(size: 9, design: .monospaced))
                        Button {
                            applyCurrentDateTime()
                            didUpdateDateTime = true
                        } label: {
                            Text("NOW")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .tracking(1)
                                .foregroundColor(CW.green)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 7)
                                .background(fieldBg)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2)
                                        .stroke(CW.green.opacity(0.4), lineWidth: 1)
                                )
                                .cornerRadius(2)
                        }
                        .buttonStyle(.plain)
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
                                hisRst = hisRst.toHalfWidth()
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
                                myRst = myRst.toHalfWidth()
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
            if case .edit(let id) = boardMode {
                Task { await loadRecord(id: id) }
            } else {
                setInitialDateTime()
            }
            focusedField = .callsign
        }
        .onExitCommand {
            if hasChanges {
                showDiscardAlert = true
            } else {
                closeWithChildren()
            }
        }
        .alert("入力を破棄しますか？", isPresented: $showDiscardAlert) {
            Button("破棄", role: .destructive) { closeWithChildren() }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("入力中のデータは保存されません。")
        }
        .onReceive(NotificationCenter.default.publisher(for: .qsoInject)) { notification in
            guard let targetId = notification.userInfo?["targetBoardId"] as? UUID,
                  targetId == boardId,
                  let id = notification.userInfo?["id"] as? Int else { return }
            Task {
                let api = LogbookAPI()
                if let record = try? await api.fetchQSO(id: id) {
                    injectFromRecord(record)
                    // 注入後、QSOボードを前面に
                    onActivate?()
                }
            }
        }
    }

    // MARK: - Enter Handler

    private func handleEnter() {
        switch focusedField {
        case .callsign:
            // CALLSIGNが空でなければフィルタ付きログボードを開く + HAMLOG lookup
            let trimmed = callsign.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty {
                openLogForCallsign(trimmed)
                // HAMLOG lookup（非同期、UIブロックなし）
                performLookup(trimmed)
            }

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
            Text(boardMode.isNew ? "NEW QSO" : "EDIT QSO")
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .tracking(4)
                .foregroundColor(CW.amber)

            Spacer()

            Text(currentTime)
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(CW.green)
                .tracking(2)

            Button { closeWithChildren() } label: {
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
                Text(isSaving ? "SAVING..." : (boardMode.isNew ? "SAVE QSO" : "UPDATE QSO"))
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

            Button {
                if hasChanges {
                    showDiscardAlert = true
                } else {
                    closeWithChildren()
                }
            } label: {
                Text("CANCEL")
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
            switch boardMode {
            case .new:
                _ = try await api.createQSO(buildInput())
            case .edit(let id):
                print("[EDIT] PUT id=\(id)")
                _ = try await api.updateQSO(id: id, input: buildInput())
                print("[EDIT] PUT success for id=\(id)")
            }
            NotificationCenter.default.post(name: .qsoUpdated, object: nil)
            closeWithChildren()
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
        applyCurrentDateTime(forceJST: true)
    }

    private func applyCurrentDateTime(forceJST: Bool = false) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let tzId = forceJST ? "Asia/Tokyo" : (timeZone == "J" ? "Asia/Tokyo" : "UTC")
        let tz = TimeZone(identifier: tzId)!
        let comps = cal.dateComponents(in: tz, from: now)
        let yy = String(format: "%02d", (comps.year ?? 2026) % 100)
        let mm = String(format: "%02d", comps.month ?? 1)
        let dd = String(format: "%02d", comps.day ?? 1)
        let hh = String(format: "%02d", comps.hour ?? 0)
        let mi = String(format: "%02d", comps.minute ?? 0)
        dateDisplay = "\(yy)/\(mm)/\(dd)"
        timeDisplay = "\(hh):\(mi)"
        if forceJST { timeZone = "J" }
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
        didUpdateDateTime = false
        setInitialDateTime()
        focusedField = .callsign
    }

    // MARK: - Close

    private func closeWithChildren() {
        for panel in childPanels {
            if onCheckPinned?(panel) == true {
                // ピン留めパネルは閉じずに残す（親はコントローラ側で付け替え）
                continue
            }
            panel.close()
        }
        childPanels.removeAll()
        onClose()
    }

    // MARK: - Board Context / Inject

    private func openLogForCallsign(_ cs: String) {
        let myBoardId = boardId
        let context = LogBoardContext(
            callsignFilter: cs,
            onSelect: { id in
                NotificationCenter.default.post(
                    name: .qsoInject,
                    object: nil,
                    userInfo: ["id": id, "targetBoardId": myBoardId]
                )
            }
        )
        if let panel = onOpenLog?(context) {
            childPanels.append(panel)
            // ログボードの後ろにならないよう、QSOボードを前面に戻す
            onActivate?()
        }
    }

    /// 編集モード: レコードを全フィールドロード
    private func loadRecord(id: Int) async {
        print("[EDIT] Opening edit mode for id=\(id)")
        let api = LogbookAPI()
        guard let record = try? await api.fetchQSO(id: id) else {
            saveError = "Failed to load record"
            return
        }
        callsign = record.callsign
        code = record.code
        name = record.name
        qth = record.qth
        rem1 = record.remarks1
        rem2 = record.remarks2
        freq = record.freq
        mode = record.mode
        hisRst = record.hisRst
        myRst = record.myRst
        qsl = record.qslStatus

        // DATE/TIME: "26/03/23" / "08:57J" → display="08:57", tz="J"
        dateDisplay = record.date
        let t = record.time
        if t.hasSuffix("J") || t.hasSuffix("U") {
            timeDisplay = String(t.dropLast())
            timeZone = String(t.last!)
        } else {
            timeDisplay = t
        }

        // 変更検知用に元データを保持
        originalRecord = record

        // タイトル更新
        let title = "QSO: \(record.callsign)"
        onTitleChange?(title)
    }

    /// 注入: 空でないフィールドだけ上書き
    private func injectFromRecord(_ record: QSORecord) {
        if !record.callsign.isEmpty { callsign = record.callsign }
        if !record.code.isEmpty { code = record.code }
        if !record.name.isEmpty { name = record.name }
        if !record.qth.isEmpty { qth = record.qth }
        if !record.remarks1.isEmpty { rem1 = record.remarks1 }
        if !record.remarks2.isEmpty { rem2 = record.remarks2 }
    }

    // MARK: - HAMLOG Lookup

    private func performLookup(_ cs: String) {
        Task {
            let api = LogbookAPI()
            guard let result = await api.lookupCallsign(cs) else {
                print("[HAMLOG lookup] \(cs) → no response")
                return
            }
            print("[HAMLOG lookup] \(cs) → source: \(result.source)")
            guard result.source == "hamlog" || result.source == "cache" else { return }
            // 注入ルール: 空でなければ上書き、空なら既存値を残す
            if let n = result.name, !n.isEmpty { name = n }
            if let q = result.qth, !q.isEmpty { qth = q }
            if let c = result.code, !c.isEmpty { code = c }
        }
    }
}
