import SwiftUI
import FirebaseAuth

// MARK: - GİRİŞ VE KAYIT EKRANI
// Kullanıcıyı karşılayan, e-posta/şifre ile veya sosyal ağlarla giriş yapılan ana vitrin.
struct LoginView: View {
    // MARK: - DEĞİŞKENLER
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    @StateObject private var authManager = AuthManager.shared
    
    // Kullanıcı girdileri ve arayüz durumları
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false // true ise Kayıt ekranı, false ise Giriş ekranı olur.
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    // MARK: - ANA GÖRÜNÜM (BODY)
    var body: some View {
        // Tanıtım ekranı bitmişse giriş ekranını göster.
        if isOnboardingCompleted {
            ZStack {
                // Arka plan renk geçişi
                backgroundLayer
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 40) {
                        // Üst kısımdaki ikon ve başlık
                        headerSection
                        
                        // E-posta ve şifre giriş kutuları
                        inputSection
                        
                        // Şifremi unuttum ve Giriş/Kayıt butonu
                        actionSection
                        
                        // Google ve Apple giriş butonları
                        SocialLoginButtonsView()
                            .padding(.top, 10)
                        
                        // En alttaki "Hesabın yok mu? Kayıt ol" geçiş yazısı
                        footerSection
                    }
                    .padding(.horizontal, 25)
                    .padding(.top, 60)
                }
            }
            // Hata veya bilgi mesajlarını gösteren pencere
            .alert("Bilgilendirme", isPresented: $showAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(alertMessage)
            }
        } else {
            // Tanıtım ekranı bitmemişse Oraya yönlendir.
            OnboardingView()
        }
    }
}

// MARK: - ARAYÜZ PARÇALARI (GÖRSEL BİLEŞENLER)
private extension LoginView {
    
    // Koyu temalı arkaplan rengi
    var backgroundLayer: some View {
        LinearGradient(
            colors: [Color(red: 0.05, green: 0.08, blue: 0.15), .black],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
    
    // Logo ve Hoş Geldin metinleri
    var headerSection: some View {
        VStack(spacing: 20) {
            // Duruma göre (Kayıt/Giriş) değişen ana ikon
            Image(systemName: isSignUp ? "person.badge.plus" : "cloud.sun.bolt.fill")
                .font(.system(size: 70))
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.blue, .white)
                .shadow(color: .blue.opacity(0.3), radius: 15, x: 0, y: 10)
                .contentTransition(.symbolEffect(.replace)) // İkon değişirken yumuşak geçiş yapar
            
            VStack(spacing: 8) {
                Text(isSignUp ? "Hesap Oluştur" : "Hoş Geldiniz")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                
                Text(isSignUp ? "Hava durumunu takip etmek için kayıt olun." : "Lütfen bilgilerinizi kullanarak giriş yapın.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // E-posta ve şifre kutuları
    var inputSection: some View {
        VStack(spacing: 16) {
            CustomTextField(icon: "envelope.fill", placeholder: "E-posta Adresi", text: $email)
                .keyboardType(.emailAddress)
            
            CustomSecureField(icon: "lock.fill", placeholder: "Şifre", text: $password)
        }
    }
    
    // Ana işlem butonları (Giriş Yap / Şifremi Unuttum)
    var actionSection: some View {
        VStack(spacing: 20) {
            // Sadece giriş ekranında şifremi unuttum yazısı çıkar
            if !isSignUp {
                Button(action: resetPasswordAction) {
                    Text("Şifrenizi mi unuttunuz?")
                        .font(.footnote)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            
            // Ana tetikleyici buton
            Button(action: authenticateUser) {
                Text(isSignUp ? "Kayıt Ol" : "Giriş Yap")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                            .shadow(color: .blue.opacity(0.4), radius: 8, x: 0, y: 4)
                    )
            }
        }
    }
    
    // Ekranlar arası (Giriş <-> Kayıt) geçişi sağlayan alt bölüm
    var footerSection: some View {
        Button(action: {
            withAnimation(.easeInOut) {
                isSignUp.toggle()
            }
        }) {
            HStack(spacing: 5) {
                Text(isSignUp ? "Zaten bir hesabınız var mı?" : "Henüz bir hesabınız yok mu?")
                    .foregroundColor(.secondary)
                Text(isSignUp ? "Giriş Yapın" : "Hesap Oluşturun")
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            .font(.footnote)
        }
        .padding(.bottom, 20)
    }
}

// MARK: - MANTIKSAL İŞLEMLER (FONKSİYONLAR)
private extension LoginView {
    
    // Form kontrolü ve AuthManager'a veriyi gönderme
    func authenticateUser() {
        guard !email.isEmpty, !password.isEmpty else {
            alertMessage = "Lütfen tüm alanları eksiksiz doldurunuz."
            showAlert = true
            return
        }
        
        if isSignUp {
            authManager.signUp(email: email, password: password)
        } else {
            authManager.signIn(email: email, password: password)
        }
    }
    
    // Şifre sıfırlama e-postası gönderme
    func resetPasswordAction() {
        guard !email.isEmpty else {
            alertMessage = "Lütfen geçerli bir e-posta adresi giriniz."
            showAlert = true
            return
        }
        
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            if let error = error {
                alertMessage = error.localizedDescription
            } else {
                alertMessage = "Şifre sıfırlama bağlantısı e-posta adresinize başarıyla gönderildi."
            }
            showAlert = true
        }
    }
}

// MARK: - ÖZEL GİRİŞ KUTULARI (TASARIM BİLEŞENLERİ)

// Standart metin/eposta giriş kutusu
struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 18))
                .frame(width: 24)
            
            TextField(placeholder, text: $text)
                .foregroundColor(.white)
                .font(.body)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never) // E-postada ilk harfin büyük başlamasını engeller
            
            // İçinde yazı varsa temizleme (X) butonu çıkar
            if !text.isEmpty {
                Button(action: { text = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}

// Şifre giriş kutusu (Göz ikonu ile gizle/göster özelliği var)
struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var isVisible = false // Şifre görünürlük durumu
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 18))
                .frame(width: 24)
            
            Group {
                if isVisible {
                    TextField(placeholder, text: $text)
                } else {
                    SecureField(placeholder, text: $text)
                }
            }
            .foregroundColor(.white)
            .font(.body)
            
            // Gizle/Göster butonu
            Button(action: { isVisible.toggle() }) {
                Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
}
