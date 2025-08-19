//
//  EnhancedImagePicker.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import PhotosUI
import Combine

struct EnhancedImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Binding var selectedVideoURL: URL?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mediaHistory = MediaHistoryManager.shared
    @State private var selectedTab = 0
    @State private var showingMediaPicker = false
    @State private var isFromHistory = false // Track if selection is from history
    @State private var tempVideoURL: URL? // Temporary state to trigger onChange
    
    // Callback to notify parent about selection source
    var onImageSelected: ((UIImage, Bool) -> Void)? = nil // (image, isFromHistory)
    var onVideoSelected: ((URL, Bool) -> Void)? = nil // (videoURL, isFromHistory)
    
    // Convenience initializer for image-only mode (backward compatibility)
    init(selectedImage: Binding<UIImage?>, onImageSelected: ((UIImage, Bool) -> Void)? = nil) {
        self._selectedImage = selectedImage
        self._selectedVideoURL = .constant(nil)
        self.onImageSelected = onImageSelected
        self.onVideoSelected = nil
    }
    
    // Full initializer for image and video support
    init(selectedImage: Binding<UIImage?>, selectedVideoURL: Binding<URL?>, onImageSelected: ((UIImage, Bool) -> Void)? = nil, onVideoSelected: ((URL, Bool) -> Void)? = nil) {
        self._selectedImage = selectedImage
        self._selectedVideoURL = selectedVideoURL
        self.onImageSelected = onImageSelected
        self.onVideoSelected = onVideoSelected
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Tab Picker
                Picker("Source", selection: $selectedTab) {
                    Text("History").tag(0)
                    Text("Camera Roll").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                // Content based on selected tab
                if selectedTab == 0 {
                    // History Tab
                    HistoryGridView(
                        historyItems: mediaHistory.historyItems,
                        onImageSelected: { image in
                            print("🎬 EnhancedImagePicker: Image selected from history")
                            isFromHistory = true // Mark as selected from history BEFORE setting selectedImage
                            selectedImage = image
                            selectedVideoURL = nil
                            // The onChange handler will handle calling the parent callback and dismissing
                        },
                        onVideoSelected: { videoURL in
                            selectedVideoURL = videoURL
                            selectedImage = nil
                            isFromHistory = true // Mark as selected from history
                            onVideoSelected?(videoURL, true) // Notify parent: from history
                            dismiss()
                        }
                    )
                } else {
                    // Camera Roll Tab
                    VStack(spacing: 20) {
                        Spacer()
                        
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Select from Camera Roll")
                            .font(.title2)
                            .foregroundColor(.primary)
                        
                        Text("Choose photos or videos")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button("Open Camera Roll") {
                            showingMediaPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Select Media")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .toolbar {
                if selectedTab == 0 && !mediaHistory.historyItems.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Clear All") {
                            mediaHistory.clearHistory()
                        }
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .sheet(isPresented: $showingMediaPicker) {
            MediaPicker(
                selectedImage: $selectedImage, 
                selectedVideoURL: $selectedVideoURL,
                onVideoSelected: { videoURL in
                    print("🎬 EnhancedImagePicker: onVideoSelected called with: \(videoURL.absoluteString)")
                    print("🎬 EnhancedImagePicker: Setting tempVideoURL to trigger onChange")
                    
                    // Set temporary state to trigger onChange
                    tempVideoURL = videoURL
                },
                onImageSelected: { image in
                    print("🎬 EnhancedImagePicker: onImageSelected called")
                    print("🎬 EnhancedImagePicker: Setting selectedImage to trigger immediate update")
                    
                    // Set the selectedImage binding to trigger immediate UI update
                    selectedImage = image
                    
                    // The onChange handler will handle calling the parent callback and dismissing
                }
            )
            .onAppear {
                // Reset the flag when opening camera roll picker
                isFromHistory = false
                print("🎬 MediaPicker opened, reset isFromHistory to false")
            }
        }
        .onAppear {
            print("🎬 EnhancedImagePicker appeared - selectedVideoURL: \(selectedVideoURL?.absoluteString ?? "nil")")
            // Reset the isFromHistory flag when the picker appears
            isFromHistory = false
        }
        .onReceive(Just(selectedVideoURL)) { url in
            print("🎬 EnhancedImagePicker received selectedVideoURL update: \(url?.absoluteString ?? "nil")")
        }
        .onChange(of: selectedImage) { oldImage, newImage in
            print("🎬 selectedImage onChange: old=\(oldImage != nil ? "image" : "nil"), new=\(newImage != nil ? "image" : "nil"), isFromHistory=\(isFromHistory)")
            
            if let image = newImage {
                if isFromHistory {
                    // Image selected from history - notify parent and dismiss
                    print("🎬 Image selected from history, notifying parent")
                    onImageSelected?(image, true) // Notify parent: from history
                    dismiss()
                } else {
                    // Image selected from camera roll - add to history, notify parent, and dismiss
                    print("🎬 Adding image to history and notifying parent")
                    mediaHistory.addToHistory(image)
                    onImageSelected?(image, false) // Notify parent: from camera roll
                    dismiss()
                }
            } else if newImage == nil && oldImage != nil {
                print("🎬 selectedImage was cleared (set to nil) - not calling onImageSelected")
            }
        }
        .onChange(of: tempVideoURL) { oldURL, newURL in
            print("🎬 TempVideo URL changed: \(newURL?.absoluteString ?? "nil")")
            
            if let videoURL = newURL {
                print("🎬 Processing temp video URL, setting selectedVideoURL")
                selectedVideoURL = videoURL
                selectedImage = nil
                print("🎬 selectedVideoURL set to: \(selectedVideoURL?.absoluteString ?? "nil")")
                dismiss()
            }
        }
        .onChange(of: selectedVideoURL) { oldURL, newURL in
            print("🎬 Video URL changed: \(newURL?.absoluteString ?? "nil"), isFromHistory: \(isFromHistory)")
            
            if let videoURL = newURL, !isFromHistory {
                print("🎬 Starting video import from camera roll...")
                
                // Only add to history when video is selected from camera roll, not from history
                mediaHistory.addToHistory(videoURL) { result in
                    print("🎬 Video import completed with result: \(result)")
                    DispatchQueue.main.async {
                        switch result {
                        case .success(let localVideoURL):
                            print("✅ Video imported successfully to: \(localVideoURL.path)")
                            self.onVideoSelected?(localVideoURL, false) // Use local URL for playback
                            self.dismiss()
                        case .failure(let error):
                            print("❌ Video import failed: \(error.localizedDescription)")
                            // TODO: Show error alert to user
                            // For now, still dismiss but video won't be in history
                            self.dismiss()
                        }
                    }
                }
            } else if newURL != nil {
                print("🎬 Video selected from history, dismissing immediately")
                dismiss()
            }
        }
    }
}

struct HistoryGridView: View {
    let historyItems: [MediaHistoryItem]
    let onImageSelected: (UIImage) -> Void
    let onVideoSelected: ((URL) -> Void)?
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 8)
    ]
    
    var body: some View {
        if historyItems.isEmpty {
            VStack(spacing: 20) {
                Spacer()
                
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 60))
                    .foregroundColor(.gray)
                
                Text("No History Yet")
                    .font(.title2)
                    .foregroundColor(.primary)
                
                Text("Photos and videos you select will appear here for quick access")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
            }
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(historyItems) { item in
                        HistoryThumbnailView(
                            item: item,
                            onTap: {
                                if item.isVideo, let videoURL = item.videoURL {
                                    onVideoSelected?(videoURL)
                                } else if let image = item.image {
                                    onImageSelected(image)
                                }
                            },
                            onDelete: {
                                MediaHistoryManager.shared.removeFromHistory(item)
                            }
                        )
                    }
                }
                .padding()
            }
        }
    }
}

struct HistoryThumbnailView: View {
    let item: MediaHistoryItem
    let onTap: () -> Void
    let onDelete: () -> Void
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Thumbnail image
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipped()
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: item.isVideo ? "video" : "photo")
                                .foregroundColor(.gray)
                        )
                }
                
                // Video indicator overlay
                if item.isVideo {
                    VStack {
                        Spacer()
                        HStack {
                            // Play icon
                            Image(systemName: "play.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                                .padding(.leading, 8)
                            
                            Spacer()
                            
                            // Duration
                            if let duration = item.formattedDuration {
                                Text(duration)
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.black.opacity(0.7))
                                    .cornerRadius(4)
                                    .padding(.trailing, 8)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                
                // Delete button overlay
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            showingDeleteAlert = true
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.white)
                                .background(Color.red.opacity(0.8))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(4)
                
                // Date overlay
                VStack {
                    Spacer()
                    HStack {
                        Text(item.dateAdded, style: .date)
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.6))
                            .cornerRadius(4)
                        Spacer()
                    }
                }
                .padding(4)
            }
        }
        .buttonStyle(.plain)
        .alert("Delete Image", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove this image from your history?")
        }
    }
}
