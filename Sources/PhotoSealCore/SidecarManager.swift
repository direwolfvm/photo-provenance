import Foundation

public enum SidecarManager {
    public static func sidecarURL(for assetURL: URL) -> URL {
        let base = assetURL.deletingPathExtension()
        return base.appendingPathExtension("c2pa")
    }

    public static func writeSidecar(_ data: Data, for assetURL: URL) throws -> URL {
        let sidecarURL = sidecarURL(for: assetURL)
        try data.write(to: sidecarURL, options: [.atomic])
        return sidecarURL
    }

    public static func packageForSharing(assetURL: URL, sidecarURL: URL) throws -> URL {
        let zipURL = assetURL.deletingPathExtension().appendingPathExtension("photoseal.zip")
        let coordinator = NSFileCoordinator()
        var error: NSError?
        coordinator.coordinate(writingItemAt: zipURL, options: .forReplacing, error: &error) { destination in
            let archive = ArchiveBuilder(destination: destination)
            archive.addFile(at: assetURL, name: assetURL.lastPathComponent)
            archive.addFile(at: sidecarURL, name: sidecarURL.lastPathComponent)
            archive.finish()
        }
        if let error {
            throw error
        }
        return zipURL
    }
}

private final class ArchiveBuilder {
    private let destination: URL
    private var entries: [(URL, String)] = []

    init(destination: URL) {
        self.destination = destination
    }

    func addFile(at url: URL, name: String) {
        entries.append((url, name))
    }

    func finish() {
        let fileManager = FileManager.default
        fileManager.createFile(atPath: destination.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: destination) else {
            return
        }
        for (url, name) in entries {
            guard let data = try? Data(contentsOf: url) else { continue }
            let header = "--\(name)--\n"
            if let headerData = header.data(using: .utf8) {
                handle.write(headerData)
            }
            handle.write(data)
            if let footerData = "\n".data(using: .utf8) {
                handle.write(footerData)
            }
        }
        if #available(macOS 10.15, *) {
            try? handle.close()
        } else {
            handle.closeFile()
        }
    }
}
