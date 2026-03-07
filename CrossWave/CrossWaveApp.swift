//
//  CrossWaveApp.swift
//  CrossWave
//
//  Created by Mahito KIDA on 2026/03/07.
//

import SwiftUI

@main
struct CrossWaveApp: App {
    @StateObject private var panelController = FloatingPanelControllerWrapper()

    var body: some Scene {
        WindowGroup {
            ControlBoardView(panelController: panelController)
                .frame(minWidth: 400, minHeight: 350)
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 480, height: 400)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New QSO") {
                    panelController.openNew()
                }
                .keyboardShortcut("n", modifiers: .command)
            }

            CommandGroup(after: .windowArrangement) {
                Button("次のウィンドウを前面へ") {
                    let visible = NSApp.windows.filter { $0.isVisible && !$0.isMiniaturized }
                    guard visible.count > 1,
                          let current = visible.firstIndex(where: { $0.isKeyWindow }) else { return }
                    let next = visible[(current + 1) % visible.count]
                    next.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("`", modifiers: .command)
            }
        }
    }
}
