import SwiftUI

// MARK: - 1. UYGULAMA TANITIM EKRANI (ONBOARDING)
// Kullanıcı uygulamayı ilk kez açtığında onu karşılayan ve uygulamanın özelliklerini anlatan şov sayfası.

struct OnboardingView: View {
    // Kullanıcının bu tanıtımı daha önce görüp görmediğini telefon hafızasına (AppStorage) kazırız.
    // True olduğunda bir daha bu sayfa açılmaz, direkt ana ekrana geçer.
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    
    // Şu an hangi sayfada olduğumuzu takip eder (0, 1, 2)
    @State private var currentPage = 0
    
    // MARK: - SAYFA İÇERİKLERİ
    // Ekranda gösterilecek 3 farklı tanıtım sayfasının başlıklarını, yazılarını ve renk efektlerini buradan ayarlıyoruz.
    let onboardingSteps = [
        OnboardingStep(
            view: { AnyView(OnboardingCityCardView()) },
            title: "ANLIK HAVA DURUMU",
            description: "DÜNYANIN HER YERİNDEN EN GÜNCEL VERİLERİ VE DETAYLI TAHMİNLERİ TAKİP EDİN.",
            glowColor: .blue
        ),
        OnboardingStep(
            view: { AnyView(OnboardingAlertView()) },
            title: "ANLIK UYARILAR",
            description: "TEHLİKELİ HAVA DURUMLARINDAN ANINDA HABERDAR OLUN VE ÖNLEMİNİZİ ALIN.",
            glowColor: .red
        ),
        OnboardingStep(
            view: { AnyView(OnboardingAccountRowView()) },
            title: "GÜVENLİ HESAP",
            description: "FAVORİ ŞEHİRLERİNİZİ VE AYARLARINIZI BULUTTA GÜVENLE SAKLAYIN.",
            glowColor: .purple
        )
    ]
    
    var body: some View {
        ZStack {
            // Arka plan: Koyu temaya uygun, aşağıya doğru hafifçe kararan derinlik efekti (Gradient)
            LinearGradient(colors: [Color(red: 0.08, green: 0.08, blue: 0.15), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack {
                // MARK: - ATLA BUTONU
                // Sağ üstte duran ve tanıtımı direkt geçmeye yarayan düğme.
                HStack {
                    Spacer()
                    Button(action: {
                        isOnboardingCompleted = true // Şalteri kapat, ana ekrana uç!
                    }) {
                        Text("ATLA")
                            .font(.subheadline)
                            .fontWeight(.black)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(Color.white.opacity(0.08))) // Şeffaf hap (capsule) arka plan
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
                
                // MARK: - KAYDIRILABİLİR (SWIPE) SAYFALAR
                // Kullanıcının sağa sola kaydırdığı (veya butona basarak geçtiği) ana vitrin alanı.
                TabView(selection: $currentPage) {
                    ForEach(0..<onboardingSteps.count, id: \.self) { index in
                        OnboardingStepView(step: onboardingSteps[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always)) // Alt kısımdaki klasik noktaları göster
                
                // MARK: - İLERİ / BAŞLA BUTONU
                // Alt kısımda yer alan dev buton. Son sayfaya gelindiğinde ismi "BAŞLAYALIM" olarak değişir.
                Button(action:  {
                    // Eğer son sayfada değilsek bir sonraki sayfaya yaylanarak (spring) geç.
                    if currentPage < onboardingSteps.count - 1 {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            currentPage += 1
                        }
                    } else {
                        // Son sayfadaysak tanıtımı bitir ve uygulamayı aç.
                        isOnboardingCompleted = true
                    }
                }) {
                    Text(currentPage == onboardingSteps.count - 1 ? "BAŞLAYALIM" : "İLERİ")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(
                            RoundedRectangle(cornerRadius: 18)
                                .fill(LinearGradient(colors: [.blue, Color(red: 0.0, green: 0.4, blue: 0.9)], startPoint: .top, endPoint: .bottom))
                                .shadow(color: .blue.opacity(0.4), radius: 15, x: 0, y: 8)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 50)
            }
        }
    }
}

// MARK: - 2. TEKİL SAYFA TASARIMI (3D CAM EFEKTİ)
// Yukarıdaki TabView içinde dönen her bir tanıtım sayfasının şablonudur.
struct OnboardingStepView: View {
    let step: OnboardingStep
    
    var body: some View {
        VStack(spacing: 40) {
            ZStack {
                // Arkadan vuran renkli neon ışık efekti (Bulanık daire)
                Circle()
                    .fill(step.glowColor.opacity(0.25))
                    .frame(width: 320, height: 320)
                    .blur(radius: 50)
                
                // Öndeki uygulama görseli (Kart, Uyarı vs.)
                // Burada uygulanan .rotation3DEffect ile kartlar hafif yan durur, 3 boyutlu "premium" bir hava katar.
                step.view()
                    .frame(width: 270, height: 270)
                    .padding(25)
                    .background(.ultraThinMaterial) // Buzlu cam efekti
                    .cornerRadius(45)
                    .shadow(color: step.glowColor.opacity(0.4), radius: 30, x: 0, y: 15)
                    .rotation3DEffect(.degrees(12), axis: (x: 1, y: -0.5, z: 0))
                    .overlay(
                        RoundedRectangle(cornerRadius: 45)
                            .stroke(LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                    )
            }
            .padding(.top, 40)
            
            // MARK: - BAŞLIK VE AÇIKLAMA METİNLERİ
            VStack(spacing: 18) {
                Text(step.title)
                    .font(.system(size: 28, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text(step.description)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 40)
                    .lineSpacing(6)
            }
            
            Spacer()
        }
    }
}

// Onboarding sayfasının verilerini tutan basit bir kalıp
struct OnboardingStep {
    let view: () -> AnyView
    let title: String
    let description: String
    let glowColor: Color
}

// MARK: - 3. KÜÇÜK GÖRSEL MOCKUPLARI (ÖRNEK KARTLAR)
// Bu kısımdaki kartlar tamamen görsel şov amaçlıdır, gerçek veri çekmezler. Sadece tanıtım içindir.

// 1. Ekran: Örnek Hava Durumu Kartı (Memleketi düzelttik!)
struct OnboardingCityCardView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KAHRAMANMARAŞ").font(.title3).fontWeight(.black)
                    Text("Parçalı Bulutlu").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Image(systemName: "cloud.sun.fill").symbolRenderingMode(.multicolor).font(.system(size: 45))
            }
            Divider().background(.white.opacity(0.2))
            HStack(alignment: .bottom) {
                Text("24°C").font(.system(size: 48, weight: .black))
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Nem: %60").font(.caption2)
                    Text("Rüzgar: 12 km/s").font(.caption2)
                }.foregroundColor(.gray)
            }
        }
        .foregroundColor(.white).padding(20).background(Color.black.opacity(0.75)).cornerRadius(25)
    }
}

// 2. Ekran: Tehlike Uyarı Kartı
struct OnboardingAlertView: View {
    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 45))
                .foregroundColor(.red)
                .shadow(color: .red.opacity(0.5), radius: 10)
            VStack(alignment: .leading, spacing: 6) {
                Text("DİKKAT: ŞİDDETLİ YAĞMUR").font(.headline).fontWeight(.black)
                Text("BÖLGENİZ İÇİN SEL RİSKİ BULUNMAKTADIR. ÖNLEMİNİZİ ALIN.").font(.caption2).foregroundColor(.gray).lineLimit(2)
            }
        }
        .foregroundColor(.white).padding(20).background(Color.red.opacity(0.12)).cornerRadius(25).overlay(RoundedRectangle(cornerRadius: 25).stroke(.red.opacity(0.4), lineWidth: 1))
    }
}

// 3. Ekran: Güvenli Hesap Görseli (Buradaki ismi de Ahmet Yılmaz yaptık)
struct OnboardingAccountRowView: View {
    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AKTİF HESAP")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(Color.blue.opacity(0.6)))
                Spacer()
                Image(systemName: "checkmark.shield.fill").foregroundColor(.green)
            }
            HStack(spacing: 18) {
                Image(systemName: "person.crop.circle.fill").font(.system(size: 50)).foregroundColor(.gray)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ahmet Yılmaz").font(.headline).fontWeight(.black)
                    Text("ahmet@apple.com").font(.caption2).foregroundColor(.gray)
                }
                Spacer()
            }
            Divider().background(.white.opacity(0.1))
            HStack {
                Image(systemName: "star.fill").foregroundColor(.yellow).font(.caption)
                Text("Favori Şehirlerin Senkronize").font(.caption2).foregroundColor(.gray)
                Spacer()
            }
        }
        .foregroundColor(.white).padding(20).background(Color.white.opacity(0.05)).cornerRadius(25)
    }
}
