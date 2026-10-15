//
//  Bundle_ID.swift
//  Bundle_ID
//
//  Created by Christophe BASSETTE
//

// ===== FICHIER: Bundle_IDApp.swift =====

import SwiftUI
import AppKit

// Hauteur et largeur fixes de la fenêtre
private let windowSize = NSSize(width: 500, height: 650)

// Classe pour contrôler le comportement de la fenêtre (non redimensionnable)
class WindowDelegate: NSObject, NSWindowDelegate {
    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // Maintenir une taille fixe de 500x650
        return windowSize
    }
    
    func windowDidBecomeMain(_ notification: Notification) {
        if let window = notification.object as? NSWindow {
            // Désactiver le redimensionnement
            window.styleMask.remove(.resizable)
            // Taille correcte
            window.setContentSize(windowSize)
        }
    }
}

@main
struct Bundle_IDApp: App {
    @StateObject private var windowDelegate = WindowDelegateObject()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onReceive(NotificationCenter.default.publisher(for: NSWindow.willCloseNotification)) { notification in
                    // Vérifier que c'est bien la fenêtre principale qui se ferme
                    if let window = notification.object as? NSWindow,
                       window == NSApplication.shared.mainWindow || NSApplication.shared.windows.count <= 1 {
                        // Quitter l'application seulement si c'est la fenêtre principale
                        NSApplication.shared.terminate(nil)
                    }
                }
                .onAppear {
                    setupWindow()
                }
        }
        .windowStyle(DefaultWindowStyle())
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("about_menu".localized) {
                    // Créer les options pour le panneau "À propos" avec icône personnalisée
                    var options: [NSApplication.AboutPanelOptionKey: Any] = [
                        NSApplication.AboutPanelOptionKey.credits: NSAttributedString(
                            string: "bundle_id_finder_credits".localized,
                            attributes: [
                                NSAttributedString.Key.font: NSFont.systemFont(ofSize: 11),
                                NSAttributedString.Key.foregroundColor: NSColor.labelColor
                            ]
                        ),
                        NSApplication.AboutPanelOptionKey.applicationName: "Bundle ID Finder",
                        NSApplication.AboutPanelOptionKey.applicationVersion: "1.0",
                        NSApplication.AboutPanelOptionKey.version: "1.0.0"
                    ]
                    
                    // Ajouter l'icône si elle existe
                    if let appIcon = NSApplication.shared.applicationIconImage {
                        options[NSApplication.AboutPanelOptionKey.applicationIcon] = appIcon
                    }
                    
                    NSApplication.shared.orderFrontStandardAboutPanel(options: options)
                }
            }
        }
    }
    
    private func setupWindow() {
        // Attendre que la fenêtre soit créée
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if let window = NSApplication.shared.windows.first {
                // Configurer la fenêtre pour qu'elle ne soit pas redimensionnable
                window.styleMask.remove(.resizable)
                window.delegate = windowDelegate.delegate
                
                // Définir la taille exacte
                window.setContentSize(windowSize)
                
                // Centrer la fenêtre
                window.center()
                
                // Définir les contraintes de taille min/max
                window.minSize = windowSize
                window.maxSize = windowSize
            }
        }
    }
}

// Wrapper ObservableObject pour le delegate
class WindowDelegateObject: ObservableObject {
    let delegate = WindowDelegate()
}

// Extension pour la localisation
extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
}
