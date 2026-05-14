import Foundation
import CoreLocation
import Combine

// MARK: - KONUM YÖNETİCİSİ
// Cihazın GPS sensörüyle konuşan ve anlık koordinat bilgisini sağlayan sınıf.
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    
    // Cihazın mevcut enlem ve boylam bilgisini tutan değişken.
    @Published var location: CLLocationCoordinate2D?
    // Kullanıcının konuma izin verip vermediğini takip eden değişken.
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    
    override init() {
        super.init()
        manager.delegate = self
        // GPS hassasiyetini en yüksek seviyeye (Metre bazında) çeker.
        manager.desiredAccuracy = kCLLocationAccuracyBest
        self.authorizationStatus = manager.authorizationStatus
        
        // Başlangıçta izin varsa konum güncellemelerini hemen başlatır.
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation()
        }
    }
    
    // MARK: - İZİN DURUMU TAKİBİ
    // Kullanıcı ayarlardan izni değiştirirse (Aç/Kapat) bu fonksiyon otomatik tetiklenir.
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        self.authorizationStatus = manager.authorizationStatus
        
        if manager.authorizationStatus == .authorizedWhenInUse || manager.authorizationStatus == .authorizedAlways {
            manager.startUpdatingLocation() // İzin verilirse GPS motorunu çalıştır.
        } else {
            manager.stopUpdatingLocation() // İzin yoksa GPS'i kapatarak pil tasarrufu sağla.
        }
    }
    
    // MARK: - VERİ GÜNCELLEME SİNYALİ
    // GPS uydusundan yeni bir konum bilgisi geldiğinde burası çalışır.
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Gelen listedeki en son (en güncel) koordinatı alıyoruz.
        guard let newLocation = locations.last else { return }
        
        // Veriyi ana arayüze güvenli bir şekilde aktarıyoruz.
        DispatchQueue.main.async {
            self.location = newLocation.coordinate
        }
        // Not: stopUpdatingLocation() komutunu kaldırdık; böylece kullanıcı hareket ettikçe veriler güncel kalır.
    }

    // Olası bir GPS hatasında (Bina altı, tünel vb.) çalışacak hata yakalayıcı.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Konum hatası: \(error.localizedDescription)")
    }
}
