import SwiftUI
import CoreLocation
import MapKit
import WidgetKit
import FirebaseAuth

// MARK: - 1. VERİ MODELLERİ (STRUCTS)
// Uygulama içinde taşınacak verilerin (Hava durumu, tahminler) iskeletini oluşturur.

struct HourlyForecast: Identifiable, Equatable, Hashable {
    let id = UUID()
    let time: String
    let icon: String
    let temp: String
    let pop: String // Yağış ihtimali (Probability of Precipitation)
}

struct DailyForecast: Identifiable, Equatable, Hashable {
    let id = UUID()
    let dayName: String
    let icon: String
    let dayTemp: String
    let nightTemp: String
}

// Ana hava durumu modeli. Firebase'e kaydedilirken veya ekranda gösterilirken bu kalıp kullanılır.
struct CityWeather: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let temp: String
    let description: String
    let time: String
    let icon: String
    
    var humidity: Int = 0
    var windSpeed: Double = 0.0
    var feelsLike: String = ""
    var latitude: Double = 0.0
    var longitude: Double = 0.0
    
    var dailyForecast: [DailyForecast] = []
    var hourlyForecast: [HourlyForecast] = []

    // Equatable protokolü: Şehir isimleri aynıysa, objeleri aynı kabul et.
    static func == (lhs: CityWeather, rhs: CityWeather) -> Bool {
        return lhs.name == rhs.name
    }
}

// API'den gelen karmaşık listeyi parçalamak için kullanılan ara model.
struct ForecastItem: Codable {
    let dt: TimeInterval
    let main: MainInfo
    let weather: [WeatherDetail]
    let dt_txt: String
    let pop: Double?
}

// MARK: - 2. ANA EKRAN (CONTENT VIEW)
struct ContentView: View {
    // MARK: - DEĞİŞKENLER (HAFIZA VE DURUM YÖNETİMİ)
    
    // AppStorage: Kullanıcının cihaz hafızasından okunan ayarlar.
    @AppStorage("isOnboardingCompleted") private var isOnboardingCompleted: Bool = false
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    @AppStorage("autoLocation") private var autoLocation: Bool = false
    
    // Uygulama genelinde çalışan motorlar (Beyin sınıflarımız)
    @StateObject var viewModel = WeatherViewModel()
    @StateObject var locationManager = LocationManager()
    @StateObject var authManager = AuthManager.shared
    
    // Ekranlar arası geçişleri (Navigasyon) kontrol eden şalterler.
    @State private var isShowingSearch = false
    @State private var isShowingSettings = false
    @State private var isShowingAccount = false
    @State private var isShowingAboutPage = false
    
    // GPS ve Konum çekme işlemleri sırasındaki yükleme ve hata durumları.
    @State private var showLocationAlert = false
    @State private var isLocationLoading = false
    @State private var currentLocationWeather: CityWeather?
    @State private var showGpsErrorAlert = false
    @State private var gpsErrorMessage = ""

    // MARK: - ARAYÜZ (GÖRSEL KISIM)
    var body: some View {
        // Kullanıcı tanıtım ekranını (Onboarding) geçmiş mi kontrolü.
        if isOnboardingCompleted {
            NavigationStack {
                ZStack(alignment: .topLeading) {
                    // ARKA PLAN (Temaya göre değişir)
                    Group {
                        if selectedTheme == .koyu {
                            LinearGradient(colors: [.black, Color(red: 0.05, green: 0.05, blue: 0.15)], startPoint: .top, endPoint: .bottom)
                        } else {
                            Color(UIColor.systemGroupedBackground)
                        }
                    }
                    .ignoresSafeArea()
                    
                    VStack(spacing: 0) {
                        // 1. ÜST BAR: Menü butonu ve Arama çubuğu
                        HStack(spacing: 15) {
                            // Yan Menü Açma Butonu
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    isShowingSettings.toggle()
                                }
                            }) {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title2)
                                    .foregroundColor(selectedTheme == .koyu ? .white : .primary)
                            }
                            
                            // Arama Ekranını Açan Çubuk (Fake TextField)
                            Button(action: { isShowingSearch = true }) {
                                HStack {
                                    Image(systemName: "magnifyingglass")
                                        .foregroundColor(selectedTheme == .koyu ? .white.opacity(0.7) : .secondary)
                                    Text("Şehir veya havaalanı ara")
                                        .foregroundColor(selectedTheme == .koyu ? .white.opacity(0.7) : .secondary)
                                    Spacer()
                                }
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .cornerRadius(15)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.top, 10)
                        .padding(.bottom, 20)
                        
                        // 2. FAVORİ ŞEHİRLER LİSTESİ
                        if viewModel.MyCities.isEmpty {
                            // Liste boşsa kullanıcıyı yönlendiren tasarım
                            VStack {
                                Spacer()
                                Image(systemName: "cloud.sun")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text("Henüz şehir eklenmedi.")
                                    .foregroundColor(.gray)
                                    .padding(.top, 10)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            // Favori şehirler varsa, cam görünümlü kartlar şeklinde listele
                            List {
                                ForEach(viewModel.MyCities) { city in
                                    ZStack {
                                        PremiumCityCardView(city: city)
                                            .onTapGesture {
                                                // Tıklanınca o şehri Widget için varsayılan yapar
                                                favoriSehriWidgetaKaydet(sehirAdi: city.name)
                                            }
                                        // Detay sayfasına geçiş (Görünmez Link)
                                        NavigationLink(destination: WeatherDetailView(city: city, viewModel: viewModel)) {
                                            EmptyView()
                                        }
                                        .opacity(0)
                                    }
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                                }
                                .onDelete(perform: deleteCity) // Sola kaydırıp silme özelliği
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                    
                    // 3. SAĞ ALT YÜZEN KONUM BUTONU (FAB - Floating Action Button)
                    // Kullanıcının anlık konumunun hava durumunu çeker.
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: handleLocationTap) {
                                ZStack {
                                    // Yükleniyor durumunda buton "nefes alan" (pulse) bir animasyon yapar.
                                    Circle()
                                        .fill(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                        .frame(width: isLocationLoading ? 65 : 60, height: isLocationLoading ? 65 : 60)
                                        .shadow(color: .blue.opacity(isLocationLoading ? 0.8 : 0.4), radius: isLocationLoading ? 15 : 8, x: 0, y: 5)
                                        .scaleEffect(isLocationLoading ? 1.05 : 1.0)
                                        .animation(isLocationLoading ? .easeInOut(duration: 0.8).repeatForever(autoreverses: true) : .spring(), value: isLocationLoading)
                                    
                                    if isLocationLoading {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                            .scaleEffect(1.2)
                                    } else {
                                        Image(systemName: "location.fill")
                                            .font(.title2)
                                            .foregroundColor(.white)
                                            .transition(.scale)
                                    }
                                }
                            }
                            .padding(.trailing, 20)
                            .padding(.bottom, 30)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    
                    // 4. YAN MENÜ (HAMBURGER MENÜ)
                    // Ekranın solundan kayarak açılan profil ve ayarlar paneli.
                    if isShowingSettings {
                        // Menü açıkken arkaplanı karartan katman
                        Color.black.opacity(selectedTheme == .koyu ? 0.6 : 0.3)
                            .ignoresSafeArea()
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    isShowingSettings = false
                                }
                            }
                            .zIndex(1)
                            .transition(.opacity)
                        
                        // Menü Paneli İçeriği
                        VStack(alignment: .leading, spacing: 20) {
                            // Kullanıcı Bilgileri
                            HStack(spacing: 15) {
                                if let photoURL = authManager.userSession?.photoURL {
                                    AsyncImage(url: photoURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        ProgressView()
                                    }
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.crop.circle.fill")
                                        .resizable()
                                        .frame(width: 50, height: 50)
                                        .foregroundStyle(LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Merhaba,")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(authManager.userSession?.displayName ?? "Kullanıcı")
                                        .font(.headline)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            Divider().background(Color.primary.opacity(0.2))
                            
                            // Menü Butonları
                            VStack(alignment: .leading, spacing: 20) {
                                MenuButtonView(icon: "person.circle", title: "Hesabım") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isShowingSettings = false }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isShowingAccount = true }
                                }
                                MenuButtonView(icon: "info.circle", title: "Hakkımızda") {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { isShowingSettings = false }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { isShowingAboutPage = true }
                                }
                            }
                        }
                        .padding(20)
                        .frame(width: 260)
                        .background(RoundedRectangle(cornerRadius: 25).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(selectedTheme == .koyu ? 0.1 : 0.4), lineWidth: 1))
                        .offset(x: 15, y: 60)
                        .zIndex(2)
                        // Sol üstten büyüyerek açılma efekti
                        .transition(.scale(scale: 0.01, anchor: .topLeading).combined(with: .opacity))
                    }
                }
                // MARK: - YÖNLENDİRMELER (NAVIGATION & SHEETS)
                .toolbar(.hidden, for: .navigationBar)
                .sheet(isPresented: $isShowingSearch) { SearchView(viewModel: viewModel) } // Arama ekranı
                .sheet(item: $currentLocationWeather) { city in WeatherDetailView(city: city, viewModel: viewModel) } // Anlık konum detayı
                .navigationDestination(isPresented: $isShowingAccount) { AccountView() }
                .navigationDestination(isPresented: $isShowingAboutPage) { AboutView() }
                
                // HATA VE UYARI MESAJLARI (ALERTS)
                .alert("Konum İzni Gerekli", isPresented: $showLocationAlert) {
                    Button("Tamam", role: .cancel) { }
                } message: {
                    Text("Mevcut konum hava durumunuzu öğrenmek için Hesabım > Tercihler bölümünden Otomatik Konum özelliğini açmalısınız.")
                }
                .alert("Sinyal Arızası", isPresented: $showGpsErrorAlert) {
                    Button("Tamam", role: .cancel) { }
                } message: {
                    Text(gpsErrorMessage)
                }
            }
        } else {
            // Uygulama ilk defa açıldıysa tanıtım ekranını göster
            OnboardingView()
        }
    }
    
    // MARK: - İŞLEVLER (FONKSİYONLAR)
    
    // Seçilen şehri iOS Ana Ekran Widget'ı (Araç Takımı) için hafızaya kaydeder.
    func favoriSehriWidgetaKaydet(sehirAdi: String) {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.omerzibabo.weather") {
            sharedDefaults.set(sehirAdi, forKey: "selectedCity")
            WidgetCenter.shared.reloadAllTimelines() // Widget'ı anında yenile
        }
    }
    
    // Listeden şehri sola kaydırarak (Swipe) silme işlemi.
    func deleteCity(at offsets: IndexSet) {
        offsets.forEach { index in
            let city = viewModel.MyCities[index]
            viewModel.removeCityFromFirebase(cityName: city.name)
        }
    }
    
    // MARK: - KONUM İŞLEMLERİ (MEVCUT KONUM)
    // Sağ alttaki konum butonuna basılınca çalışır.
    private func handleLocationTap() {
        // Telefona hafif, premium hissettiren bir titreşim (Haptic Feedback) verir.
        let impactMed = UIImpactFeedbackGenerator(style: .medium)
        impactMed.impactOccurred()
        
        if !autoLocation {
            showLocationAlert = true // Şalter kapalıysa uyarı ver
        } else {
            fetchCurrentLocationWeather() // Açıksa veriyi çek
        }
    }
    
    // GPS'ten anlık koordinatı alıp hava durumunu çeken motor.
    private func fetchCurrentLocationWeather() {
        // Eğer GPS uyduya tam bağlanamadıysa sessizce kalmaz, hatayı ekrana basar.
        guard let location = locationManager.location else {
            gpsErrorMessage = "Cihazınızdan şu an net bir GPS sinyali alınamıyor. Lütfen konum servislerinin tam olarak yerini bulmasını bekleyin veya açık alana geçin."
            showGpsErrorAlert = true
            return
        }
        
        // Butonu animasyonlu yükleme moduna sokar
        withAnimation {
            isLocationLoading = true
        }
        
        Task {
            do {
                let weatherService = WeatherService()
                let fetchedWeather = try await weatherService.fetchWeather(lat: location.latitude, lon: location.longitude)
                
                await MainActor.run {
                    self.currentLocationWeather = fetchedWeather
                    withAnimation {
                        self.isLocationLoading = false // Animasyonu durdur
                    }
                }
            } catch {
                await MainActor.run {
                    withAnimation {
                        self.isLocationLoading = false
                    }
                    self.gpsErrorMessage = "Hava durumu verisi çekilirken bir sorun oluştu: \(error.localizedDescription)"
                    self.showGpsErrorAlert = true
                }
            }
        }
    }
}

// MARK: - 3. ARAMA EKRANI (SEARCH VIEW)
// Kullanıcının şehir veya ilçe aradığı, Apple Maps destekli ekran.
struct SearchView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WeatherViewModel
    @AppStorage("selectedTheme") private var selectedTheme: Theme = .sistem
    
    // Apple Haritalar (MapKit) arama motorumuz
    @StateObject private var searchService = LocationSearchService()
    
    // Yükleme durumu ve dönen çark için değişkenler
    @State private var selectedCityWeather: CityWeather?
    @State private var isLoading = false
    @State private var isSpinning = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Temaya göre arkaplanı ayarlar
                if selectedTheme == .koyu {
                    Color(red: 0.08, green: 0.08, blue: 0.12).ignoresSafeArea()
                } else {
                    Color(UIColor.systemGroupedBackground).ignoresSafeArea()
                }
                
                // MapKit'ten gelen sonuçları listeler
                List(searchService.searchResults, id: \.self) { result in
                    Button(action: {
                        fetchWeatherAndNavigate(for: result) // Tıklanan şehrin detayını çek
                    }) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(result.title)
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            // Mahalle/İlçe alt başlığı varsa göster
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .listRowBackground(Color.white.opacity(0.05))
                    .listRowSeparatorTint(.gray.opacity(0.3))
                }
                .scrollContentBackground(.hidden)
                
                // Arama yapılırken ekranı karartan ve dönen yükleme göstergesi
                if isLoading {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ZStack {
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 5)
                                    .frame(width: 45, height: 45)
                                
                                Circle()
                                    .trim(from: 0.2, to: 1.0)
                                    .stroke(
                                        LinearGradient(colors: [.cyan, .blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                                    )
                                    .frame(width: 45, height: 45)
                                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                                    .onAppear {
                                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                                            isSpinning = true
                                        }
                                    }
                            }
                            
                            Text("Veriler Çekiliyor...")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        .padding(.horizontal, 35)
                        .padding(.vertical, 30)
                        .background(RoundedRectangle(cornerRadius: 25).fill(.ultraThinMaterial))
                        .overlay(RoundedRectangle(cornerRadius: 25).stroke(Color.white.opacity(0.2), lineWidth: 1))
                        .shadow(color: .black.opacity(0.4), radius: 20)
                    }
                }
            }
            .navigationTitle("Şehir Ara")
            .navigationBarTitleDisplayMode(.inline)
            // iOS standartlarında arama çubuğu ekler
            .searchable(text: $searchService.searchQuery, prompt: "İlçe veya şehir adı giriniz...")
            // Arama başarılı olursa Detay sayfasına (WeatherDetailView) yönlendirir
            .navigationDestination(item: $selectedCityWeather) { city in
                WeatherDetailView(city: city, viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Kapat") { dismiss() }
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                }
            }
        }
    }
    
    // Tıklanan şehrin adına göre değil, garantili olan Koordinatlarına (Enlem/Boylam) göre veriyi çeken sistem.
    private func fetchWeatherAndNavigate(for result: MKLocalSearchCompletion) {
        isLoading = true
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        // Önce Apple Haritalar'dan tam koordinatı buluyoruz
        search.start { response, error in
            guard let coordinate = response?.mapItems.first?.placemark.coordinate else {
                isLoading = false
                return
            }
            
            // Koordinatı bulduysak hava durumu servisine gönderiyoruz
            Task {
                do {
                    let weatherService = WeatherService()
                    let fetchedWeather = try await weatherService.fetchWeather(lat: coordinate.latitude, lon: coordinate.longitude)
                    
                    await MainActor.run {
                        self.selectedCityWeather = fetchedWeather
                        self.isLoading = false
                        self.isSpinning = false
                    }
                } catch {
                    print("Arama verisi çekilemedi: \(error.localizedDescription)")
                    await MainActor.run {
                        self.isLoading = false
                        self.isSpinning = false
                    }
                }
            }
        }
    }
}

// MARK: - 4. YARDIMCI GÖRÜNÜMLER (BİLEŞENLER)

// Ana ekrandaki şehir kartlarının (Favoriler) hava durumuna göre değişen arka plan animasyonu.
struct WeatherAnimatedBackgroundView: View {
    var condition: String
    @State private var isAnimating = false
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Hava durumuna (güneşli, yağmurlu) uygun renk geçişi (Gradient)
                baseGradient(for: condition)
                
                let conditionLower = condition.lowercased()
                
                // Hava güneşliyse dönen güneş efekti
                if conditionLower.contains("clear") || conditionLower.contains("açık") || conditionLower.contains("güneş") {
                    Image(systemName: "sun.max.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .foregroundColor(.yellow.opacity(0.6))
                        .blur(radius: 5)
                        .offset(x: geo.size.width * 0.5, y: -20)
                        .rotationEffect(.degrees(isAnimating ? 360 : 0))
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                    
                // Bulutluysa yavaşça kayan bulutlar
                } else if conditionLower.contains("cloud") || conditionLower.contains("bulut") {
                    Image(systemName: "cloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .foregroundColor(.white.opacity(0.3))
                        .offset(x: isAnimating ? geo.size.width : -geo.size.width * 0.5, y: 10)
                    
                    Image(systemName: "cloud.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 90, height: 90)
                        .foregroundColor(.white.opacity(0.2))
                        .offset(x: isAnimating ? -50 : geo.size.width * 0.8, y: 50)
                    
                // Yağmurluysa yukarı aşağı hareket eden bulut
                } else if conditionLower.contains("rain") || conditionLower.contains("yağmur") || conditionLower.contains("shower") {
                    Image(systemName: "cloud.heavyrain.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.black.opacity(0.3))
                        .offset(x: geo.size.width * 0.6, y: isAnimating ? 10 : -10)
                    
                // Karlı hava animasyonu
                } else if conditionLower.contains("snow") || conditionLower.contains("kar") {
                    Image(systemName: "snowflake")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 80, height: 80)
                        .foregroundColor(.white.opacity(0.5))
                        .offset(x: geo.size.width * 0.6, y: isAnimating ? 30 : -10)
                        .rotationEffect(.degrees(isAnimating ? 180 : 0))
                }
            }
        }
        .onAppear {
            // Sonsuz döngüde çalışan yavaş animasyon motoru
            withAnimation(.linear(duration: 10.0).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
    }
    
    // Havanın metin açıklamasına göre arka plan renklerini belirleyen fonksiyon
    func baseGradient(for condition: String) -> LinearGradient {
        let conditionLower = condition.lowercased()
        let colors: [Color]
        
        if conditionLower.contains("clear") || conditionLower.contains("açık") || conditionLower.contains("güneş") {
            colors = [Color.blue.opacity(0.7), Color.cyan.opacity(0.5)]
        } else if conditionLower.contains("rain") || conditionLower.contains("yağmur") || conditionLower.contains("shower") {
            colors = [Color.gray.opacity(0.8), Color.blue.opacity(0.6)]
        } else if conditionLower.contains("cloud") || conditionLower.contains("bulut") {
            colors = [Color.gray.opacity(0.6), Color.gray.opacity(0.8)]
        } else if conditionLower.contains("snow") || conditionLower.contains("kar") {
            colors = [Color.white.opacity(0.4), Color.cyan.opacity(0.5)]
        } else {
            colors = [Color.blue.opacity(0.4), Color.purple.opacity(0.4)]
        }
        
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

// Ana ekrandaki yatay, cam efekti uygulanan "Favori Şehir Kartı" görünümü.
struct PremiumCityCardView: View {
    let city: CityWeather
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(city.name).font(.title2).fontWeight(.bold).foregroundColor(.white)
                Text(city.time).font(.subheadline).foregroundColor(.white.opacity(0.8))
                Spacer()
                Text(city.description.capitalized).font(.caption).foregroundColor(.white.opacity(0.8))
            }
            Spacer()
            VStack(alignment: .trailing) {
                Text("\(city.temp)°").font(.system(size: 40, weight: .light)).foregroundColor(.white)
                Spacer()
                Image(systemName: city.icon).symbolRenderingMode(.multicolor).font(.title)
            }
        }
        .padding()
        .frame(height: 110)
        .background(
            WeatherAnimatedBackgroundView(condition: city.description)
                .overlay(.black.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.2), lineWidth: 1))
        )
    }
}

// Menülerde kullanılan standart satır görünümü (İkon + Metin)
struct MenuButtonView: View {
    let icon: String
    let title: String
    var action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon).frame(width: 25)
                Text(title).font(.headline)
            }
            .foregroundColor(.primary)
        }
    }
}
