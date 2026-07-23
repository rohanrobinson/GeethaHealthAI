import Foundation

// Approximates the app's on-device footprint: the SwiftData store
// (Application Support) plus imported/scanned documents (Documents dir).
enum StorageInfo {
    static func usedBytes() -> Int64 {
        let fm = FileManager.default
        let directories = [
            fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fm.urls(for: .documentDirectory, in: .userDomainMask).first,
        ].compactMap { $0 }
        return directories.reduce(0) { $0 + directorySize(at: $1) }
    }

    private static func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }

        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                  values.isRegularFile == true else { continue }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    static func formatted() -> String {
        ByteCountFormatter.string(fromByteCount: usedBytes(), countStyle: .file)
    }
}
