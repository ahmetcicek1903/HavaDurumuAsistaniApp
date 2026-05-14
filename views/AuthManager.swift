import Foundation
import FirebaseAuth
import Combine

// MARK: - KİMLİK DOĞRULAMA YÖNETİCİSİ
// Kullanıcının giriş yapma, kayıt olma ve çıkış yapma işlemlerini yöneten ana beyin.
class AuthManager: ObservableObject {
    
    // Kullanıcının anlık oturum durumunu tutar. Değiştiğinde arayüzü otomatik günceller.
    @Published var userSession: FirebaseAuth.User?
    
    // Uygulamanın her yerinden aynı hafızaya erişebilmek için tekil (singleton) yapı.
    static let shared = AuthManager()
    
    init() {
        // Uygulama her açıldığında cihazda kayıtlı bir oturum var mı diye kontrol eder.
        self.userSession = Auth.auth().currentUser
    }
    
    // MARK: - ÇIKIŞ İŞLEMİ
    func signOut() {
        do {
            try Auth.auth().signOut()
            self.userSession = nil
            print("Ahmet başkan, çıkış yapıldı!")
        } catch {
            print("Çıkış yaparken bir arıza çıktı kral: \(error.localizedDescription)")
        }
    }
    
    // MARK: - GİRİŞ İŞLEMİ (LOG IN)
    func signIn(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Giriş başarısız Ahmet başkan: \(error.localizedDescription)")
                // Hata durumunda ileride ekrana uyarı basılabilir.
                return
            }
            
            // Giriş başarılıysa arka plandaki oturum bilgisini günceller.
            DispatchQueue.main.async {
                self.userSession = result?.user
                print("Giriş başarılı! Hoş geldin \(result?.user.email ?? "Başkan")")
            }
        }
    }
    
    // MARK: - KAYIT İŞLEMİ (SIGN UP)
    func signUp(email: String, password: String) {
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error {
                print("Kayıt olamadık başkan: \(error.localizedDescription)")
                return
            }
            // Kayıt başarılıysa kullanıcıyı direkt içeri alır.
            DispatchQueue.main.async {
                self.userSession = result?.user
            }
        }
    }
}
