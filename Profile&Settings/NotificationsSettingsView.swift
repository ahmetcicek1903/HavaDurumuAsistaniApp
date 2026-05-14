import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @AppStorage("allowNotifications") private var allowNotifications = false
    @AppStorage("showDailyNotifications") private var showDailyNotifications = true
    @AppStorage("showDangerAlerts") private var showDangerAlerts = true
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    @State private var showingSettingsAlert = false
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    mainToggleSection
                    
                    if allowNotifications {
                        preferencesSection
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Bildirimler")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // Ekran açıldığında güncel izin durumunu Apple'dan kontrol et
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    self.allowNotifications = (settings.authorizationStatus == .authorized)
                }
            }
        }
        .alert(isPresented: $showingSettingsAlert) {
            Alert(
                title: Text("Bildirim İzni Gerekli"),
                message: Text("Başkan, daha önce bildirimleri reddetmişsin. Uyarıları alabilmek için telefonun Ayarlar menüsünden izin vermelisin."),
                primaryButton: .default(Text("Ayarlara Git")) {
                    if let appSettings = URL(string: UIApplication.openSettingsURLString), UIApplication.shared.canOpenURL(appSettings) {
                        UIApplication.shared.open(appSettings)
                    }
                },
                secondaryButton: .cancel(Text("İptal")) {
                    self.allowNotifications = false
                }
            )
        }
    }
    
    // MARK: - ALT PARÇALAR (TASARIM)
    
    private var mainToggleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ANA KONTROL")
                .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                .padding(.leading, 25)
            
            VStack(spacing: 0) {
                Toggle(isOn: Binding(
                    get: { allowNotifications },
                    set: { newValue in
                        if newValue {
                            checkAndRequestPermission()
                        } else {
                            allowNotifications = false
                            applyNotificationPreferences() // Şalter kapanınca tüm bildirimleri iptal et
                        }
                    }
                )) {
                    HStack(spacing: 15) {
                        Image(systemName: "bell.circle.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.green.cornerRadius(8))
                        Text("Bildirimlere İzin Ver").fontWeight(.medium)
                    }
                }
                .padding()
                .tint(.green)
            }
            .modifier(DynamicGlassCard())
            .padding(.horizontal)
            
            Text("Hava Durumu Asistanı'nın size günlük özetler ve acil durum uyarıları göndermesine izin verin.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 25)
        }
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("BİLDİRİM TERCİHLERİ")
                .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                .padding(.leading, 25)
            
            VStack(spacing: 0) {
                // GÜNLÜK ÖZET ŞALTERİ
                Toggle(isOn: Binding(
                    get: { showDailyNotifications },
                    set: { newValue in
                        showDailyNotifications = newValue
                        applyNotificationPreferences() // Ayar değişince motoru güncelle
                    }
                )) {
                    HStack(spacing: 15) {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.cornerRadius(8))
                        Text("Günlük Hava Özeti").fontWeight(.medium)
                    }
                }
                .padding()
                .tint(.blue)
                
                Divider().padding(.horizontal)
                
                // TEHLİKE UYARILARI ŞALTERİ
                Toggle(isOn: Binding(
                    get: { showDangerAlerts },
                    set: { newValue in
                        showDangerAlerts = newValue
                        applyNotificationPreferences()
                    }
                )) {
                    HStack(spacing: 15) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.red.cornerRadius(8))
                        Text("Tehlikeli Hava Uyarıları").fontWeight(.medium)
                    }
                }
                .padding()
                .tint(.red)
            }
            .modifier(DynamicGlassCard())
            .padding(.horizontal)
            
            Text("Tehlikeli hava uyarıları, bulunduğunuz konumda ani fırtına, sel veya aşırı sıcaklık durumlarında anlık bildirim gönderir.")
                .font(.caption)
                .foregroundColor(.gray)
                .padding(.horizontal, 25)
        }
    }
    
    // MARK: - İŞLEVLER (BİLDİRİM MOTORU)
    
    private func checkAndRequestPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            DispatchQueue.main.async {
                if settings.authorizationStatus == .notDetermined {
                    // İlk defa soruluyorsa Apple'dan izin iste
                    center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                        DispatchQueue.main.async {
                            if granted {
                                self.allowNotifications = true
                                self.applyNotificationPreferences() // İzin verildi, ayarları uygula
                            } else {
                                self.allowNotifications = false
                            }
                        }
                    }
                } else if settings.authorizationStatus == .denied {
                    // Daha önce reddettiyse uyarı verip Ayarlara yolla
                    self.showingSettingsAlert = true
                } else {
                    self.allowNotifications = true
                    self.applyNotificationPreferences()
                }
            }
        }
    }
    
    // Şalterlere göre Apple'ın bildirim saatini ayarlayan ana beyin
    private func applyNotificationPreferences() {
        let center = UNUserNotificationCenter.current()
        
        // Komple kapatıldıysa bütün kurulu bildirimleri temizle
        if !allowNotifications {
            center.removeAllPendingNotificationRequests()
            print("Tüm bildirimler iptal edildi.")
            return
        }
        
        // Günlük bildirim açık mı?
        if showDailyNotifications {
            scheduleDailySummary()
        } else {
            center.removePendingNotificationRequests(withIdentifiers: ["dailySummary"])
            print("Günlük özet iptal edildi.")
        }
        
        // Not: Tehlikeli hava uyarıları gerçekte bir API veya Firebase üzerinden Push Notification (APNs) ile gelir.
        // Şalter açıksa burada kullanıcının cihazını Firebase'deki 'danger_alerts' kanalına abone edebilirsin.
        if showDangerAlerts {
            print("Tehlikeli uyarılar aktif. (Firebase aboneliği yapılmalı)")
        } else {
            print("Tehlikeli uyarılar kapalı.")
        }
    }
    
    // Her sabah saat 08:00'e lokal bildirim kurma
    private func scheduleDailySummary() {
        let center = UNUserNotificationCenter.current()
        
        // Önce eskileri temizle ki üst üste binmesin
        center.removePendingNotificationRequests(withIdentifiers: ["dailySummary"])
        
        let content = UNMutableNotificationContent()
        content.title = "Günaydın Başkan ☀️"
        content.body = "Bugünün hava durumu raporu hazır. Çıkmadan önce Kahramanmaraş için son duruma göz atmayı unutma!"
        content.sound = .default
        
        // Sabah 08:00'e ayarla
        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "dailySummary", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Bildirim kurulamadı usta: \(error)")
            } else {
                print("Günlük bildirim her sabah 08:00 için zımba gibi kuruldu.")
            }
        }
    }
    
    // MARK: - ARKA PLAN
    var dynamicBackground: some View {
        ZStack {
            if selectedTheme == .acik {
                Color(uiColor: .systemGroupedBackground)
            } else if selectedTheme == .koyu {
                LinearGradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.12), .black], startPoint: .top, endPoint: .bottom)
            } else {
                Color(uiColor: .systemBackground)
            }
        }
    }
}


