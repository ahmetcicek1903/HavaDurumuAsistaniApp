import SwiftUI
import Combine
import FirebaseFirestore
import FirebaseAuth

// MARK: - HAVA DURUMU VERİ YÖNETİCİSİ
// Bu sınıf uygulamanın "beyni" görevini görür. UI (Arayüz) ile Veri (Firebase/API) arasındaki köprüdür.
class WeatherViewModel: ObservableObject {
    
    // MARK: - DEĞİŞKENLER (HAFIZA)
    
    // Kullanıcının favori eklediği şehirlerin listesi. @Published olduğu için burası değişince ekran otomatik yenilenir.
    @Published var MyCities: [CityWeather] = []
    
    // Arama çubuğuna yazılan metni tutar.
    @Published var searchText = ""
    
    // Arama sonuçlarından dönen tekil veya çoklu şehir verilerini tutar.
    @Published var searchResults: [CityWeather] = []
    
    // Firebase Firestore veritabanı bağlantısı.
    private var db = Firestore.firestore()
    
    // İnternetten hava durumu çeken servis sınıfımız.
    private let weatherService = WeatherService()
    
    // MARK: - BAŞLATICI (INITIALIZER)
    init() {
        // Uygulama açılır açılmaz Firebase'deki favori şehirleri çekmeye başla.
        fetchFavoritesFromFirebase()
    }
    
    // MARK: - 1. ŞEHİR ARAMA MOTORU
    // Kullanıcı arama kutusuna isim yazdığında çalışır.
    func searchCity(query: String) {
        // Gereksiz internet harcamamak için 2 harften az yazıldıysa arama yapma.
        guard query.count > 2 else {
            self.searchResults = []
            return
        }
        
        // Arka planda (Asenkron) API'den veriyi çekiyoruz.
        Task {
            do {
                let city = try await weatherService.fetchWeather(cityName: query)
                // İnternetten gelen veriyle arayüzü güncellerken ana kanala (Main Thread) dönüyoruz.
                await MainActor.run {
                    self.searchResults = [city]
                }
            } catch {
                print("Arama işlemi başarısız: \(error.localizedDescription)")
                await MainActor.run {
                    self.searchResults = []
                }
            }
        }
    }
    
    // MARK: - 2. FAVORİ ŞEHİR EKLEME (FIREBASE)
    // Beğenilen şehri kullanıcının Firebase hesabına kalıcı olarak kaydeder.
    func addCityToFirebase(city: CityWeather) {
        // Oturum açmış kullanıcının benzersiz kimliğini (UID) alıyoruz.
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        // Güvenlik Önlemi: Eğer şehir ismi boş gelirse hata oluşmaması için varsayılan isim veriyoruz.
        let finalCityName = city.name.isEmpty ? "Bilinmeyen Bölge" : city.name
        
        // Firebase'e gönderilecek veri paketi (Sözlük yapısı).
        let cityData: [String: Any] = [
            "name": finalCityName,
            "temp": city.temp,
            "description": city.description,
            "time": city.time,
            "icon": city.icon
        ]
        
        // Firestore Yolu: users -> [KullanıcıID] -> favorites -> [Şehirİsmi]
        db.collection("users").document(uid).collection("favorites").document(finalCityName).setData(cityData)
    }
    
    // MARK: - 3. FAVORİ ŞEHİR SİLME
    // Firebase'den ilgili şehir dökümanını siler.
    func removeCityFromFirebase(cityName: String) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).collection("favorites").document(cityName).delete() { error in
            if let error = error {
                print("Silme işlemi sırasında hata oluştu: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 4. FAVORİLERİ CANLI TAKİP ETME
    // Firebase'deki değişiklikleri anlık izler (Snapshot Listener).
    // Yani bir şehir eklendiğinde veya silindiğinde ekran biz bir şey yapmadan güncellenir.
    func fetchFavoritesFromFirebase() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        
        db.collection("users").document(uid).collection("favorites").addSnapshotListener { querySnapshot, _ in
            guard let documents = querySnapshot?.documents else { return }
            
            // Firebase'den gelen ham dökümanları CityWeather objesine çeviriyoruz.
            let favorites = documents.map { doc in
                let data = doc.data()
                return CityWeather(
                    name: data["name"] as? String ?? "",
                    temp: data["temp"] as? String ?? "",
                    description: data["description"] as? String ?? "",
                    time: data["time"] as? String ?? "",
                    icon: data["icon"] as? String ?? ""
                )
            }
            
            // Listeyi güncelliyoruz ve derecelerin taze kalması için API'den yenileme başlatıyoruz.
            DispatchQueue.main.async {
                self.MyCities = favorites
                self.refreshAllFavorites()
            }
        }
    }

    // MARK: - 5. MEVCUT KONUM HAVA DURUMU
    // Cihazdan gelen koordinatlara (Lat/Lon) göre hava durumunu çeker.
    func fetchLocationWeather(lat: Double, lon: Double) {
        Task {
            do {
                let currentCity = try await weatherService.fetchWeather(lat: lat, lon: lon)
                
                await MainActor.run {
                    // Eğer bu konum listede yoksa en başa ekle.
                    if !self.MyCities.contains(where: { $0.name == currentCity.name }) {
                        self.MyCities.insert(currentCity, at: 0)
                    }
                    
                    // TEHLİKE SENSÖRÜ: Mevcut konumdaki sıcaklığı kontrol et ve gerekirse bildirim at.
                    let tempString = currentCity.temp.filter("0123456789.-".contains)
                    let tempDouble = Double(tempString) ?? 0.0
                    
                    NotificationManager.shared.checkExtremeWeatherAndAlert(
                        cityName: currentCity.name,
                        temp: tempDouble,
                        windSpeed: 0, // Geliştirme aşamasında 0 olarak bırakıldı
                        conditionId: 0
                    )
                }
            } catch {
                print("Koordinat bazlı hava durumu çekilemedi: \(error)")
            }
        }
    }
    
    // MARK: - 6. DERECELERİ TAZELEME VE GÜVENLİK TARAMASI
    // Favori listedeki tüm şehirlerin derecelerini API'den tekrar çeker ve ekstrem durumları denetler.
    private func refreshAllFavorites() {
        let currentCities = MyCities
        
        for city in currentCities {
            Task {
                do {
                    let updated = try await weatherService.fetchWeather(cityName: city.name)
                    
                    await MainActor.run {
                        // Şehrin listedeki o anki yerini bulup verisini güncelliyoruz.
                        if let realIndex = self.MyCities.firstIndex(where: { $0.name == city.name }) {
                            self.MyCities[realIndex] = updated
                            
                            // SICAKLIK DENETİMİ: Ayarlar açıksa tehlikeli hava bildirimlerini tetikle.
                            let tempString = updated.temp.filter("0123456789.-".contains)
                            let tempDouble = Double(tempString) ?? 0.0
                            
                            let dangerAlertsEnabled = UserDefaults.standard.bool(forKey: "showDangerAlerts")
                            if dangerAlertsEnabled {
                                NotificationManager.shared.checkExtremeWeatherAndAlert(
                                    cityName: updated.name,
                                    temp: tempDouble,
                                    windSpeed: 0,
                                    conditionId: 0
                                )
                            }
                        }
                    }
                } catch {
                    print("\(city.name) güncellenirken hata oluştu.")
                }
            }
        }
    }
}
