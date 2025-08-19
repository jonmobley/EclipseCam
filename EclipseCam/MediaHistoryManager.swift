//
//  MediaHistoryManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import Foundation
import AVFoundation
import AVKit
import Photos

// MARK: - Media Type
enum MediaType: String, Codable {
    case image
    case video
}

// MARK: - Video Import Error
enum VideoImportError: Error, LocalizedError {
    case fileTooLarge(sizeInMB: Double)
    case copyFailed(underlying: Error)
    case invalidURL
    case insufficientStorage
    case unknownError
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge(let sizeInMB):
            return "Video file is too large (\(String(format: "%.1f", sizeInMB))MB). Please select a smaller video."
        case .copyFailed(let underlying):
            return "Failed to import video: \(underlying.localizedDescription)"
        case .invalidURL:
            return "Invalid video file selected."
        case .insufficientStorage:
            return "Not enough storage space to import video."
        case .unknownError:
            return "An unknown error occurred while importing the video."
        }
    }
}

// MARK: - Media History Item
struct MediaHistoryItem: Codable, Identifiable {
    let id: UUID
    let mediaType: MediaType
    let mediaData: Data // Image data or video file path
    let dateAdded: Date
    let thumbnailData: Data // Thumbnail for both images and videos
    let duration: Double? // Video duration in seconds (nil for images)
    
    // Initialize with image
    init(image: UIImage) {
        self.id = UUID()
        self.mediaType = .image
        self.dateAdded = Date()
        self.duration = nil
        
        // Store full resolution image
        if let fullData = image.jpegData(compressionQuality: 0.8) {
            self.mediaData = fullData
        } else {
            self.mediaData = Data()
        }
        
        // Create and store thumbnail (300px max dimension for performance)
        let thumbnailSize = CGSize(width: 300, height: 300)
        let thumbnail = image.resized(to: thumbnailSize)
        if let thumbData = thumbnail.jpegData(compressionQuality: 0.7) {
            self.thumbnailData = thumbData
        } else {
            self.thumbnailData = Data()
        }
    }
    
    // Initialize with local video file path (after copying to app directory)
    init(localVideoPath: String, duration: Double, thumbnailData: Data) {
        self.id = UUID()
        self.mediaType = .video
        self.dateAdded = Date()
        self.duration = duration
        self.thumbnailData = thumbnailData
        
        // Store local video file path as string data
        self.mediaData = localVideoPath.data(using: .utf8) ?? Data()
    }
    
    var image: UIImage? {
        guard mediaType == .image else { return nil }
        return UIImage(data: mediaData)
    }
    
    var videoURL: URL? {
        guard mediaType == .video else { return nil }
        guard let pathString = String(data: mediaData, encoding: .utf8) else { return nil }
        return URL(fileURLWithPath: pathString)
    }
    
    var thumbnail: UIImage? {
        return UIImage(data: thumbnailData)
    }
    
    var isVideo: Bool {
        return mediaType == .video
    }
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Media History Manager
@MainActor
class MediaHistoryManager: ObservableObject {
    static let shared = MediaHistoryManager()
    
    @Published var historyItems: [MediaHistoryItem] = []
    private let maxHistoryItems = 50 // Limit to prevent storage bloat
    private let userDefaults = UserDefaults.standard
    private let historyKey = "MediaHistory"
    
    private init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    func addToHistory(_ image: UIImage) {
        let newItem = MediaHistoryItem(image: image)
        
        // Remove duplicate if exists (same media data)
        historyItems.removeAll { item in
            item.mediaData == newItem.mediaData
        }
        
        // Add to beginning of array (most recent first)
        historyItems.insert(newItem, at: 0)
        
        // Limit history size
        if historyItems.count > maxHistoryItems {
            historyItems = Array(historyItems.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func addToHistory(_ videoURL: URL, completion: @escaping (Result<URL, VideoImportError>) -> Void) {
        print("📹 MediaHistoryManager: Starting video import from \(videoURL.absoluteString)")
        Task {
            do {
                let localPath = try await importVideo(from: videoURL)
                print("📹 MediaHistoryManager: Video copied to local path: \(localPath)")
                
                // Get video duration and generate thumbnail from local file
                let localURL = URL(fileURLWithPath: localPath)
                let asset = AVURLAsset(url: localURL)
                
                // Load duration using modern API
                let duration = try await asset.load(.duration)
                let durationInSeconds = CMTimeGetSeconds(duration)
                
                // Generate thumbnail using modern async API
                let imageGenerator = AVAssetImageGenerator(asset: asset)
                imageGenerator.appliesPreferredTrackTransform = true
                imageGenerator.maximumSize = CGSize(width: 300, height: 300)
                
                var thumbnailData = Data()
                do {
                    let cgImage = try await imageGenerator.image(at: CMTime.zero).image
                    let thumbnailImage = UIImage(cgImage: cgImage)
                    thumbnailData = thumbnailImage.jpegData(compressionQuality: 0.7) ?? Data()
                } catch {
                    print("Failed to generate video thumbnail: \(error)")
                }
                
                // Update UI on main actor
                await MainActor.run {
                    let newItem = MediaHistoryItem(localVideoPath: localPath, duration: durationInSeconds, thumbnailData: thumbnailData)
                    
                    // Remove duplicate if exists (same media data)
                    self.historyItems.removeAll { item in
                        item.mediaData == newItem.mediaData
                    }
                    
                    // Add to beginning of array (most recent first)
                    self.historyItems.insert(newItem, at: 0)
                    
                    // Limit history size
                    if self.historyItems.count > self.maxHistoryItems {
                        self.historyItems = Array(self.historyItems.prefix(self.maxHistoryItems))
                    }
                    
                    self.saveHistory()
                    print("📹 MediaHistoryManager: Video import completed successfully, calling completion with: \(localURL.absoluteString)")
                    completion(.success(localURL))
                }
            } catch {
                await MainActor.run {
                    completion(.failure(error as? VideoImportError ?? .unknownError))
                }
            }
        }
    }
    
    func removeFromHistory(_ item: MediaHistoryItem) {
        // If it's a video, delete the local file
        if item.mediaType == .video, let videoURL = item.videoURL {
            cleanupVideoFile(at: videoURL)
        }
        
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
        // Clean up all video files before clearing history
        for item in historyItems where item.mediaType == .video {
            if let videoURL = item.videoURL {
                cleanupVideoFile(at: videoURL)
            }
        }
        
        historyItems.removeAll()
        saveHistory()
    }
    
    // MARK: - Private Methods
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(historyItems)
            userDefaults.set(data, forKey: historyKey)
        } catch {
            print("Failed to save media history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = userDefaults.data(forKey: historyKey) else { return }
        
        do {
            let decoder = JSONDecoder()
            historyItems = try decoder.decode([MediaHistoryItem].self, from: data)
        } catch {
            print("Failed to load media history: \(error)")
            // Clear corrupted data
            userDefaults.removeObject(forKey: historyKey)
        }
    }
    
    // MARK: - Video Import Methods
    
    private func importVideo(from sourceURL: URL) async throws -> String {
        // Check file size (limit to 500MB)
        let maxSizeInBytes: Int64 = 500 * 1024 * 1024 // 500MB
        
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
            if let fileSize = fileAttributes[.size] as? Int64 {
                let sizeInMB = Double(fileSize) / (1024 * 1024)
                if fileSize > maxSizeInBytes {
                    throw VideoImportError.fileTooLarge(sizeInMB: sizeInMB)
                }
                print("📹 Video size: \(String(format: "%.1f", sizeInMB))MB")
            }
        } catch {
            if error is VideoImportError {
                throw error
            }
            // If we can't get file size, continue anyway
            print("⚠️ Could not determine video file size: \(error)")
        }
        
        // Create videos directory in Documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let videosDirectory = documentsPath.appendingPathComponent("Videos")
        
        try FileManager.default.createDirectory(at: videosDirectory, withIntermediateDirectories: true)
        
        // Generate unique filename
        let uniqueID = UUID().uuidString
        let destinationURL = videosDirectory.appendingPathComponent("\(uniqueID).mp4")
        
        // Copy the video file
        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            print("✅ Video imported successfully to: \(destinationURL.path)")
            return destinationURL.path
        } catch {
            throw VideoImportError.copyFailed(underlying: error)
        }
    }
    
    private func cleanupVideoFile(at videoURL: URL) {
        do {
            try FileManager.default.removeItem(at: videoURL)
            print("🗑️ Cleaned up video file: \(videoURL.path)")
        } catch {
            print("⚠️ Failed to cleanup video file: \(error)")
        }
    }
    
    // Get videos directory for app
    private func getVideosDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("Videos")
    }
}

// MARK: - UIImage Extension
extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        let aspectRatio = self.size.width / self.size.height
        let targetAspectRatio = size.width / size.height
        
        var newSize: CGSize
        if aspectRatio > targetAspectRatio {
            // Image is wider than target
            newSize = CGSize(width: size.width, height: size.width / aspectRatio)
        } else {
            // Image is taller than target
            newSize = CGSize(width: size.height * aspectRatio, height: size.height)
        }
        
        // Ensure we don't upscale
        if newSize.width > self.size.width || newSize.height > self.size.height {
            newSize = self.size
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
