import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    
    // Celsius şalterini çöpe attık!
    @State private var selectedTheme = 0
    @State private var autoLocation = false
    
    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
            
            Form {
                // 1. BÖLÜM: GÖRÜNÜM
                Section(header: Text("GÖRÜNÜM").foregroundColor(.gray)) {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Image(systemName: "circle.split.1x2.fill").foregroundColor(.blue)
                            Text("Tema Seçimi").foregroundColor(.white)
                        }
                        
                        Picker("Tema", selection: $selectedTheme) {
                            Text("Otomatik").tag(0)
                            Text("Açık").tag(1)
                            Text("Koyu").tag(2)
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.vertical, 5)
                }
                .listRowBackground(Color.white.opacity(0.05))
                
                // 2. BÖLÜM: BİLDİRİMLER VE İZİNLER (CELSIUS'UN YERİNE GELDİ)
                Section(header: Text("BİLDİRİMLER VE İZİNLER").foregroundColor(.gray)) {
                    
                    // BİLDİRİMLER ALT SAYFASINA GİDEN JİLET BUTON
                    NavigationLink(destination: NotificationSettingsView()) {
                        HStack(spacing: 15) {
                            Image(systemName: "bell.badge.fill").foregroundColor(.red)
                            Text("Bildirimler").foregroundColor(.white)
                        }
                    }
                    
                    Toggle(isOn: $autoLocation) {
                        HStack(spacing: 15) {
                            Image(systemName: "location.fill").foregroundColor(.green)
                            Text("Otomatik Konum Takibi").foregroundColor(.white)
                        }
                    }
                    .tint(.blue)
                }
                .listRowBackground(Color.white.opacity(0.05))
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Ayarlar")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bitti") { dismiss() }
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
        }
        .tint(.white)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}
