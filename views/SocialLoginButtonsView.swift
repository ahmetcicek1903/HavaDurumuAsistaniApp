import SwiftUI
import FirebaseAuth
import GoogleSignIn
import FirebaseCore

struct SocialLoginButtonsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 16) { // Butonlar arası mesafe biraz daha açıldı
            
            // APPLE GİRİŞ BUTONU (Kurumsal Outlined Tasarım)
            Button(action: {
                print("Apple ID entegrasyonu hazırlık aşamasındadır.")
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 20))
                    Text("Apple ile Giriş Yap")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 55) // Genişlik ve yükseklik artırıldı
                .background(Color.white.opacity(0.05))
                .cornerRadius(15)
                .overlay(
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
                )
            }
            
            // GOOGLE GİRİŞ BUTONU (Orijinal Renkli Tasarım)
            Button(action: {
                signInWithGoogle()
            }) {
                HStack(spacing: 12) {
                    // Google'ın orijinal renklerini SF Symbols üzerinden ateşliyoruz
                    Image(systemName: "g.circle.fill")
                        .symbolRenderingMode(.multicolor) // İşte o renkler burada başkan!
                        .font(.system(size: 22))
                        .background(Color.white.clipShape(Circle())) // Logonun arkası temiz dursun
                        
                    Text("Google ile Giriş Yap")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black) // Google butonu genelde açık renk ferah durur
                }
                .frame(maxWidth: .infinity)
                .frame(height: 55) // Sütunlar genişletildi
                .background(Color.white) // Google butonu orijinal beyaz zeminine kavuştu
                .cornerRadius(15)
                .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
        }
        .padding(.horizontal, 20) // Kenarlardan biraz daha yayılması sağlandı
    }
    
    // MARK: - Google Kimlik Doğrulama Mantığı
    private func signInWithGoogle() {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            return
        }
        
        let config = GIDConfiguration(clientID: clientID)
        GIDSignIn.sharedInstance.configuration = config
        
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let rootViewController = window.rootViewController else { return }
        
        GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { result, error in
            if let error = error {
                print("Hata: \(error.localizedDescription)")
                return
            }
            
            guard let user = result?.user,
                  let idToken = user.idToken?.tokenString else {
                return
            }
            
            let accessToken = user.accessToken.tokenString
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            
            Auth.auth().signIn(with: credential) { authResult, error in
                if let error = error {
                    print("Firebase Hatası: \(error.localizedDescription)")
                } else {
                    print("Giriş Başarılı: \(authResult?.user.email ?? "")")
                }
            }
        }
    }
}
