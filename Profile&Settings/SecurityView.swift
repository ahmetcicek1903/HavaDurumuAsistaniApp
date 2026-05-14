import FirebaseCore
import SwiftUI
import FirebaseAuth
import GoogleSignIn

struct SecurityView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    // Bağlantı Durumları ve Onay Kontrolleri
    @State private var isGoogleLinked = false
    @State private var isAppleLinked = false
    @State private var showSignOutAlert = false
    
    var body: some View {
        ZStack {
            // 1. Dinamik Arka Plan
            dynamicBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    
                    // 2. Erişim Ayarları
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ERİŞİM AYARLARI")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                            .padding(.leading, 10)
                        
                        VStack(spacing: 0) {
                            NavigationLink(destination: ChangeEmailView()) {
                                AccountMenuRow(icon: "envelope.badge.shield.half.filled", title: "E-Posta Adresini Değiştir", color: .blue)
                            }
                            
                            Divider().padding(.leading, 60)
                            
                            NavigationLink(destination: ChangePasswordView()) {
                                AccountMenuRow(icon: "key.horizontal.fill", title: "Şifreyi Güncelle", color: .orange)
                            }
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 3. Sosyal Bağlantılar
                    VStack(alignment: .leading, spacing: 12) {
                        Text("SOSYAL BAĞLANTILAR")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                            .padding(.leading, 10)
                        
                        VStack(spacing: 0) {
                            // Apple Butonu
                            Button(action: {
                                if !isAppleLinked { linkAppleAccount() }
                            }) {
                                SocialLinkRow(
                                    icon: "applelogo",
                                    title: "Apple ID",
                                    subtitle: isAppleLinked ? "Bağlı" : "Bağlamak İçin Dokun",
                                    color: .black,
                                    isLinked: isAppleLinked
                                )
                            }
                            
                            Divider().padding(.leading, 60)
                            
                            // Google Butonu
                            Button(action: {
                                if !isGoogleLinked { linkGoogleAccount() }
                            }) {
                                SocialLinkRow(
                                    icon: "g.circle.fill",
                                    title: "Google Hesabı",
                                    subtitle: isGoogleLinked ? "Bağlı" : "Bağlamak İçin Dokun",
                                    color: .red,
                                    isLinked: isGoogleLinked
                                )
                            }
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 4. Güvenlik Yönetimi (Çıkış İşlemleri)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GÜVENLİK YÖNETİMİ")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                            .padding(.leading, 10)
                        
                        Button(action: {
                            showSignOutAlert = true
                        }) {
                            HStack(spacing: 15) {
                                Image(systemName: "iphone.and.arrow.forward")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .frame(width: 35, height: 35)
                                    .background(Color.red.opacity(0.8).cornerRadius(10))
                                
                                Text("Tüm Cihazlardan Çıkış Yap")
                                    .fontWeight(.medium)
                                    .foregroundColor(.red)
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 15)
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                }
                .padding()
                .padding(.top, 10)
            }
        }
        .navigationTitle("Şifre ve Güvenlik")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(selectedTheme.colorScheme)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Bitti") { dismiss() }
                    .fontWeight(.bold)
            }
        }
        // Ekran açıldığında bağlı hesapları kontrol et
        .onAppear {
            checkLinkedProviders()
        }
        // Çıkış Yapma Onay Penceresi
        .alert(isPresented: $showSignOutAlert) {
            Alert(
                title: Text("Çıkış Yap"),
                message: Text("Hesabınızdan çıkış yapmak istediğinize emin misiniz?"),
                primaryButton: .destructive(Text("Çıkış Yap")) {
                    performSignOut()
                },
                secondaryButton: .cancel(Text("İptal"))
            )
        }
    }
    
    // MARK: - Bağlı Hesapların Kontrolü
    private func checkLinkedProviders() {
        guard let user = Auth.auth().currentUser else { return }
        
        let linkedProviders = user.providerData.map { $0.providerID }
        
        isGoogleLinked = linkedProviders.contains("google.com")
        isAppleLinked = linkedProviders.contains("apple.com")
    }
    
    // MARK: - Google Hesabı Bağlama
    private func linkGoogleAccount() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            print("Hata: Firebase ClientID bulunamadı.")
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else {
            print("Hata: RootViewController bulunamadı.")
            return
        }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("Google girişi iptal edildi veya bir hata oluştu: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                print("Hata: Google kimlik doğrulama bilgileri alınamadı.")
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            Auth.auth().currentUser?.link(with: credential) { authResult, linkError in
                if let linkError = linkError {
                    print("Hesap bağlama işlemi başarısız oldu: \(linkError.localizedDescription)")
                } else {
                    print("Google hesabı başarıyla bağlandı.")
                    
                    withAnimation(.spring()) {
                        self.isGoogleLinked = true
                    }
                }
            }
        }
    }
    
    // MARK: - Apple Hesabı Bağlama (Geliştirme Aşamasında)
    private func linkAppleAccount() {
        print("Apple hesabı bağlama işlemi başlatıldı.")
        // Apple Sign In entegrasyonu buraya eklenecektir.
    }
    
    // MARK: - Güvenli Çıkış İşlemi
    private func performSignOut() {
        do {
            try Auth.auth().signOut()
            print("Başarıyla çıkış yapıldı.")
            dismiss()
        } catch let error as NSError {
            print("Çıkış işlemi sırasında hata oluştu: \(error.localizedDescription)")
        }
    }
    
    // Dinamik Arka Plan
    var dynamicBackground: some View {
        Group {
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

// Sosyal Hesap Satırı Bileşeni
struct SocialLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let isLinked: Bool
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)
                .frame(width: 35, height: 35)
                .background(color.cornerRadius(10))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(isLinked ? .green : .gray)
            }
            
            Spacer()
            
            Image(systemName: isLinked ? "checkmark.circle.fill" : "link.badge.plus")
                .foregroundColor(isLinked ? .green : .blue)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(isLinked ? Color.clear : Color.blue.opacity(0.02))
    }
}
