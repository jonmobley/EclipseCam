//
//  MediaHistoryManager.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import Foundation

// MARK: - Media History Item
struct MediaHistoryItem: Codable, Identifiable {
    let id: UUID
    let imageData: Data
    let dateAdded: Date
    let thumbnailData: Data // Smaller version for UI performance
    
    init(image: UIImage) {
        self.id = UUID()
        self.dateAdded = Date()
        
        // Store full resolution image
        if let fullData = image.jpegData(compressionQuality: 0.8) {
            self.imageData = fullData
        } else {
            self.imageData = Data()
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
    
    var image: UIImage? {
        return UIImage(data: imageData)
    }
    
    var thumbnail: UIImage? {
        return UIImage(data: thumbnailData)
    }
}

// MARK: - Media History Manager
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
        
        // Remove duplicate if exists (same image data)
        historyItems.removeAll { item in
            item.imageData == newItem.imageData
        }
        
        // Add to beginning of array (most recent first)
        historyItems.insert(newItem, at: 0)
        
        // Limit history size
        if historyItems.count > maxHistoryItems {
            historyItems = Array(historyItems.prefix(maxHistoryItems))
        }
        
        saveHistory()
    }
    
    func removeFromHistory(_ item: MediaHistoryItem) {
        historyItems.removeAll { $0.id == item.id }
        saveHistory()
    }
    
    func clearHistory() {
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
