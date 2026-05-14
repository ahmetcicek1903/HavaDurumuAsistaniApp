import SwiftUI
import UserNotifications
import Combine
import Foundation

// MARK: - BİLDİRİM YÖNETİCİSİ (NOTIFICATION MANAGER)
// Apple'ın bildirim motorunu (UNUserNotificationCenter) kullanarak kullanıcıya uyarılar gönderen ana sınıf.
class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    
    // Sınıfın uygulamanın her yerinden tek bir kopya olarak kullanılmasını sağlar (Singleton Prensibi).
    static let shared = NotificationManager()
    
    // Kullanıcının bildirim izni verip vermediğini tutan, arayüzü güncelleyebilen (Published) değişken.
    @Published var isPermissionGranted = false
    
    // 🚨 SPAM FİLTRESİ HAFIZASI 🚨
    // Hangi şehre en son ne zaman bildirim atıldığını (Tarih olarak) aklında tutan sözlük (Dictionary).
    private var lastAlertTimes: [String: Date] = [:]
    
    override init() {
        super.init()
        // Bildirim olaylarını bu sınıfın yöneteceğini Apple'a bildirir.
        UNUserNotificationCenter.current().delegate = self
    }
    
    // Uygulama ekranda açıkken (Ön plandayken) bir bildirim gelirse, bunun gizli kalmayıp yukarıdan düşmesini (banner) ve ses çıkarmasını sağlar.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }
    
    // MARK: - İZİN İSTEME EKRANI
    // Kullanıcıya "Sana bildirim gönderebilir miyim?" diye soran standart Apple penceresini çıkarır.
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isPermissionGranted = granted // İzin sonucunu hafızaya kaydet
                if let error = error {
                    print("Bildirim yetkisi alınırken hata çıktı: \(error.localizedDescription)")
                }
                completion(granted)
            }
        }
    }
    
    // MARK: - TEHLİKE SENSÖRÜ (RESMİ VE PROFESYONEL DİL)
    // Hava durumu API'sinden gelen anlık verileri ölçer; limitler aşılmışsa kullanıcıya uyarı fırlatır.
    func checkExtremeWeatherAndAlert(cityName: String, temp: Double, windSpeed: Double, conditionId: Int) {
            
        // 🛑 1. ŞALTER KONTROLÜ (AYARLAR)
        // Kullanıcının Ayarlar ekranında bildirimleri veya tehlike uyarılarını kapatıp kapatmadığını kontrol eder.
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "allowNotifications") == nil { defaults.set(false, forKey: "allowNotifications") }
        if defaults.object(forKey: "showDangerAlerts") == nil { defaults.set(true, forKey: "showDangerAlerts") }
            
        let allowNotifications = defaults.bool(forKey: "allowNotifications")
        let showDangerAlerts = defaults.bool(forKey: "showDangerAlerts")
            
        // Eğer kullanıcı ayarlardan şalteri kapattıysa, hiç hava durumunu ölçmeden işlemi sonlandır (return).
        if !allowNotifications || !showDangerAlerts {
            return
        }
            
        var alertTitle = ""
        var alertBody = ""
        var isDanger = false
            
        // MARK: - PROFESYONEL BİLDİRİM METİNLERİ (ŞARTLAR)
        // Sıcaklık kontrolleri
        if temp <= -5 {
            alertTitle = "Uyarı: Aşırı Soğuk ve Buzlanma Tehlikesi ❄️"
            alertBody = "\(cityName) konumunda hava sıcaklığı \(Int(temp))°C seviyesine düşmüştür. Yollarda oluşabilecek gizli buzlanma riskine karşı dikkatli olunuz."
            isDanger = true
        } else if temp >= 38 {
            alertTitle = "Uyarı: Yüksek Sıcaklık Düzeyi ☀️"
            alertBody = "\(cityName) konumunda hava sıcaklığı \(Int(temp))°C olarak ölçülmüştür. Sağlık sorunlarına karşı uzun süre doğrudan güneş ışığına maruz kalmaktan kaçınınız."
            isDanger = true
        }
            
        // Rüzgar kontrolü
        if windSpeed > 15.0 {
            alertTitle = "Uyarı: Şiddetli Rüzgar ve Fırtına 🌪️"
            alertBody = "\(cityName) bölgesinde şiddetli rüzgar etkisini göstermektedir. Ağaç veya direk devrilmesi, çatı uçması gibi risklere karşı tedbirli olunuz."
            isDanger = true
        }
            
        // Hava durumu kodları (ID) kontrolü. OpenWeather API standartlarına göre belirlenmiştir.
        if (200...232).contains(conditionId) {
            // 200'lü kodlar Gök gürültülü fırtınaları temsil eder.
            alertTitle = "Uyarı: Gök Gürültülü Sağanak Yağış ⚡"
            alertBody = "\(cityName) konumunda kuvvetli gök gürültülü fırtına tespit edilmiştir. Yıldırım düşmesi riskine karşı açık alanlarda bulunmaktan kaçınınız."
            isDanger = true
        } else if [502, 503, 504, 522].contains(conditionId) {
            // 500'lü kritik kodlar şiddetli yağmuru temsil eder.
            alertTitle = "Uyarı: Şiddetli Yağış ve Sel Riski 🌧️"
            alertBody = "\(cityName) bölgesinde beklenen kuvvetli yağış nedeniyle ani sel, su baskını ve ulaşımda aksamalara karşı dikkatli olunuz."
            isDanger = true
        } else if [602, 622].contains(conditionId) {
            // 602 ve 622 kodları yoğun ve şiddetli kar yağışını temsil eder.
            alertTitle = "Uyarı: Yoğun Kar Yağışı 🌨️"
            alertBody = "\(cityName) bölgesinde yoğun kar yağışı beklenmektedir. Trafikte yaşanabilecek aksamalara karşı kış lastiği kullanımına özen gösteriniz."
            isDanger = true
        }
            
        // 🚨 2. SPAM KONTROL MEKANİZMASI 🚨
        // Aynı tehlike bildirimiyle kullanıcıyı sürekli rahatsız etmemek için süre ölçümü yapar.
        if isDanger {
            // Her şehir için benzersiz bir anahtar (key) oluştur. Örn: "Kahramanmaraş_danger"
            let alertKey = "\(cityName)_danger"
                
            // Bu şehre daha önce bildirim atılmış mı kontrol et.
            if let lastTime = lastAlertTimes[alertKey] {
                // Son atılan bildirimin üzerinden kaç saniye geçmiş hesapla.
                let timePassed = Date().timeIntervalSince(lastTime)
                    
                // Eğer 1 SAATTEN (3600 saniye) az zaman geçmişse, bu bildirimi iptal et (sessize al).
                if timePassed < 3600 {
                    return
                }
            }
                
            // Süre engeline takılmadıysa, şu anki zamanı deftere kaydet.
            lastAlertTimes[alertKey] = Date()
            
            // Asıl bildirimi oluşturup fırlatan fonksiyonu çağır.
            scheduleAlert(title: alertTitle, body: alertBody, identifier: alertKey)
        }
    }
    
    // MARK: - BİLDİRİM OLUŞTURMA VE GÖNDERME
    // Gelen başlık ve metinle Apple sistemine gerçek bir bildirim isteği yollar.
    private func scheduleAlert(title: String, body: String, identifier: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        // Tehlike uyarısı olduğu için Apple'ın daha dikkat çekici olan "Critical" sesini çalmaya çalışır.
        content.sound = .defaultCritical
        
        // Bildirimin tam olarak ne zaman gösterileceği. (Burada 2 saniye sonra anında göster olarak ayarlandı).
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        
        // İsteği paketle
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        // Paketi Apple sistemine teslim et
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Bildirim gönderilemedi: \(error.localizedDescription)")
            } else {
                print("Tehlike uyarısı başarıyla fırlatıldı! (\(title))")
            }
        }
    }
}
