import SwiftUI

struct SharedUploadsView: View {
    @StateObject private var sharedManager = SharedAudioManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    if sharedManager.pendingUploads.isEmpty {
                        emptyStateView
                    } else {
                        headerSection
                        uploadsListSection
                    }
                }
                .padding()
            }
            .navigationTitle("Shared Uploads")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: refreshUploads) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .onAppear {
                sharedManager.loadPendingUploads()
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Shared Files")
                .font(.title)
                .foregroundColor(.primary)
            
            Text("Share audio files from other apps using the \"Add to Listener\" extension to see them here.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 60)
    }
    
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Auto-Processing Status")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("\(sharedManager.pendingUploads.count) file\(sharedManager.pendingUploads.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            
            if sharedManager.pendingUploads.contains(where: { $0.uploadStatus == .uploading }) {
                HStack {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Auto-processing files...")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.blue.opacity(0.1))
                    .cornerRadius(8)
                    
                    Spacer()
                }
            }
        }
    }
    
    private var uploadsListSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(sharedManager.pendingUploads) { sharedFile in
                SharedFileCard(sharedFile: sharedFile) {
                    sharedManager.deleteSharedFile(sharedFile)
                }
            }
        }
    }
    
    private func refreshUploads() {
        sharedManager.loadPendingUploads()
    }
}

struct SharedFileCard: View {
    let sharedFile: SharedAudioFile
    let onDelete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(sharedFile.metadata.originalFilename)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                statusBadge
            }
            
            if !sharedFile.metadata.notes.isEmpty {
                Text(sharedFile.metadata.notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
            }
            
            HStack {
                Text("Auto-processing enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(action: onDelete) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Delete")
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.separator), lineWidth: 1)
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            switch sharedFile.uploadStatus {
            case .pending:
                Image(systemName: "clock")
                Text("Pending")
            case .uploading:
                ProgressView()
                    .scaleEffect(0.8)
                Text("Uploading")
            case .completed:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Completed")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Failed")
            }
        }
        .font(.caption)
        .foregroundColor(statusColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusBackgroundColor)
        .cornerRadius(6)
    }
    
    private var statusColor: Color {
        switch sharedFile.uploadStatus {
        case .pending:
            return .secondary
        case .uploading:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var statusBackgroundColor: Color {
        switch sharedFile.uploadStatus {
        case .pending:
            return Color(.secondarySystemBackground)
        case .uploading:
            return Color.blue.opacity(0.1)
        case .completed:
            return Color.green.opacity(0.1)
        case .failed:
            return Color.red.opacity(0.1)
        }
    }
    
    private var formattedDate: String {
        let date = Date(timeIntervalSince1970: TimeInterval(sharedFile.metadata.timestamp))
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    SharedUploadsView()
}