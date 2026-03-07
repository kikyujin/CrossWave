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

    @discardableResult
    func open(content: some View, title: String = "NEW QSO", width: CGFloat = 820, height: CGFloat = 420) -> NSPanel {
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
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        guard let closedPanel = notification.object as? NSPanel else { return }
        NSApp.removeWindowsItem(closedPanel)
        panels.removeAll { $0 === closedPanel }
    }

    func close(_ panel: NSPanel) {
        NSApp.removeWindowsItem(panel)
        panel.close()
        panels.removeAll { $0 === panel }
    }

    func closeAll() {
        panels.forEach { $0.close() }
        panels.removeAll()
    }
}

@MainActor
class FloatingPanelControllerWrapper: ObservableObject {
    let controller = FloatingPanelController()
    private var qsoCount = 0

    func openNew() {
        qsoCount += 1
        let title = qsoCount == 1 ? "NEW QSO" : "NEW QSO (\(qsoCount))"

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
            }
        ), title: title)
        panelRef = panel
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
    func openPanel(content: some View, title: String, width: CGFloat = 820, height: CGFloat = 420) -> NSPanel {
        var panelRef: NSPanel?
        let panel = controller.open(content: content, title: title, width: width, height: height)
        panelRef = panel
        _ = panelRef  // suppress warning
        return panel
    }
}
