import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 8)
            
            HStack(spacing: 20) {
                AppIconView(size: 80)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("The Annex")
                        .font(.title)
                        .fontWeight(.bold)
                    Text(AnnexQuotes.tagline)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "2.0.0")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .frame(width: 350)
            
            HStack(spacing: 24) {
                InfoRow(label: "Developer", value: "ry4nolson")
                InfoRow(label: "Build", value: "2026.03.11")
                InfoRow(label: "Platform", value: "macOS 12+")
            }
            
            Divider()
                .frame(width: 350)
            
            VStack(spacing: 6) {
                Text("Features")
                    .font(.headline)
                
                HStack(alignment: .top, spacing: 24) {
                    VStack(alignment: .leading, spacing: 3) {
                        FeatureItem(text: "Multi-folder sync with presets")
                        FeatureItem(text: "One-way sync (Local → NAS)")
                        FeatureItem(text: "Bandwidth throttling")
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        FeatureItem(text: "Smart sync (WiFi, power-based)")
                        FeatureItem(text: "Activity logging & statistics")
                        FeatureItem(text: "NAS monitoring & health checks")
                    }
                }
            }
            
            Spacer(minLength: 4)
            
            VStack(spacing: 4) {
                Text(AnnexQuotes.aboutInspiration)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if AnnexQuotes.shared.showPersonality {
                    Text(AnnexQuotes.aboutFooter)
                        .font(.caption)
                        .italic()
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .padding(.bottom, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
            Text(value)
                .fontWeight(.medium)
        }
    }
}

struct FeatureItem: View {
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.caption)
            Text(text)
                .font(.subheadline)
        }
    }
}

struct AppIconView: View {
    let size: CGFloat
    
    var body: some View {
        Group {
            if let image = loadAppIcon() {
                Image(nsImage: image)
                    .resizable()
                    .frame(width: size, height: size)
                    .cornerRadius(size * 0.2)
            } else {
                Image(systemName: "externaldrive.fill.badge.checkmark")
                    .font(.system(size: size * 0.6))
                    .foregroundColor(.blue)
                    .frame(width: size, height: size)
            }
        }
    }
    
    private func loadAppIcon() -> NSImage? {
        if let resourcePath = Bundle.main.resourcePath {
            let iconPath = (resourcePath as NSString).appendingPathComponent("AppIcon.png")
            return NSImage(contentsOfFile: iconPath)
        }
        return nil
    }
}
