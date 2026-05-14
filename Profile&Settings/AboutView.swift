import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            List {
                // MARK: - LOGO VE BAŞLIK
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "cloud.sun.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 80, height: 80)
                                .symbolRenderingMode(.multicolor)
                                .shadow(radius: 5)
                            
                            VStack(spacing: 4) {
                                Text("Hava Durumu Asistanı")
                                    .font(.headline)
                                Text("Sürüm 1.0.0")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .listRowBackground(Color.clear)
                }

                // MARK: - GELİŞTİRİCİ BİLGİSİ
                Section(header: Text("GELİŞTİRİCİ")) {
                    HStack {
                        Text("Yazılım Geliştirme")
                        Spacer()
                        Text("Ahmet Çiçek")
                            .foregroundColor(.secondary)
                    }
                }

                // MARK: - YASAL VE İLETİŞİM
                Section(header: Text("YASAL & DESTEK"), footer: Text("© 2026 Ahmet Çiçek. Tüm hakları saklıdır.")) {
                    Link(destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!) {
                        SettingsRow(title: "Kullanım Koşulları", icon: "doc.text")
                    }
                    
                    Link(destination: URL(string: "https://www.apple.com/legal/privacy/")!) {
                        SettingsRow(title: "Gizlilik Politikası", icon: "hand.raised.fill")
                    }
                    
                    // DESTEK MAİL LİNKİ
                    Link(destination: URL(string: "mailto:acicek167@gmail.com")!) {
                        SettingsRow(title: "Destek ile İletişime Geç", icon: "envelope.fill")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        .navigationTitle("Hakkımızda")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Bitti") { dismiss() }
                    .fontWeight(.bold)
            }
        }
    }
    
    var dynamicBackground: some View {
        selectedTheme == .koyu ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
}

// Ortak Satır Tasarımı
struct SettingsRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}
