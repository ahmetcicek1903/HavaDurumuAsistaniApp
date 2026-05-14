import SwiftUI

// MARK: - TEMA SEÇENEKLERİ
// Uygulamanın görselliğini belirleyen seçenekleri tutar.
enum Theme: String, CaseIterable {
    case sistem = "Sistem"
    case acik = "Açık"
    case koyu = "Koyu"
    
    // SwiftUI'ın anlayacağı renk şemasına (ColorScheme) çeviren yardımcı değişken.
    // .light, .dark veya sistem varsayılanı (nil) döndürür.
    var colorScheme: ColorScheme? {
        switch self {
        case .sistem: return nil
        case .acik: return .light
        case .koyu: return .dark
        }
    }
}

// MARK: - TEMA YÖNETİCİSİ
// Uygulamanın her yerinden erişilebilen ana tema şalteri.
struct ThemeManager {
    // AppStorage sayesinde kullanıcının tema seçimi telefonun kalıcı hafızasına kaydedilir.
    // Uygulama kapansa bile bu seçim unutulmaz.
    @AppStorage("selectedTheme") static var selectedTheme: Theme = .sistem
}
