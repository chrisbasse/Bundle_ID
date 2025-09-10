// ===== FICHIER: ContentView.swift =====
// VERSION COMPATIBLE macOS 11+

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var bundleID: String = ""
    @State private var appName: String = ""
    @State private var appVersion: String = ""
    @State private var isDragging: Bool = false
    @State private var showingFilePicker: Bool = false
    @State private var errorMessage: String = ""
    @State private var showingCopiedAlert: Bool = false
    
    var body: some View {
        VStack(spacing: 20) {
            // En-tête
            VStack(spacing: 8) {
                if let appIcon = NSApplication.shared.applicationIconImage {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 48, height: 48)
                } else {
                    // Fallback au cas où l'icône ne serait pas disponible
                    Image(systemName: "app.badge")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                }
                
                Text("app_title".localized)
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("drag_instruction".localized)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Zone de drop - Compatible macOS 11+
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDragging ? Color.blue : Color.gray.opacity(0.5),
                    style: StrokeStyle(
                        lineWidth: 2,
                        dash: isDragging ? [] : [10]
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(isDragging ? Color.blue.opacity(0.1) : Color.clear)
                )
                .frame(width: 400, height: 150)
                .overlay(
                    VStack(spacing: 12) {
                        Image(systemName: isDragging ? "arrow.down.circle.fill" : "plus.circle.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(isDragging ? .blue : .gray)
                        
                        Text(isDragging ? "drop_to_analyze".localized : "drag_app_here".localized)
                            .font(.headline)
                            .foregroundColor(isDragging ? .blue : .gray)
                    }
                )
                .onDrop(of: [UTType.fileURL], isTargeted: $isDragging) { providers in
                    handleDrop(providers: providers)
                }
            
            // Bouton de sélection de fichier - Compatible macOS 11+
            Button(action: {
                showingFilePicker = true
            }) {
                HStack {
                    Image(systemName: "folder.badge.plus")
                    Text("select_application".localized)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
            }
            .buttonStyle(BorderedButtonStyle()) // Compatible macOS 11
            
            Divider()
                .padding(.horizontal)
            
            // Affichage des résultats
            if !bundleID.isEmpty {
                VStack(spacing: 16) {
                    // Informations de l'application
                    VStack(alignment: .leading, spacing: 8) {
                        if !appName.isEmpty {
                            HStack {
                                Text("application_label".localized)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(appName)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if !appVersion.isEmpty {
                            HStack {
                                Text("version_label".localized)
                                    .fontWeight(.medium)
                                Spacer()
                                Text(appVersion)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // Bundle ID avec bouton de copie
                    VStack(alignment: .leading, spacing: 8) {
                        Text("bundle_id_label".localized)
                            .font(.headline)
                        
                        HStack {
                            // Zone de texte sélectionnable - Compatible macOS 11+
                            if #available(macOS 12.0, *) {
                                Text(bundleID)
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                    .font(.system(.body, design: .monospaced))
                            } else {
                                // Fallback pour macOS 11
                                Text(bundleID)
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(6)
                                    .font(.system(.body, design: .monospaced))
                                    .onTapGesture {
                                        copyBundleID()
                                    }
                                    .help("copy_bundle_id".localized)
                            }
                            
                            Button(action: copyBundleID) {
                                Image(systemName: showingCopiedAlert ? "checkmark" : "doc.on.clipboard")
                                    .foregroundColor(showingCopiedAlert ? .green : .blue)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .help("copy_bundle_id".localized)
                        }
                    }
                    .padding(.horizontal)
                    
                    // Message de confirmation de copie
                    if showingCopiedAlert {
                        Text("copied_to_clipboard".localized)
                            .font(.caption)
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            // Message d'erreur
            if !errorMessage.isEmpty {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 600)
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.applicationBundle],
            allowsMultipleSelection: false
        ) { result in
            handleFileSelection(result: result)
        }
    }
    
    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        
        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
            DispatchQueue.main.async {
                if let data = item as? Data,
                   let url = URL(dataRepresentation: data, relativeTo: nil) {
                    analyzeApplication(at: url)
                }
            }
        }
        return true
    }
    
    private func handleFileSelection(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                analyzeApplication(at: url)
            }
        case .failure(let error):
            DispatchQueue.main.async {
                self.errorMessage = String(format: "selection_error".localized, error.localizedDescription)
            }
        }
    }
    
    private func analyzeApplication(at url: URL) {
        clearResults()
        
        // Vérifier que c'est bien une application
        guard url.pathExtension == "app" else {
            errorMessage = "not_an_app_error".localized
            return
        }
        
        // Chemin vers Info.plist
        let infoPlistURL = url.appendingPathComponent("Contents/Info.plist")
        
        guard FileManager.default.fileExists(atPath: infoPlistURL.path) else {
            errorMessage = "info_plist_not_found".localized
            return
        }
        
        // Lire le Info.plist
        do {
            let data = try Data(contentsOf: infoPlistURL)
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                
                // Extraire les informations
                if let bundleIdentifier = plist["CFBundleIdentifier"] as? String {
                    bundleID = bundleIdentifier
                } else {
                    errorMessage = "bundle_id_not_found".localized
                    return
                }
                
                if let displayName = plist["CFBundleDisplayName"] as? String {
                    appName = displayName
                } else if let name = plist["CFBundleName"] as? String {
                    appName = name
                } else {
                    appName = url.deletingPathExtension().lastPathComponent
                }
                
                if let version = plist["CFBundleShortVersionString"] as? String {
                    appVersion = version
                } else if let version = plist["CFBundleVersion"] as? String {
                    appVersion = version
                }
                
                errorMessage = ""
                
            } else {
                errorMessage = "cannot_read_plist".localized
            }
        } catch {
            errorMessage = String(format: "plist_read_error".localized, error.localizedDescription)
        }
    }
    
    private func clearResults() {
        bundleID = ""
        appName = ""
        appVersion = ""
        errorMessage = ""
        showingCopiedAlert = false
    }
    
    private func copyBundleID() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(bundleID, forType: .string)
        
        // Animation compatible macOS 11+
        if #available(macOS 12.0, *) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingCopiedAlert = true
            }
        } else {
            showingCopiedAlert = true
        }
        
        // Réinitialiser l'indicateur après 2 secondes
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if #available(macOS 12.0, *) {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingCopiedAlert = false
                }
            } else {
                showingCopiedAlert = false
            }
        }
    }
}

#Preview {
    ContentView()
}
