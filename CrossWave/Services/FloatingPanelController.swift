//
//  FloatingPanelController.swift
//  CrossWave
//
//  NSPanelベースのフローティング入力パネル

import AppKit
import Combine
import SwiftUI

class FloatingPanelController: NSObject, NSWindowDelegate {
    private(set) var panels: [NSPanel] = []
    /// 子パネル → 親ウィンドウのマッピング（NSWindow にして MainWindow も対応）
    private var parentMap: [ObjectIdentifier: NSWindow] = [:]

    @discardableResult
    func open(content: some View, title: String = "NEW QSO", width: CGFloat = 820, height: CGFloat = 420, parent: NSWindow? = nil) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [
                .titled,
                .closable,
                .resizable
            ],
            backing: .buffered,
            defer: false
        )

        panel.title = title
        panel.level = .normal
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.backgroundColor = NSColor(Color(hex: "#1a1a2e"))
        panel.isOpaque = true

        let hostingView = NSHostingView(rootView: content)
        panel.contentView = hostingView

        // メインウィンドウの下部中央に配置
        if let mainWindow = NSApp.mainWindow {
            let mainFrame = mainWindow.frame
            let offset = CGFloat(panels.count) * 24
            let x = mainFrame.midX - width / 2 + offset
            let y = mainFrame.midY - height / 2 - offset
            panel.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        } else {
            panel.center()
        }

        panel.delegate = self
        NSApp.addWindowsItem(panel, title: panel.title, filename: false)
        panel.makeKeyAndOrderFront(nil)
        panels.append(panel)
        if let parent = parent {
            parentMap[ObjectIdentifier(panel)] = parent
        }
        return panel
    }

    // クローズ時の後始末は全てここに統一
    func windowWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel else { return }
        NSApp.removeWindowsItem(closedPanel)
        // 親ウィンドウにフォーカスを戻す
        let key = ObjectIdentifier(closedPanel)
        if let parent = parentMap[key], parent.isVisible {
            parent.makeKeyAndOrderFront(nil)
        }
        parentMap.removeValue(forKey: key)
        panels.removeAll { $0 === closedPanel }
    }

    /// パネルを閉じる（後始末は windowWillClose に委譲）
    func close(_ panel: NSPanel) {
        panel.close()
    }

    func closeAll() {
        let snapshot = panels
        snapshot.forEach { $0.close() }
    }
}

@MainActor
class FloatingPanelControllerWrapper: ObservableObject {
    let controller = FloatingPanelController()
    private var qsoCount = 0

    /// 全パネル一覧
    var allPanels: [NSPanel] { controller.panels }

    /// 全パネルを閉じる
    func closeAll() { controller.closeAll() }

    func openNew() {
        qsoCount += 1
        let title = qsoCount == 1 ? "NEW QSO" : "NEW QSO (\(qsoCount))"

        // 呼び出し元のウィンドウを親にする（NSWindow にして MainWindow も対応）
        let callerWindow = NSApp.keyWindow

        var panelRef: NSPanel?
        let panel = controller.open(content: QSOInputView(
            onClose: { [weak self] in
                if let p = panelRef {
                    self?.controller.close(p)
                }
            },
            onTitleChange: { title in
                if let p = panelRef {
                    p.title = title
                    NSApp.changeWindowsItem(p, title: title, filename: false)
                }
            },
            onOpenLog: { [weak self] context -> NSPanel? in
                self?.openLog(context: context, parent: panelRef)
            },
            onActivate: {
                panelRef?.makeKeyAndOrderFront(nil)
            }
        ), title: title, parent: callerWindow)
        panelRef = panel
    }

    @discardableResult
    func openLog(context: LogBoardContext = .default, parent: NSWindow? = nil) -> NSPanel {
        let title: String
        if let filter = context.callsignFilter {
            title = "LOG: \(filter.uppercased())"
        } else {
            title = "LOG BOARD"
        }
        return openPanel(
            content: ContentView(panelController: self, context: context),
            title: title,
            width: 1200,
            height: 700,
            parent: parent
        )
    }

    func openExport(records: [QSORecord] = []) {
        openPanel(
            content: ExportDialogView(records: records),
            title: "EXPORT CSV",
            width: 420,
            height: 260
        )
    }

    @discardableResult
    func openPanel(content: some View, title: String, width: CGFloat = 820, height: CGFloat = 420, parent: NSWindow? = nil) -> NSPanel {
        let panel = controller.open(content: content, title: title, width: width, height: height, parent: parent)
        return panel
    }
}
