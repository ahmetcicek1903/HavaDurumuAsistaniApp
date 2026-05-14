import SwiftUI
import FirebaseAuth

struct ChangeEmailView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    // VERİLER
    @State private var currentEmail = Auth.auth().currentUser?.email ?? "Bilinmiyor"
    @State private var newEmail = ""
    @State private var passwordForAuth = "" // Şifre kontrolü için şart!
    
    // YOL BİLGİSAYARI İKAZ LAMBALARI (Kurumsal Tabelalar İçin)
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isSuccess = false
    
    // Göz butonu için durum
    @State private var isPasswordSecured = true

    var isFormValid: Bool {
        !newEmail.isEmpty && newEmail.contains("@") && !passwordForAuth.isEmpty
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
                    
                    // 1. MEVCUT DURUM KARTI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MEVCUT HESAP").font(.caption2).fontWeight(.bold).foregroundColor(.secondary).padding(.leading, 10)
                        
                        HStack(spacing: 15) {
                            Image(systemName: "envelope.badge.shield.half.filled").foregroundColor(.blue)
                            Text(currentEmail).foregroundColor(.secondary).italic()
                            Spacer()
                        }
                        .padding()
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 2. DOĞRULAMA VE YENİ BİLGİ KARTI
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GÜVENLİK VE YENİ ADRES").font(.caption2).fontWeight(.bold).foregroundColor(.secondary).padding(.leading, 10)
                        
                        VStack(spacing: 0) {
                            // Yeni E-posta
                            InfoInputField(label: "Yeni E-Posta Adresi", text: $newEmail, icon: "envelope.fill", keyboard: .emailAddress)
                            
                            Divider().padding(.leading, 45)
                            
                            // Mevcut Şifre (Doğrulama için)
                            HStack(spacing: 15) {
                                Image(systemName: "lock.fill").foregroundColor(.orange).frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Mevcut Şifreniz").font(.caption2).foregroundColor(.gray)
                                    if isPasswordSecured {
                                        SecureField("", text: $passwordForAuth)
                                    } else {
                                        TextField("", text: $passwordForAuth)
                                    }
                                }
                                Button(action: { isPasswordSecured.toggle() }) {
                                    Image(systemName: isPasswordSecured ? "eye.slash.fill" : "eye.fill").foregroundColor(.gray)
                                }
                            }
                            .padding()
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 3. GÜNCELLE BUTONU
                    Button(action: {
                        updateEmailInFirebase()
                    }) {
                        Text("E-Posta Adresini Güncelle")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: !isFormValid ? [.gray] : [.blue, .cyan],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(!isFormValid ? 0 : 0.3), radius: 10, y: 5)
                    }
                    .disabled(!isFormValid)
                    .padding(.top, 10)
                }
                .padding()
            }
        }
        .navigationTitle("E-Posta Değiştir")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(selectedTheme.colorScheme)
    }
    
    var dynamicBackground: some View {
        selectedTheme == .koyu ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
    
    // MARK: - FİREBASE BEYİN AMELİYATI (HATA ÇEVİRİCİLİ)
    private func updateEmailInFirebase() {
        guard let user = Auth.auth().currentUser, let oldEmail = user.email else { return }
        
        // 1. ADIM: Önce şifreyle "Ben buyum" diyoruz (Re-authentication)
        let credential = EmailAuthProvider.credential(withEmail: oldEmail, password: passwordForAuth)
        
        user.reauthenticate(with: credential) { _, error in
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
            
            // 2. ADIM: Şifre doğruysa e-postayı beyne yazdır
            user.updateEmail(to: newEmail) { updateError in
                withAnimation(.spring()) {
                    if let updateError = updateError {
                        let errorCode = (updateError as NSError).code
                        // Özel Hata Yakalayıcılar
                        if errorCode == AuthErrorCode.invalidEmail.rawValue {
                            alertMessage = "GİRDİĞİNİZ E-POSTA ADRESİ GEÇERSİZDİR."
                        } else if errorCode == AuthErrorCode.emailAlreadyInUse.rawValue {
                            alertMessage = "BU E-POSTA ADRESİ BAŞKA BİR HESAP TARAFINDAN KULLANILMAKTADIR."
                        } else {
                            alertMessage = "E-POSTA GÜNCELLENEMEDİ. LÜTFEN TEKRAR DENEYİNİZ."
                        }
                        isSuccess = false
                        showAlert = true
                    } else {
                        // 3. ADIM: Doğrulama maili gönder ve başarı mesajını yak!
                        user.sendEmailVerification()
                        
                        alertMessage = "E-POSTA ADRESİNİZ GÜNCELLENMİŞTİR. ONAY MAİLİ GÖNDERİLDİ."
                        isSuccess = true
                        showAlert = true
                        
                        // Ortalığı temizle
                        passwordForAuth = ""
                        newEmail = ""
                        
                        // 2.5 Saniye sonra sayfayı süzülerek kapat
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
