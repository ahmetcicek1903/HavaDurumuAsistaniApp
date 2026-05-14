import SwiftUI
import FirebaseAuth

struct ChangePasswordView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    // VERİLER
    @State private var oldPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    
    // İKAZ LAMBALARI (Kurumsal Uyarı Mesajları İçin)
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false // Başarılıysa sayfayı kapatmak için
    
    var isFormValid: Bool {
        !oldPassword.isEmpty && !newPassword.isEmpty && !confirmPassword.isEmpty && (newPassword == confirmPassword)
    }
    
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    
                    // --- YENİ KURUMSAL İKAZ TABELASI ---
                    if showAlert {
                        HStack(spacing: 12) {
                            Image(systemName: isSuccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                .font(.title2)
                            Text(alertMessage)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Spacer()
                        }
                        .foregroundColor(isSuccess ? .green : .red)
                        .padding()
                        .background(isSuccess ? Color.green.opacity(0.15) : Color.red.opacity(0.15))
                        .cornerRadius(15)
                        .overlay(RoundedRectangle(cornerRadius: 15).stroke(isSuccess ? Color.green.opacity(0.3) : Color.red.opacity(0.3), lineWidth: 1))
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                    // ------------------------------------
                    
                    // 1. GÜVENLİK DOĞRULAMASI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GÜVENLİK DOĞRULAMASI").font(.caption2).fontWeight(.bold).foregroundColor(.secondary).padding(.leading, 10)
                        
                        VStack {
                            PasswordToggleField(label: "Mevcut Şifre", text: $oldPassword, icon: "lock.shield.fill")
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 2. YENİ ŞİFRE BELİRLEME
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YENİ ŞİFRE BELİRLE").font(.caption2).fontWeight(.bold).foregroundColor(.secondary).padding(.leading, 10)
                        
                        VStack(spacing: 0) {
                            PasswordToggleField(label: "Yeni Şifre", text: $newPassword, icon: "key.fill")
                            Divider().padding(.leading, 45)
                            PasswordToggleField(label: "Şifre Tekrar", text: $confirmPassword, icon: "key.fill")
                        }
                        .modifier(DynamicGlassCard())
                        
                        Text("Şifreniz en az 6 karakter olmalı.")
                            .font(.caption).foregroundColor(.secondary).padding(.horizontal, 10)
                    }
                    
                    // 3. GÜNCELLE BUTONU (FİREBASE BEYNİNE BAĞLI)
                    Button(action: {
                        updatePasswordInFirebase()
                    }) {
                        Text("Şifreyi Güncelle")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: !isFormValid ? [.gray] : [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .orange.opacity(!isFormValid ? 0 : 0.3), radius: 10, y: 5)
                    }
                    .disabled(!isFormValid)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .navigationTitle("Şifreyi Güncelle")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(selectedTheme.colorScheme)
    }
    
    var dynamicBackground: some View {
        selectedTheme == .koyu ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
    
    // MARK: - FİREBASE BEYİN AMELİYATI (MEVCUT ŞİFRE KONTROLÜ VE HATA ÇEVİRİSİ)
    private func updatePasswordInFirebase() {
        guard let user = Auth.auth().currentUser, let email = user.email else { return }
        
        // 1. Önce eski şifrenin doğru olup olmadığını teyit ediyoruz (Re-authenticate)
        let credential = EmailAuthProvider.credential(withEmail: email, password: oldPassword)
        
        user.reauthenticate(with: credential) { authResult, error in
            if let error = error {
                let errorCode = (error as NSError).code
                withAnimation(.spring()) {
                    if errorCode == AuthErrorCode.wrongPassword.rawValue {
                        alertMessage = "MEVCUT ŞİFRENİZ HATALIDIR."
                    } else {
                        alertMessage = "DOĞRULAMA BAŞARISIZ OLDU. LÜTFEN TEKRAR DENEYİNİZ."
                    }
                    isSuccess = false
                    showAlert = true
                }
                return
            }
            
            // 2. Eski şifre doğruysa, yeni şifreyi beyne yazdır
            user.updatePassword(to: newPassword) { updateError in
                withAnimation(.spring()) {
                    if let updateError = updateError {
                        let errorCode = (updateError as NSError).code
                        if errorCode == AuthErrorCode.weakPassword.rawValue {
                            alertMessage = "YENİ ŞİFRENİZ ÇOK ZAYIF. EN AZ 6 KARAKTER OLMALIDIR."
                        } else {
                            alertMessage = "ŞİFRE GÜNCELLENEMEDİ. LÜTFEN TEKRAR DENEYİNİZ."
                        }
                        isSuccess = false
                        showAlert = true
                    } else {
                        // İşlem cillop gibi tamamlandı
                        alertMessage = "ŞİFRENİZ BAŞARIYLA GÜNCELLENMİŞTİR."
                        isSuccess = true
                        showAlert = true
                        
                        // Kalan şifreleri temizle
                        oldPassword = ""
                        newPassword = ""
                        confirmPassword = ""
                        
                        // 2 Saniye sonra ekranı kapat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

// MARK: - GÖZ BUTONLU ÖZEL ŞİFRE GİRİŞ KARTI
struct PasswordToggleField: View {
    let label: String
    @Binding var text: String
    let icon: String
    
    // Göz açık mı kapalı mı?
    @State private var isSecured: Bool = true
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.orange)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundColor(.gray)
                
                // Göz durumuna göre SecureField veya TextField göster
                if isSecured {
                    SecureField("", text: $text)
                        .foregroundColor(.primary)
                } else {
                    TextField("", text: $text)
                        .foregroundColor(.primary)
                }
            }
            
            Spacer()
            
            // GÖZ BUTONU
            Button(action: {
                isSecured.toggle()
            }) {
                Image(systemName: isSecured ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .padding()
    }
}
