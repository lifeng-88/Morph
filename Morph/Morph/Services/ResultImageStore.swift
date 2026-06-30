import UIKit

enum ResultImageStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("morph_results", isDirectory: true)
    }

    static func save(_ image: UIImage) throws -> String {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let filename = "\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.92) else {
            throw FaceSwapError.imageEncodingFailed
        }
        try data.write(to: url, options: .atomic)
        return filename
    }

    static func load(_ filename: String) -> UIImage? {
        let url = directory.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }

    static func delete(_ filename: String) {
        let url = directory.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }
}
