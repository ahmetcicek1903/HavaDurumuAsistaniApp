import SwiftUI
import FirebaseAuth
import CoreLocation

struct AccountView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject var authManager = AuthManager.shared
    
    // Uygulama ayarları
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    @AppStorage("autoLocation") private var autoLocation: Bool = false
    
    // İŞLEM ŞALTERLERİ
    @State private var showSignOutAlert = false
    @State private var showDeleteAccountAlert = false
    @State private var showLocationDeniedAlert = false
    
    // İKAZ LAMBALARI
    @State private var showErrorAlert = false
    @State private var errorAlertTitle = ""
    @State private var errorAlertMessage = ""
    
    // İŞTE YENİ MOTOR: Apple'ın orijinal konum yöneticisi (Senin klası yormamak için)
    @State private var clManager = CLLocationManager()
    
    var body: some View {
        NavigationStack {
            ZStack {
                dynamicBackground.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        profileSection
                        
                        navigationLinksSection
                        
                        preferencesSection
                        
                        dangerZoneSection
                    }
                }
            }
            .navigationTitle("Hesabım")
            .navigationBarTitleDisplayMode(.inline)
            .preferredColorScheme(selectedTheme.colorScheme)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") { dismiss() }.fontWeight(.bold)
                }
            }
            // --- ONAY VE BİLDİRİM PENCERELERİ ---
            .alert("Oturumu Kapat", isPresented: $showSignOutAlert) {
                Button("İptal", role: .cancel) { }
                Button("Çıkış Yap", role: .destructive) { performSignOut() }
            } message: {
                Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?")
            }
            .alert("Hesabı Kalıcı Olarak Sil", isPresented: $showDeleteAccountAlert) {
                Button("İptal", role: .cancel) { }
                Button("Hesabımı Sil", role: .destructive) { performAccountDeletion() }
            } message: {
                Text("Bu işlem geri alınamaz. Hesabınız ve tüm verileriniz sistemden kalıcı olarak silinecektir. Onaylıyor musunuz?")
            }
            .alert(errorAlertTitle, isPresented: $showErrorAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorAlertMessage)
            }
            .alert("Konum İzni Gerekli", isPresented: $showLocationDeniedAlert) {
                Button("Ayarlara Git") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("İptal", role: .cancel) { }
            } message: {
                Text("Cihazınızdan konum izni reddedilmiş. Otomatik konumu açmak için cihaz ayarlarından izin vermeniz gerekiyor.")
            }
        }
    }
    
    // MARK: - ALT PARÇALAR
    
    private var profileSection: some View {
        VStack(spacing: 15) {
            if let photoURL = authManager.userSession?.photoURL {
                AsyncImage(url: photoURL) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                }
                .frame(width: 90, height: 90)
                .clipShape(Circle())
                .shadow(color: .blue.opacity(0.3), radius: 10)
                .overlay(Circle().stroke(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3))
            } else {
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 90, height: 90)
                    .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .background(Circle().fill(.ultraThinMaterial))
                    .shadow(color: .blue.opacity(0.3), radius: 10)
            }
            
            VStack(spacing: 5) {
                Text(authManager.userSession?.displayName ?? "Kullanıcı Adı")
                    .font(.title2).fontWeight(.bold)
                
                Text(authManager.userSession?.email ?? "Kullanıcı Bulunamadı")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 30)
        .frame(maxWidth: .infinity)
        .modifier(DynamicGlassCard())
        .padding(.horizontal)
    }
    
    private var navigationLinksSection: some View {
        VStack(spacing: 0) {
            NavigationLink(destination: PersonalInfoView()) {
                AccountMenuRow(icon: "person.text.rectangle.fill", title: "Kişisel Bilgiler", color: .blue)
            }
            
            Divider().padding(.leading, 60)
            
            NavigationLink(destination: SecurityView()) {
                AccountMenuRow(icon: "shield.lefthalf.filled", title: "Şifre ve Güvenlik", color: .green)
            }
        }
        .modifier(DynamicGlassCard())
        .padding(.horizontal)
    }
    
    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TERCİHLER")
                .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                .padding(.leading, 25)
            
            VStack(spacing: 0) {
                // TEMA SEÇİCİ
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "circle.lefthalf.filled").foregroundColor(.orange)
                        Text("Tema Seçimi").fontWeight(.medium)
                    }
                    Picker("Tema", selection: $selectedTheme) {
                        ForEach(Theme.allCases, id: \.self) { theme in
                            Text(theme.rawValue).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()

                Divider().padding(.horizontal)

                // BİLDİRİM AYARLARI
                NavigationLink(destination: NotificationSettingsView()) {
                    HStack(spacing: 15) {
                        Image(systemName: "bell.badge.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.red.cornerRadius(8))
                        
                        Text("Bildirim Ayarları").fontWeight(.medium).foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                    .padding()
                }

                Divider().padding(.horizontal)

                // KONUM ŞALTERİ (TERTEMİZ BINDING)
                Toggle(isOn: Binding(
                    get: { self.autoLocation },
                    set: { newValue in
                        self.handleLocationToggle(newValue: newValue)
                    }
                )) {
                    HStack(spacing: 15) {
                        Image(systemName: "location.fill")
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.cornerRadius(8))
                        Text("Otomatik Konum").fontWeight(.medium)
                    }
                }
                .padding()
                .tint(.blue)
            }
            .modifier(DynamicGlassCard())
            .padding(.horizontal)
        }
    }
    
    private var dangerZoneSection: some View {
        VStack(spacing: 12) {
            Button(action: { showSignOutAlert = true }) {
                HStack {
                    Image(systemName: "power")
                    Text("Güvenli Çıkış Yap")
                }
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(LinearGradient(colors: [.red, Color(red: 0.6, green: 0, blue: 0)], startPoint: .leading, endPoint: .trailing))
                .cornerRadius(15)
                .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
            }
            
            Button(action: { showDeleteAccountAlert = true }) {
                Text("Hesabı Kalıcı Olarak Sil")
                    .font(.footnote)
                    .foregroundColor(.red.opacity(0.6))
                    .padding(.top, 10)
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
    
    // MARK: - İŞLEVLER VE MANTIK
    
    // ŞALTERE BASILINCA ÇALIŞACAK ANA MOTOR
    private func handleLocationToggle(newValue: Bool) {
        if newValue {
            let status = clManager.authorizationStatus
            
            if status == .notDetermined {
                // Apple'ın orijinal izin penceresini çağırıyoruz
                clManager.requestWhenInUseAuthorization()
                autoLocation = true
            } else if status == .denied || status == .restricted {
                showLocationDeniedAlert = true
                autoLocation = false
            } else {
                autoLocation = true
            }
        } else {
            autoLocation = false
        }
    }
    
    private func performSignOut() {
        authManager.signOut()
        dismiss()
    }
    
    private func performAccountDeletion() {
        guard let user = Auth.auth().currentUser else { return }
        user.delete { error in
            if let error = error {
                let errorCode = (error as NSError).code
                if errorCode == AuthErrorCode.requiresRecentLogin.rawValue {
                    errorAlertTitle = "Yeniden Giriş Gerekli"
                    errorAlertMessage = "Güvenlik nedeniyle, hesabınızı kalıcı olarak silebilmemiz için çıkış yapıp tekrar giriş yapmanız gerekmektedir."
                } else {
                    errorAlertTitle = "İşlem Başarısız"
                    errorAlertMessage = "Hesabınız silinirken sistemsel bir hata oluştu."
                }
                showErrorAlert = true
            } else {
                authManager.signOut()
                dismiss()
            }
        }
    }
    
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

// MARK: - YARDIMCI BİLEŞENLER
struct DynamicGlassCard: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? Color.white.opacity(0.05) : Color.white)
            .cornerRadius(20)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.4 : 0.08), radius: 15, x: 0, y: 8)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(colorScheme == .dark ? Color.white.opacity(0.1) : Color.clear, lineWidth: 1))
    }
}

struct AccountMenuRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon).font(.title3).foregroundColor(.white).frame(width: 32, height: 32).background(color.gradient , in:RoundedRectangle(cornerRadius : 8))
            Text(title).font(.body).fontWeight(.medium).foregroundColor(.primary)
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).fontWeight(.bold).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
    }
}
