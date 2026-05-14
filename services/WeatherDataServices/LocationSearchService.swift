import SwiftUI
import MapKit
import Combine

// MARK: - ARAMA SERVİSİ
// Apple Haritalar (MapKit) altyapısını kullanarak şehir ve ilçe araması yapan motor.
class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchQuery = "" // Kullanıcının klavyeden yazdığı metin.
    @Published var searchResults: [MKLocalSearchCompletion] = [] // Haritadan gelen eşleşen yerler.
    
    private var completer: MKLocalSearchCompleter
    private var cancellable: AnyCancellable?

    override init() {
        completer = MKLocalSearchCompleter()
        // Sadece adres ve yerleşim birimlerini getirir (Restoran, kafe gibi yerleri eler).
        completer.resultTypes = .address
        super.init()
        completer.delegate = self
        
        // DEBOUNCE SİSTEMİ: Kullanıcı yazarken her harfte istek atmak yerine 300ms bekler.
        // Bu sayede hem internet harcanmaz hem de uygulama kasmaz.
        cancellable = $searchQuery
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] query in
                if query.isEmpty {
                    self?.searchResults = []
                } else {
                    self?.completer.queryFragment = query
                }
            }
    }

    // Apple servisinden sonuçlar başarıyla geldiğinde listeyi günceller.
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        self.searchResults = completer.results
    }
    
    // İnternet veya servis kaynaklı bir arama hatası olursa devreye girer.
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Arama hatası: \(error.localizedDescription)")
    }
}
