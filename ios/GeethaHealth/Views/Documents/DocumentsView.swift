import SwiftUI
import SwiftData
import PhotosUI
import QuickLook
import UniformTypeIdentifiers

struct DocumentsView: View {
    @Environment(\.modelContext) private var context
    var profile: Profile

    @State private var showingScanner = false
    @State private var showingPhotoPicker = false
    @State private var showingFileImporter = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var previewURL: URL?
    @State private var renaming: MedicalDocument?
    @State private var renameText = ""

    private var documents: [MedicalDocument] {
        profile.documents.sorted { $0.uploadedAt > $1.uploadedAt }
    }

    var body: some View {
        NavigationStack {
            Group {
                if documents.isEmpty {
                    ContentUnavailableView(
                        "No documents yet",
                        systemImage: "doc.on.doc",
                        description: Text("Scan a paper record, or import a photo or PDF.")
                    )
                } else {
                    documentList
                }
            }
            .navigationTitle("Documents")
            .toolbar {
                Menu {
                    if DocumentScannerView.isSupported {
                        Button("Scan document", systemImage: "doc.viewfinder") { showingScanner = true }
                    }
                    Button("Choose photos", systemImage: "photo.on.rectangle") { showingPhotoPicker = true }
                    Button("Import file", systemImage: "folder") { showingFileImporter = true }
                } label: {
                    Label("Add document", systemImage: "plus")
                }
            }
            .fullScreenCover(isPresented: $showingScanner) {
                DocumentScannerView { images in
                    saveScan(images)
                }
                .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $photoItems, maxSelectionCount: 10, matching: .images)
            .onChange(of: photoItems) {
                importPhotos()
            }
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.pdf, .image], allowsMultipleSelection: true) { result in
                importFiles(result)
            }
            .quickLookPreview($previewURL)
            .alert("Rename document", isPresented: Binding(
                get: { renaming != nil },
                set: { if !$0 { renaming = nil } }
            )) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel) { renaming = nil }
                Button("Save") {
                    if let doc = renaming, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                        doc.name = renameText.trimmingCharacters(in: .whitespaces)
                    }
                    renaming = nil
                }
            }
        }
    }

    private var documentList: some View {
        List {
            ForEach(documents) { document in
                Button {
                    previewURL = DocumentFileStore.url(forFileName: document.fileName)
                } label: {
                    HStack(spacing: 12) {
                        DocumentThumbnailView(fileName: document.fileName)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.name)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                            Text(document.uploadedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .contextMenu {
                    Button("Rename", systemImage: "pencil") {
                        renameText = document.name
                        renaming = document
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        delete(document)
                    }
                }
            }
            .onDelete { offsets in
                for offset in offsets { delete(documents[offset]) }
            }
        }
    }

    private func delete(_ document: MedicalDocument) {
        DocumentFileStore.delete(fileName: document.fileName)
        context.delete(document)
    }

    private func insertDocument(name: String, fileName: String, contentType: String) {
        let document = MedicalDocument(name: name, fileName: fileName, contentType: contentType)
        document.profile = profile
        context.insert(document)
    }

    private func saveScan(_ images: [UIImage]) {
        guard !images.isEmpty else { return }
        let data = DocumentFileStore.pdfData(from: images)
        guard let fileName = try? DocumentFileStore.save(data, fileExtension: "pdf") else { return }
        let name = "Scan \(Date().formatted(date: .abbreviated, time: .omitted))"
        insertDocument(name: name, fileName: fileName, contentType: "application/pdf")
    }

    private func importPhotos() {
        let items = photoItems
        photoItems = []
        guard !items.isEmpty else { return }
        Task {
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                let utType = item.supportedContentTypes.first
                let ext = utType?.preferredFilenameExtension ?? "jpg"
                let mime = utType?.preferredMIMEType ?? "image/jpeg"
                guard let fileName = try? DocumentFileStore.save(data, fileExtension: ext) else { continue }
                let name = "Photo \(Date().formatted(date: .abbreviated, time: .omitted))"
                insertDocument(name: name, fileName: fileName, contentType: mime)
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }
            let ext = url.pathExtension.isEmpty ? "pdf" : url.pathExtension
            let mime = UTType(filenameExtension: ext)?.preferredMIMEType ?? "application/octet-stream"
            guard let fileName = try? DocumentFileStore.save(data, fileExtension: ext) else { continue }
            insertDocument(name: url.deletingPathExtension().lastPathComponent, fileName: fileName, contentType: mime)
        }
    }
}

struct DocumentThumbnailView: View {
    let fileName: String
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "doc")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 44, height: 58)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
        .task(id: fileName) {
            let request = QLThumbnailGenerator.Request(
                fileAt: DocumentFileStore.url(forFileName: fileName),
                size: CGSize(width: 88, height: 116),
                scale: 2,
                representationTypes: .thumbnail
            )
            if let representation = try? await QLThumbnailGenerator.shared.generateBestRepresentation(for: request) {
                thumbnail = representation.uiImage
            }
        }
    }
}
