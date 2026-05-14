import SwiftUI
import Charts
import MapKit

// MARK: - 1. DETAY ANA EKRANI
// Seçilen şehrin saatlik, günlük tahmini ile rüzgar, nem ve radar gibi detaylı istatistiklerini gösteren ana sayfa.
struct WeatherDetailView: View {
    // Favori durumu ve ekranın kaydırma (scroll) oranını takip eden değişkenler.
    @State private var isFavorite: Bool = false
    @State private var scrollOffset: CGFloat = 0
    let city: CityWeather
    @ObservedObject var viewModel: WeatherViewModel
    
    var body: some View {
        ZStack {
            // Arka planı o anki hava durumuna göre renklendiren fonksiyon
            getBackgroundGradient(condition: city.description)
                .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 25) {
                    // EKRAN KAYDIRMA (SCROLL) SENSÖRÜ:
                    // Kullanıcı ekranı aşağı kaydırdıkça üstteki isim ve sıcaklık yazısının şeffaflaşması/küçülmesi için pozisyonu ölçer.
                    GeometryReader { geo in
                        Color.clear.preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                    }
                    .frame(height: 0)
                    
                    // Üst Bar (Geri dönüş butonu, Şehir Adı ve Favori Butonu)
                    UpperBarView(isFavorite: $isFavorite, city: city, viewModel: viewModel, scrollOffset: scrollOffset)
                    
                    // Ana sıcaklık ve ikon (Kaydırıldıkça yavaşça şeffaflaşır ve küçülür)
                    MainWeatherInfoView(city: city)
                        .opacity(Double(1 + (scrollOffset / 180)))
                        .scaleEffect(max(0.7, 1 + (scrollOffset / 400)))
                    
                    // Önümüzdeki 24 saatin yatay listesi
                    HourlyForecastView(city: city)
                    
                    // Apple Charts ile oluşturulmuş sıcaklık değişim grafiği
                    TemperatureChartView(city: city)
                    
                    // Rüzgar ve Nem bilgilerini gösteren yan yana iki kare kart
                    HStack(spacing: 15) {
                        WindSquareCard(city: city)
                        HumiditySquareCard(city: city)
                    }
                    .padding(.horizontal)
                    
                    // CANLI RADAR: Apple Maps ve OpenWeather API altyapısı birleştirilerek harita basılır.
                    WeatherRadarMapView(city: city)
                    
                    // 5 Günlük Tahmini gösteren kaydırmalı (Swipe) kart yapısı.
                    WeeklySwipeCardView(forecast: city.dailyForecast)
                    
                    Spacer()
                }
                .padding(.bottom, 20)
            }
            .coordinateSpace(name: "scroll")
            .onPreferenceChange(ScrollOffsetKey.self) { value in
                scrollOffset = value
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Ekran açıldığında bu şehrin favorilerde olup olmadığını Firebase modelinden (ViewModel) kontrol et.
            isFavorite = viewModel.MyCities.contains(where: { $0.name == city.name })
        }
    }
    
    // MARK: - ARKA PLAN MOTORU
    // Hava durumunun İngilizce veya Türkçe ismine göre ekrana degrade (gradient) renk basar.
    func getBackgroundGradient(condition: String) -> LinearGradient {
        let cond = condition.lowercased()
        if cond.contains("güneşli") || cond.contains("açık") || cond.contains("clear") {
            return LinearGradient(colors: [.blue, Color.orange.opacity(0.8)], startPoint: .top, endPoint: .bottom)
        } else if cond.contains("yağmurlu") || cond.contains("rain") {
            return LinearGradient(colors: [Color.gray, Color(red: 0.1, green: 0.1, blue: 0.3)], startPoint: .top, endPoint: .bottom)
        } else if cond.contains("karlı") || cond.contains("snow") {
            return LinearGradient(colors: [Color.white, Color.blue.opacity(0.3)], startPoint: .top, endPoint: .bottom)
        } else if cond.contains("gece") {
            return LinearGradient(colors: [Color(red: 0.02, green: 0.02, blue: 0.1), .black], startPoint: .top, endPoint: .bottom)
        } else {
            return LinearGradient(colors: [.blue, .black], startPoint: .top, endPoint: .bottom)
        }
    }
}

// MARK: - 2. ÜST MENÜ (UPPER BAR)
struct UpperBarView: View {
    @Binding var isFavorite: Bool
    let city: CityWeather
    @ObservedObject var viewModel: WeatherViewModel
    var scrollOffset: CGFloat = 0
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            // Scroll offset -150'yi geçince üstte tarih yerine şehrin adı ve derecesi belirir.
            if scrollOffset < -150 {
                Text("\(city.name) | \(city.temp)°")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white).transition(.opacity)
            } else {
                // Türkiye lokasyonuna göre Türkçe tarih formatı
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "tr_TR"))))
                    .font(.subheadline).fontWeight(.medium).foregroundColor(.white.opacity(0.7)).transition(.opacity)
            }
            
            HStack {
                // Geri Çıkma Butonu
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        .padding(10).background(.ultraThinMaterial).clipShape(Circle())
                }
                
                Spacer()
                
                // Favori (Kalp) Butonu: Basıldığında Firebase'e ekler veya siler.
                Button {
                    isFavorite.toggle()
                    if isFavorite {
                        viewModel.addCityToFirebase(city: city)
                    } else {
                        viewModel.removeCityFromFirebase(cityName: city.name)
                    }
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.title2)
                        .foregroundColor(isFavorite ? .red : .white)
                        .padding(10).background(.ultraThinMaterial).clipShape(Circle())
                }
            }
        }
        .padding(.horizontal).padding(.top, 10)
        .animation(.easeInOut, value: scrollOffset < -150)
    }
}

// MARK: - 3. ANA BİLGİ GÖRÜNÜMÜ
// Şehrin dev boyuttaki ikonu ve mevcut sıcaklık değeri.
struct MainWeatherInfoView: View {
    let city: CityWeather
    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: city.icon).font(.system(size: 100)).symbolRenderingMode(.multicolor).shadow(radius: 10)
            Text(city.name).font(.system(size: 40, weight: .bold))
            Text("\(city.temp)°").font(.system(size: 85, weight: .thin))
        }.foregroundColor(.white)
    }
}

// MARK: - 4. SAATLİK TAHMİN BÖLÜMÜ
// Önümüzdeki saatler için yatay kaydırılabilir (ScrollView) kutucukları çizer.
struct HourlyForecastView: View {
    let city: CityWeather
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("GÜN İÇİ SAATLİK HAVA TAHMİNİ")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            
            if city.hourlyForecast.isEmpty {
                ProgressView().tint(.white).frame(maxWidth: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(city.hourlyForecast) { hour in
                            HourlyBox(time: hour.time,
                                      icon: hour.icon,
                                      temp: hour.temp,
                                      percentage: hour.pop) // pop: Yağış İhtimali
                        }
                    }.padding(.horizontal)
                }
            }
        }
    }
}

// MARK: - 5. SICAkLIK GRAFİĞİ (APPLE CHARTS)
// Gelen saatlik verilerin derecelerini birleştirip dalgalı bir grafik (LineChart) çizer.
struct TemperatureChartView: View {
    let city: CityWeather
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GÜNLÜK SICAKLIK DEĞİŞİMİ GRAFİĞİ")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            
            VStack {
                if city.hourlyForecast.isEmpty {
                    ProgressView().tint(.white).frame(height: 120).frame(maxWidth: .infinity)
                } else {
                    Chart {
                        ForEach(city.hourlyForecast) { hour in
                            let tempValue = Double(hour.temp) ?? 0.0
                            
                            // Çizgi Grafiği
                            LineMark(x: .value("Saat", hour.time), y: .value("Derece", tempValue))
                                .interpolationMethod(.catmullRom) // Çizgileri yumuşatıp kavisli yapar
                                .foregroundStyle(.white)
                                .lineStyle(StrokeStyle(lineWidth: 3))
                            
                            // Çizgi üzerindeki noktalar ve üstlerinde yazan derece değerleri
                            PointMark(x: .value("Saat", hour.time), y: .value("Derece", tempValue))
                                .foregroundStyle(.white)
                                .annotation(position: .top, spacing: 5) {
                                    Text("\(Int(tempValue))°")
                                        .font(.caption).fontWeight(.bold).foregroundColor(.white)
                                }
                            
                            // Çizginin altını dolduran şeffaf degrade renk
                            AreaMark(x: .value("Saat", hour.time), y: .value("Derece", tempValue))
                                .interpolationMethod(.catmullRom)
                                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom))
                        }
                    }
                    .frame(height: 120)
                    .chartYAxis(.hidden) // Y eksenindeki derece yazılarını gizler (Tasarım daha temiz durur)
                    .chartXAxis {
                        AxisMarks { _ in AxisValueLabel().foregroundStyle(.white.opacity(0.7)) }
                    }
                    // Grafiğin alt ve üst limitlerini, o günkü en düşük ve en yüksek sıcaklığa göre dinamik ayarlar
                    .chartYScale(domain: (city.hourlyForecast.compactMap { Double($0.temp) }.min() ?? 0) - 4 ... (city.hourlyForecast.compactMap { Double($0.temp) }.max() ?? 0) + 4)
                }
            }
            .padding()
            .premiumGlass()
            .padding(.horizontal)
        }
    }
}

// Saatlik tahmin yatay listesinin içindeki tekil kutucuk tasarımı
struct HourlyBox: View {
    let time: String, icon: String, temp: String, percentage: String
    var body: some View {
        VStack(spacing: 8) {
            Text(time).font(.caption).fontWeight(.semibold)
            Image(systemName: icon).font(.title2).symbolRenderingMode(.multicolor)
            Text("\(temp)°").font(.title3).fontWeight(.bold)
            
            // Su damlası ikonu ve yağış yüzdesi
            HStack(spacing: 2) {
                Image(systemName: "drop.fill").font(.system(size: 8))
                Text(percentage).font(.system(size: 10)).fontWeight(.bold)
            }
            .foregroundColor(.cyan)
        }
        .foregroundColor(.white).padding().frame(width: 75, height: 130)
        .premiumGlass(radius: 15)
    }
}

// MARK: - 6. RÜZGAR VE NEM KARTLARI
struct WindSquareCard: View {
    let city: CityWeather
    var body: some View {
        VStack (alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "wind").foregroundColor(.white.opacity(0.7))
                Text("ANLIK RÜZGAR HIZI").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.7))
            }
            // Pusula ikonu
            ZStack{
                Circle().stroke(Color.white.opacity(0.3) , lineWidth: 2 ).frame(width: 60, height: 60)
                Image(systemName: "location.north.fill").rotationEffect(.degrees(45)).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity , alignment: .center)
            
            VStack(alignment: .center , spacing: 2){
                Text("\(String(format: "%.1f", city.windSpeed)) km/s")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
                // Rüzgar 20 km/s üzerindeyse "Sert Rüzgar" uyarısı verir
                Text(city.windSpeed > 20 ? "Sert Rüzgar" : "Hafif Esinti")
                    .font(.caption2).foregroundColor(.white.opacity(0.7))
            }
            .frame(maxWidth: .infinity , alignment: .center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .premiumGlass()
    }
}

struct HumiditySquareCard: View {
    let city: CityWeather
    var body: some View {
        VStack(alignment:.leading , spacing: 8 ) {
            HStack {
                Image(systemName: "humidity").foregroundColor(.white.opacity(0.7))
                Text("GÜNCEL NEM ORANI").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.7))
            }
            
            // Yuvarlak İlerleme Çubuğu (Circular Progress Bar) tasarımı
            ZStack{
                Circle().stroke(Color.white.opacity(0.2) , lineWidth: 6).frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(city.humidity) / 100)
                    .stroke(style : StrokeStyle(lineWidth: 6 , lineCap: .round))
                    .foregroundColor(.blue.opacity(0.8))
                    .rotationEffect(.degrees(-90)) // Başlangıç noktasını yukarı (Saat 12 yönüne) alır
                
                Text("%\(city.humidity)")
                    .font(.headline).fontWeight(.bold).foregroundColor(.white)
            }
            .frame(maxWidth : .infinity , alignment: .center )
            
            Text("Hissedilen: \(city.feelsLike)°")
                .font(.caption2).foregroundColor(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .frame(maxWidth : .infinity)
        .frame(height: 160)
        .premiumGlass()
    }
}

// MARK: - 7. RADAR HARİTA SİSTEMİ (MAPKIT + OPENWEATHER)
// Apple'ın UIView yapısını SwiftUI'a bağlayan köprü (Bridge). Harita üzerine API'den gelen radar görsellerini giydirir.
struct WeatherMapBridge: UIViewRepresentable {
    let city: CityWeather
    let layerType: String // "precipitation_new" (Yağış) veya "wind_new" (Rüzgar)
    let apiKey = "98924265b259eba4d92303212e8f832c"

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .standard // Radar renkleri net gözüksün diye uydu yerine standart harita kullanılır
        mapView.isRotateEnabled = false
        
        // Haritayı seçilen şehre odaklar ve yakınlaştırır (Zoom)
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
        mapView.setRegion(region, animated: true)
        
        // Şehrin tam ortasına kırmızı iğne (Pin) bırakır
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: city.latitude, longitude: city.longitude)
        annotation.title = city.name
        mapView.addAnnotation(annotation)
        
        updateOverlay(mapView)
        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        updateOverlay(uiView) // Rüzgar/Yağış seçimi değiştiğinde haritayı günceller
    }

    private func updateOverlay(_ mapView: MKMapView) {
        // Üst üste binmemesi için önce eski radar katmanını temizler
        mapView.removeOverlays(mapView.overlays)
        
        // OpenWeather'ın URL yapısına uygun formatta (Tile System) harita üstü boyamayı ayarlar
        let template = "https://tile.openweathermap.org/map/\(layerType)/{z}/{x}/{y}.png?appid=\(apiKey)"
        let overlay = MKTileOverlay(urlTemplate: template)
        overlay.canReplaceMapContent = false // Harita yolları alttan gözükmeye devam etsin
        mapView.addOverlay(overlay, level: .aboveLabels) // Radar renklerini şehir isimlerinin üstüne basar
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tileOverlay)
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

// Radar haritasının SwiftUI'daki dış çerçevesi ve menü butonları (Rüzgar/Yağış değiştirici)
struct WeatherRadarMapView: View {
    let city: CityWeather
    @State private var selectedMode = 0 // 0: Rüzgar, 1: Yağış

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CANLI HAVA DURUMU RADARI")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal)
            
            VStack(spacing: 15) {
                // MOD SEÇİCİ (Segmented Control tarzında özel tasarım)
                HStack(spacing: 0) {
                    Button(action: { selectedMode = 0 }) {
                        Text("Rüzgar")
                            .font(.subheadline).fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMode == 0 ? Color.blue.opacity(0.8) : Color.clear)
                            .foregroundColor(selectedMode == 0 ? .white : .white.opacity(0.6))
                            .cornerRadius(12)
                    }
                    
                    Button(action: { selectedMode = 1 }) {
                        Text("Yağış")
                            .font(.subheadline).fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(selectedMode == 1 ? Color.indigo.opacity(0.8) : Color.clear)
                            .foregroundColor(selectedMode == 1 ? .white : .white.opacity(0.6))
                            .cornerRadius(12)
                    }
                }
                .padding(4)
                .background(Color.black.opacity(0.3))
                .cornerRadius(16)
                .padding(.horizontal)

                // Radarın gösterildiği alan
                WeatherMapBridge(
                    city: city,
                    layerType: selectedMode == 0 ? "wind_new" : "precipitation_new"
                )
                .frame(height: 300)
                .cornerRadius(15)
                .padding(.horizontal)
                .shadow(radius: 10)
            }
            .padding(.vertical)
            .premiumGlass()
            .padding(.horizontal)
        }
    }
}

// MARK: - 8. 5 GÜNLÜK TAHMİN (SWIPE KART)
// TabView kullanılarak sayfa sayfa (yana kaydırmalı) tasarlanmış günlük tahmin bileşeni.
struct WeeklySwipeCardView : View {
    let forecast: [DailyForecast]
    @State private var selectedIndex = 0
    
    var body : some View {
        VStack(spacing : 15) {
            // Başlık ve Sayfa Noktaları (Page Indicator)
            HStack {
                Text("ÖNÜMÜZDEKİ 5 GÜNLÜK TAHMİN")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                
                if !forecast.isEmpty {
                    HStack(spacing:6){
                        ForEach(0..<forecast.count , id:\.self) { index in
                            Circle()
                                .fill(selectedIndex == index ?  Color.white : Color.gray.opacity(0.3))
                                .frame(width: 6 , height: 6)
                        }
                    }
                }
            }
            .padding(.horizontal , 20 )
            .padding(.top , 20 )
            
            if forecast.isEmpty {
                VStack {
                    Spacer()
                    ProgressView().tint(.white)
                    Text("Veriler çekiliyor...").font(.caption).foregroundColor(.white.opacity(0.7)).padding()
                    Spacer()
                }
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(forecast.enumerated()), id : \.offset ) { index , day in
                        VStack(spacing : 25 ){
                            Text(day.dayName).font(.title).fontWeight(.bold).foregroundColor(.white)
                            Image(systemName : day.icon).font(.system(size: 90)).symbolRenderingMode(.multicolor).shadow(radius: 10)
                            
                            // Gündüz ve Gece sıcaklıklarının yan yana gösterimi
                            HStack(spacing : 50) {
                                VStack(spacing : 5) {
                                    Text("Gündüz").font(.subheadline).foregroundColor(.white.opacity(0.7))
                                    Text("\(day.dayTemp)˚").font(.system(size: 30 , weight: .bold)).foregroundColor(.white)
                                }
                                VStack(spacing: 5) {
                                    Text("Gece").font(.subheadline).foregroundColor(.white.opacity(0.7))
                                    Text("\(day.nightTemp)˚").font(.system(size: 30 , weight: .bold )).foregroundColor(.white.opacity(0.8))
                                }
                            }
                            Spacer()
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // Alt kısımdaki standart noktaları gizler, bizim üstte çizdiğimizi kullanırız.
            }
        }
        .frame(height:350)
        .premiumGlass()
        .padding(.horizontal)
    }
}

// MARK: - YARDIMCI SİSTEMLER VE TASARIM MODİFİYELERİ (MODIFIERS)

// Ekran kaydırma miktarını (scroll) hafızada tutmak için kullanılan sistem değişkeni.
struct ScrollOffsetKey : PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value : inout CGFloat , nextValue : () -> CGFloat) {
        value += nextValue()
    }
}

// Uygulamaya "Buzlu Cam" (Glassmorphism) efektini veren özel tasarım kalıbı.
// Arka planı bulanıklaştırır ve hafif parlak beyaz bir çerçeve ekler.
struct PremiumGlassModifier: ViewModifier {
    var radius: CGFloat
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: radius)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: radius)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.cyan.opacity(0.1),
                                    Color.blue.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                .shadow(color: .black.opacity(0.2), radius: 15, x: 0, y: 10)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.1), .white.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
    }
}

// Her objeye uzun uzun "PremiumGlassModifier" yazmamak için oluşturulmuş kısa fonksiyon.
extension View {
    func premiumGlass(radius: CGFloat = 20) -> some View {
        self.modifier(PremiumGlassModifier(radius: radius))
    }
}
