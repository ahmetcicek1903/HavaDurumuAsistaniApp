import SwiftUI
import FirebaseAuth

struct AuthView: View {
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var errorMessage = ""
    @State private var showAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Arka Plan
                LinearGradient(colors: [.black, Color(red: 0.05, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
                
                ScrollView { // Ekran kayabilsin ki butonlar altta kalmasın
                    VStack(spacing: 25) {
                        Spacer(minLength: 50)
                        
                        // Logo
                        Image(systemName: "cloud.sun.bolt.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .symbolRenderingMode(.multicolor)
                        
                        VStack(spacing: 8) {
                            Text(isSignUp ? "Yeni Hesap Aç" : "Tekrar Hoş Geldin")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(.white)
                            
                            Text(isSignUp ? "Hava durumunu takip etmek için hemen katıl." : "Kral kaldığın yerden devam ediyoruz.")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        VStack(spacing: 15) {
                            // Email
                            HStack {
                                Image(systemName: "envelope").foregroundColor(.gray)
                                TextField("", text: $email, prompt: Text("E-posta").foregroundColor(.gray))
                                    .foregroundColor(.white)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .cornerRadius(12)
                            
                            // Şifre
                            HStack {
                                Image(systemName: "lock").foregroundColor(.gray)
                                SecureField("", text: $password, prompt: Text("Şifre").foregroundColor(.gray))
                                    .foregroundColor(.white)
                            }
                            .padding()
                            .background(.white.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        
                        // ANA BUTON (GİRİŞ / KAYIT)
                        Button(action: handleAuth) {
                            Text(isSignUp ? "KAYIT OL VE BAŞLA" : "GİRİŞ YAP")
                                .fontWeight(.bold)
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(color: .white.opacity(0.2), radius: 5)
                        }
                        .padding(.horizontal)
                        
                        // ŞIFRE SIFIRLAMA (Sadece Giriş Modunda)
                        if !isSignUp {
                            Button("Şifremi unuttum, yardım et reis") {
                                resetPassword()
                            }
                            .foregroundColor(.blue.opacity(0.8))
                            .font(.footnote)
                        }
                        
                        Spacer(minLength: 20)
                        
                        // MOD DEĞİŞTİRME BUTONU (BURASI ÇOK ÖNEMLİ)
                        Button(action: {
                            withAnimation(.spring()) {
                                isSignUp.toggle()
                            }
                        }) {
                            HStack {
                                Text(isSignUp ? "Zaten hesabın var mı?" : "Henüz hesabın yok mu?")
                                    .foregroundColor(.white.opacity(0.7))
                                Text(isSignUp ? "Giriş Yap" : "Kayıt Ol Reis")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                            }
                            .font(.subheadline)
                        }
                        .padding(.bottom, 30)
                    }
                    .padding()
                }
            }
            .alert("Durum", isPresented: $showAlert) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // --- FIREBASE FONKSİYONLARI (AYNI KALDI) ---
    func handleAuth() {
        if isSignUp {
            Auth.auth().createUser(withEmail: email, password: password) { result, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showAlert = true
                } else {
                    errorMessage = "Hesabın başarıyla açıldı kral! Şimdi giriş yapabilirsin."
                    showAlert = true
                    isSignUp = false
                }
            }
        } else {
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    errorMessage = error.localizedDescription
                    showAlert = true
                }
            }
        }
    }
    
    func resetPassword() {
        guard !email.isEmpty else {
            errorMessage = "Önce e-postanı yazman lazım başkan."
            showAlert = true
            return
        }
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            errorMessage = error?.localizedDescription ?? "Şifre sıfırlama linki e-postana uçuruldu!"
            showAlert = true
        }
    }
}
#Preview{
    AuthView()
}
