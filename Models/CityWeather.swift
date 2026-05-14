import Foundation

struct CityWeather: Identifiable {
    let id = UUID()
    let name: String
    let tep: String
    let description: String
    let time: String
    let icon: String
}
