import SwiftUI
import FirebaseAuth

struct PersonalInfoView: View {
    @Environment(\.dismiss) var dismiss
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    // VERİLER (İçi boş başlıyor, ekran açılınca Firebase dolduracak)
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var phone = ""

    @State private var originalFirstName = ""
        @State private var originalLastName = ""
        @State private var originalPhone = ""
        
        // DEĞİŞİM SENSÖRÜ (Eski ile yeni veriyi karşılaştırır)
    private var hasChanges: Bool {
        firstName != originalFirstName ||
        lastName != originalLastName ||
        phone != originalPhone
    }
    var body: some View {
        ZStack {
            dynamicBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    
                    // --- YENİ EKLENEN PROFİL FOTOĞRAFI MOTORU ---
                    if let user = Auth.auth().currentUser, let photoURL = user.photoURL {
                        AsyncImage(url: photoURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            ProgressView()
                        }
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 3))
                        .shadow(color: .blue.opacity(0.3), radius: 10)
                        .padding(.top, 10)
                    } else {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                            .padding(.top, 10)
                    }
                    // ---------------------------------------------
                    
                    // 1. KİMLİK BİLGİLERİ KARTI
                    VStack(alignment: .leading, spacing: 15) {
                        Text("KİMLİK BİLGİLERİ")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                        
                        VStack(spacing: 0) {
                            InfoInputField(label: "Ad", text: $firstName, icon: "person.fill")
                            Divider().padding(.leading, 45)
                            InfoInputField(label: "Soyad", text: $lastName, icon: "person.fill")
                        }
                        .modifier(DynamicGlassCard()) // Senin kendi tasarımın duruyor
                    }
                    
                    // 2. İLETİŞİM BİLGİLERİ KARTI
                    VStack(alignment: .leading, spacing: 15) {
                        Text("İLETİŞİM BİLGİLERİ")
                            .font(.caption2).fontWeight(.bold).foregroundColor(.secondary)
                        
                        VStack(spacing: 0) {
                            // E-posta kutusu kilitlendi (Sadece okuma amaçlı)
                            InfoInputField(label: "E-Posta", text: $email, icon: "envelope.fill", keyboard: .emailAddress)
                                .disabled(true)
                                .opacity(0.7) // Kilitli olduğunu belli etmek için biraz soluklaştırdık
                            Divider().padding(.leading, 45)
                            InfoInputField(label: "Telefon", text: $phone, icon: "phone.fill", keyboard: .phonePad)
                        }
                        .modifier(DynamicGlassCard())
                    }
                    
                    // 3. KAYDET BUTONU
                    Button(action: {
                        guard let user = Auth.auth().currentUser else { return }
                        
                        let fullName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
                        let changeRequest = user.createProfileChangeRequest()
                        changeRequest.displayName = fullName
                        
                        changeRequest.commitChanges { error in
                            if let error = error {
                                print("Hata oluştu başkan: \(error.localizedDescription)")
                            } else {
                                print("İsim başarıyla güncellendi: \(fullName)")
                                dismiss() // Güncelleme bitince ekranı kapatır
                            }
                        }
                    }) {
                        Text("Değişiklikleri Kaydet")
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing))
                            .cornerRadius(15)
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                    }
                    .padding(.top, 10)
                    .disabled(!hasChanges) // Değişiklik yoksa butonu kilitler
                    .opacity(hasChanges ? 1.0 : 0.5) // Değişiklik yoksa soluk gösterir
                }
                .padding()
            }
        }
        .navigationTitle("Kişisel Bilgiler")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(selectedTheme.colorScheme)
        
        // EKRAN AÇILDIĞINDA BEYİNDEN (FIREBASE) VERİLERİ ÇEKME İŞLEMİ
        .onAppear {
            if let user = Auth.auth().currentUser {
                self.email = user.email ?? ""
                self.phone = user.phoneNumber ?? ""
                self.originalPhone = self.phone // Kopyasını aldık
                
                if let fullName = user.displayName {
                    let components = fullName.components(separatedBy: " ")
                    if components.count > 1 {
                        self.lastName = components.last ?? ""
                        self.firstName = components.dropLast().joined(separator: " ")
                    } else {
                        self.firstName = fullName
                        self.lastName = ""
                    }
                }
                // İsimlerin de kopyasını aldık
                self.originalFirstName = self.firstName
                self.originalLastName = self.lastName
            }
        }
    }
        
    var dynamicBackground: some View {
        selectedTheme == .koyu ? Color.black : Color(uiColor: .systemGroupedBackground)
    }
}


// Özel Giriş Alanı Bileşeni (Senin Kodun)
struct InfoInputField: View {
    let label: String
    @Binding var text: String
    let icon: String
    var keyboard: UIKeyboardType = .default
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption2).foregroundColor(.gray)
                TextField("HENÜZ BİLGİ GİRİLMEDİ", text: $text)
                    .foregroundColor(.primary)
                    .keyboardType(keyboard)
            }   
        }
        .padding()
    }
}
