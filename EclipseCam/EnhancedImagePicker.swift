//
//  EnhancedImagePicker.swift
//  EclipseCam
//
//  Created by Jon Mobley on 8/18/25.
//

import SwiftUI
import PhotosUI

struct EnhancedImagePicker: View {
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    @StateObject private var mediaHistory = MediaHistoryManager.shared
    @State private var selectedTab = 0
    @State private var showingPhotoPicker = false
    @State private var isFromHistory = false // Track if selection is from history
    
    // Callback to notify parent about selection source
    var onImageSelected: ((UIImage, Bool) -> Void)? = nil // (image, isFromHistory)
    
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
                            selectedImage = image
                            isFromHistory = true // Mark as selected from history
                            onImageSelected?(image, true) // Notify parent: from history
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
                        
                        Button("Open Camera Roll") {
                            showingPhotoPicker = true
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Select Image")
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
        .sheet(isPresented: $showingPhotoPicker) {
            ImagePicker(selectedImage: $selectedImage)
        }
        .onChange(of: selectedImage) { oldImage, newImage in
            if let image = newImage, !isFromHistory {
                // Only add to history when image is selected from camera roll, not from history
                mediaHistory.addToHistory(image)
                onImageSelected?(image, false) // Notify parent: from camera roll
                dismiss()
            }
        }
    }
}

struct HistoryGridView: View {
    let historyItems: [MediaHistoryItem]
    let onImageSelected: (UIImage) -> Void
    
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
                
                Text("Images you select will appear here for quick access")
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
                                if let image = item.image {
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
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )
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
