import WidgetKit
import SwiftUI

// 1. YAKIT (Veri Modeli - Detaylı Versiyon)
struct WeatherEntry: TimelineEntry {
    let date: Date
    let cityName: String
    let temp: String
    let description: String
    let icon: String
    let humidity: String
    let windSpeed: String
}

// 2. DİSTRİBÜTÖR VE ZAMANLAYICI (API & Favori Şehir)
struct WeatherProvider: TimelineProvider {
    
    // Uygulama Grubu (App Group) üzerinden favori şehri oku
    func getFavoriSehir() -> String {
        let sharedDefaults = UserDefaults(suiteName: "group.com.omerzibabo.weather")
        return sharedDefaults?.string(forKey: "selectedCity") ?? "Kahramanmaras"
    }

    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: Date(), cityName: "Yükleniyor...", temp: "0", description: "Bekleyiniz", icon: "cloud.sun.fill", humidity: "0", windSpeed: "0")
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> ()) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> ()) {
        let sehir = getFavoriSehir()
        let apiKey = "98924265b259eba4d92303212e8f832c" // OpenWeatherMap Key
        let urlString = "https://api.openweathermap.org/data/2.5/weather?q=\(sehir)&units=metric&appid=\(apiKey)"
        
        guard let url = URL(string: urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "") else {
            completion(Timeline(entries: [placeholder(in: context)], policy: .atEnd))
            return
        }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let main = json["main"] as? [String: Any],
               let weather = (json["weather"] as? [[String: Any]])?.first,
               let wind = json["wind"] as? [String: Any] {
                
                let entry = WeatherEntry(
                    date: Date(),
                    cityName: json["name"] as? String ?? sehir,
                    temp: "\(Int(main["temp"] as? Double ?? 0))",
                    description: weather["description"] as? String ?? "",
                    icon: "cloud.sun.fill", // Hava durumuna göre ikon eşleşmesi eklenebilir
                    humidity: "\(main["humidity"] as? Int ?? 0)",
                    windSpeed: "\(Int(wind["speed"] as? Double ?? 0))"
                )
                
                // 30 dakikada bir güncellenme kuralı
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
                completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
            } else {
                completion(Timeline(entries: [placeholder(in: context)], policy: .atEnd))
            }
        }.resume()
    }
}

// 3. KAPORTA TASARIMI (Görünüm Seçici)
struct WeatherWidgetEntryView : View {
    var entry: WeatherProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                SmallWidgetView(entry: entry)
            case .systemMedium:
                MediumWidgetView(entry: entry)
            default:
                SmallWidgetView(entry: entry)
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(gradient: Gradient(colors: [Color(red: 0.02, green: 0.05, blue: 0.12), .black]), startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

// 🏎️ KÜÇÜK (SMALL) TASARIM
struct SmallWidgetView: View {
    var entry: WeatherEntry
    var body: some View {
        VStack(spacing: 8) {
            Text(entry.cityName).font(.caption).bold().foregroundColor(.gray)
            Image(systemName: "sun.max.fill").font(.title).foregroundColor(.yellow)
            Text("\(entry.temp)°").font(.system(size: 32, weight: .bold)).foregroundColor(.white)
            Text(entry.description).font(.caption2).foregroundColor(.gray)
        }
    }
}

// 🏎️ YATAY (MEDIUM) TASARIM
struct MediumWidgetView: View {
    var entry: WeatherEntry
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading) {
                Text(entry.cityName).font(.headline).foregroundColor(.white)
                HStack {
                    Image(systemName: "sun.max.fill").font(.system(size: 40)).foregroundColor(.yellow)
                    Text("\(entry.temp)°").font(.system(size: 45, weight: .bold)).foregroundColor(.white)
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 10) {
                DetailRow(icon: "humidity", label: "Nem", value: "%\(entry.humidity)")
                DetailRow(icon: "wind", label: "Rüzgar", value: "\(entry.windSpeed) km/s")
                DetailRow(icon: "thermometer.low", label: "Hissedilen", value: "\(Int(entry.temp)! - 2)°")
            }
        }
        .padding()
    }
}

struct DetailRow: View {
    var icon: String; var label: String; var value: String
    var body: some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.gray)
            Text(value).font(.caption).fontWeight(.bold).foregroundColor(.white)
            Image(systemName: icon).foregroundColor(.cyan).font(.caption)
        }
    }
}

// 4. WIDGET ANA MOTORU
struct WeatherWidget: Widget {
    let kind: String = "WeatherWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherProvider()) { entry in
            WeatherWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Hava Durumu Asistanı")
        .description("Favori şehrinin havası her an ekranında.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
