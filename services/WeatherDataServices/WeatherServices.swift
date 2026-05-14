import Foundation
import CoreLocation

// MARK: - VERİ MODELLERİ (JSON PARSING)
// OpenWeather API'den gelen karmaşık veriyi uygulamanın anlayacağı kalıplara sokarız.
struct WeatherResponse: Codable {
    let name: String
    let main: MainInfo
    let weather: [WeatherDetail]
    let wind: WindInfo
    let coord: CoordinateInfo
    let dt: TimeInterval
}

struct ForecastResponse: Codable {
    let list: [ForecastItem]
}

struct MainInfo: Codable {
    let temp: Double
    let humidity: Int
    let feels_like: Double
    let temp_min: Double?
    let temp_max: Double?
}

struct WeatherDetail: Codable {
    let description: String
    let id: Int
    let icon: String // Gece/Gündüz ayrımı için API'den gelen ikon kodu.
}

struct WindInfo: Codable {
    let speed: Double
}

struct CoordinateInfo: Codable {
    let lat: Double
    let lon: Double
}

// MARK: - HAVA DURUMU SERVİSİ
// İnternet üzerinden hava durumu verilerini çeken ve işleyen ana motor.
class WeatherService {
    private let apiKey = "98924265b259eba4d92303212e8f832c"
    
    // Şehir ismi ile (Örn: "Kahramanmaraş") veri çekme fonksiyonu.
    func fetchWeather(cityName: String) async throws -> CityWeather {
        let weatherUrl = "https://api.openweathermap.org/data/2.5/weather?q=\(cityName)&appid=\(apiKey)&units=metric&lang=tr"
        let forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?q=\(cityName)&appid=\(apiKey)&units=metric&lang=tr"
        
        return try await performDualRequest(weatherUrl: weatherUrl, forecastUrl: forecastUrl)
    }
    
    // GPS koordinatları (Enlem/Boylam) ile veri çekme fonksiyonu.
    func fetchWeather(lat: Double, lon: Double) async throws -> CityWeather {
        let weatherUrl = "https://api.openweathermap.org/data/2.5/weather?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=tr"
        let forecastUrl = "https://api.openweathermap.org/data/2.5/forecast?lat=\(lat)&lon=\(lon)&appid=\(apiKey)&units=metric&lang=tr"
        
        return try await performDualRequest(weatherUrl: weatherUrl, forecastUrl: forecastUrl)
    }
    
    // MARK: - ASENKRON VERİ TRANSFERİ
    // Hem anlık durumu hem de 5 günlük tahmini aynı anda çeken ana işlemci.
    private func performDualRequest(weatherUrl: String, forecastUrl: String) async throws -> CityWeather {
        // URL'deki Türkçe karakterleri internet uyumlu hale getirir (Encoding).
        guard let encodedWUrl = weatherUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let wUrl = URL(string: encodedWUrl),
              let encodedFUrl = forecastUrl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let fUrl = URL(string: encodedFUrl) else {
            throw URLError(.badURL)
        }
        
        // async let sayesinde iki farklı isteği aynı anda ateşler, zaman kazanırız.
        async let (wData, _) = URLSession.shared.data(from: wUrl)
        async let (fData, _) = URLSession.shared.data(from: fUrl)
        
        // Gelen JSON verilerini yukarıda tanımladığımız modellere parçalar.
        let weatherResponse = try JSONDecoder().decode(WeatherResponse.self, from: try await wData)
        let forecastResponse = try JSONDecoder().decode(ForecastResponse.self, from: try await fData)
        
        // Karmaşık tahmini temizler ve 24 saatlik veriye dönüştürür.
        let processedForecast = processForecast(forecastResponse.list)
        let currentIconCode = weatherResponse.weather.first?.icon ?? "01d"
        
        // Gelecek 24 saati temsil eden ilk 8 tahmini (3'er saatlik aralarla) hazırlar.
        let hourlyData = forecastResponse.list.prefix(8).map { item -> HourlyForecast in
            let time = formatTimestamp(item.dt)
            let temp = String(format: "%.0f", item.main.temp)
            let iconCode = item.weather.first?.icon ?? "01d"
            let icon = mapWeatherIcon(id: item.weather.first?.id ?? 800, iconCode: iconCode)
            let popValue = Int((item.pop ?? 0.0) * 100)
            
            return HourlyForecast(time: time, icon: icon, temp: temp, pop: "%\(popValue)")
        }
        
        // Uygulamanın her yerinde kullanılacak temizlenmiş tek bir CityWeather nesnesi döner.
        return CityWeather(
            name: weatherResponse.name,
            temp: String(format: "%.0f", weatherResponse.main.temp),
            description: weatherResponse.weather.first?.description ?? "Veri yok",
            time: formatTimestamp(weatherResponse.dt),
            icon: mapWeatherIcon(id: weatherResponse.weather.first?.id ?? 800, iconCode: currentIconCode),
            humidity: weatherResponse.main.humidity,
            windSpeed: weatherResponse.wind.speed,
            feelsLike: String(format: "%.0f", weatherResponse.main.feels_like),
            latitude: weatherResponse.coord.lat,
            longitude: weatherResponse.coord.lon,
            dailyForecast: processedForecast,
            hourlyForecast: hourlyData
        )
    }

    // MARK: - VERİ AYIKLAMA MANTIKLARI
    // 3 saatlik ham listeyi "Bugün, Yarın, Çarşamba" gibi günlere bölen zeka motoru.
    private func processForecast(_ list: [ForecastItem]) -> [DailyForecast] {
        var dailyDict: [Date: [ForecastItem]] = [:]
        let calendar = Calendar.current
        
        // Verileri cihazın yerel saatine göre günlere gruplar.
        for item in list {
            let date = Date(timeIntervalSince1970: item.dt)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            if let midnight = calendar.date(from: components) {
                dailyDict[midnight, default: []].append(item)
            }
        }
        
        var result: [DailyForecast] = []
        let sortedDates = dailyDict.keys.sorted()
        
        for date in sortedDates {
            guard let items = dailyDict[date] else { continue }
            
            // O günün en yüksek ve en düşük derecelerini filtreler.
            let maxTemp = items.compactMap { $0.main.temp_max }.max() ?? items[0].main.temp
            let minTemp = items.compactMap { $0.main.temp_min }.min() ?? items[0].main.temp
            
            // Günlük ikonu belirlemek için gecenin verisini değil, günün en sıcak (gündüz) anını baz alır.
            let daytimeItem = items.max(by: { $0.main.temp < $1.main.temp }) ?? items[0]
            let iconCode = daytimeItem.weather.first?.icon ?? "01d"
            let icon = mapWeatherIcon(id: daytimeItem.weather.first?.id ?? 800, iconCode: iconCode)
            
            // Tarih bilgisini kullanıcı dostu isimlere çevirir.
            var dayName = ""
            if calendar.isDateInToday(date) {
                dayName = "Bugün"
            } else if calendar.isDateInTomorrow(date) {
                dayName = "Yarın"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "EEEE"
                formatter.locale = Locale(identifier: "tr_TR")
                dayName = formatter.string(from: date).capitalized
            }
            
            result.append(DailyForecast(dayName: dayName, icon: icon, dayTemp: String(format: "%.0f", maxTemp), nightTemp: String(format: "%.0f", minTemp)))
        }
        
        return result
    }
    
    // Saat verisini "14:30" formatına çevirir.
    private func formatTimestamp(_ timestamp: TimeInterval) -> String {
        let date = Date(timeIntervalSince1970: timestamp)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    // MARK: - İKON HARİTALAMA (SF Symbols)
    // API'den gelen sayısal ID'leri Apple'ın standart SF Symbols ikonlarına dönüştürür.
    private func mapWeatherIcon(id: Int, iconCode: String) -> String {
        let isDay = iconCode.contains("d") // Gündüz mü Gece mi kontrolü
        
        switch id {
        case 200...232: return "cloud.bolt.fill"
        case 300...321: return "cloud.drizzle.fill"
        case 500...531: return "cloud.heavyrain.fill"
        case 600...622: return "snowflake"
        case 701...781: return "cloud.fog.fill"
        case 800: return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 801...802: return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 803...804: return "cloud.fill"
        default: return isDay ? "sun.max.fill" : "moon.stars.fill"
        }
    }
}
