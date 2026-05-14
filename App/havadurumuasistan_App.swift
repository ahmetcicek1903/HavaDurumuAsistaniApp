import SwiftUI
import FirebaseCore
import UserNotifications

// MARK: - APP DELEGATE SİSTEMİ
// Uygulamanın yaşam döngüsünü (başlangıç, bildirimler vb.) yöneten ana sınıf.
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    // Uygulama ilk kez açıldığında çalışacak olan ana motor
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Firebase veritabanı ve servis bağlantılarını başlatır
        FirebaseApp.configure()
        
        // Bildirimlerin ekranda görünmesini sağlayan temsilciyi (Delegate) bağlar
        UNUserNotificationCenter.current().delegate = self
        
        return true
    }
    
    // Uygulama açıkken (ön plandayken) bir bildirim gelirse nasıl davranacağını belirler.
    // Banner, ses ve liste şeklinde gösterilmesi komutunu verir.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}

// MARK: - ANA UYGULAMA YAPISI
@main
struct havadurumuasistan_App: App {
    // AppDelegate sınıfını SwiftUI yapısına dahil eden köprü.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    // Uygulama boyunca tek bir noktadan yönetilecek olan veri ve yetkilendirme modelleri.
    @StateObject var viewModel = WeatherViewModel()
    @StateObject var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            // OTURUM KONTROLÜ: Kullanıcı giriş yapmış mı?
            if authManager.userSession != nil {
                // Giriş yapılmışsa ana sayfayı göster ve veri modelini (ViewModel) tüm alt sayfalara aktar.
                ContentView()
                    .environmentObject(viewModel)
            } else {
                // Giriş yapılmamışsa kullanıcıyı oturum açma ekranına yönlendir.
                LoginView()
            }
        }
    }
}
