import SwiftUI
import CoreLocation
import MapKit
import Combine

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

final class MapViewModel: ObservableObject {
    let recenteringRequest = PassthroughSubject<Void, Never>()
}

class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    @Published var speed: Double = 0.0
    @Published var averageSpeed: Double = 0.0
    @Published var tripDistance: Double = 0.0
    @Published var heading: String = "--"
    @Published var currentLocation: CLLocation?
    @Published var deviceHeading: CLLocationDirection = 0.0
    let userAnnotation = MKPointAnnotation()
    private var lastLocation: CLLocation?
    private var speedSum: Double = 0
    private var speedReadings: Int = 0
    private let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
    let maxSpeed: Double = 220
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 1
        locationManager.activityType = .automotiveNavigation
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.pausesLocationUpdatesAutomatically = false
    }
    
    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        locationManager.startUpdatingLocation()
        locationManager.startUpdatingHeading()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        let currentSpeed = max(0, location.speed * 3.6)
        speed = min(currentSpeed, maxSpeed)
        if let last = lastLocation {
            let distance = location.distance(from: last)
            if distance > 0.5 { // filter out GPS noise
                tripDistance += distance
            }
        }
        lastLocation = location
        // Average speed
        if currentSpeed > 1 {
            speedSum += currentSpeed
            speedReadings += 1
            averageSpeed = speedSum / Double(speedReadings)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        let index = Int((newHeading.trueHeading + 22.5) / 45.0) & 7
        heading = directions[index]
        self.deviceHeading = newHeading.trueHeading
    }
}

struct SpeedometerView: View {
    @EnvironmentObject var locationManager: LocationManager
    let maxSpeed: Double = 220
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            VStack(spacing: 0) {
                // Heading (compass)
                HStack {
                    Spacer()
                    VStack(spacing: 2) {
                        Image(systemName: "location.north.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(orange)
                        Text(locationManager.heading)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(orange)
                    }
                    Spacer()
                }
                .padding(.top, 24)
                Spacer()
                // Snelheid gecentreerd
                VStack(spacing: 0) {
                    Text("\(Int(locationManager.speed))")
                        .font(.system(size: 100, weight: .bold, design: .rounded))
                        .foregroundColor(orange)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                    Text("KM/H")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(orange)
                        .padding(.top, 2)
                    SpeedBar(progress: locationManager.speed / maxSpeed)
                        .frame(height: 18)
                        .frame(minWidth: 100, maxWidth: 180)
                        .padding(.top, 24)
                }
                Spacer()
                // AVG en TRIP onderaan
                HStack {
                    StatBlockSmall(title: "AVG", value: String(format: "%.0f", locationManager.averageSpeed))
                    Spacer()
                    StatBlockSmall(title: "TRIP", value: String(format: "%.1f", locationManager.tripDistance/1000))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 32)
            }
        }
    }
    var orange: Color {
        Color(red: 246/255, green: 166/255, blue: 27/255)
    }
}

struct SpeedBar: View {
    var progress: Double // 0.0 ... 1.0
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(red: 35/255, green: 34/255, blue: 35/255))
                Capsule()
                    .fill(LinearGradient(gradient: Gradient(colors: [Color.yellow, Color.orange]), startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(geo.size.width * progress, 8))
                    .shadow(color: Color.yellow.opacity(0.2), radius: 6, x: 0, y: 0)
            }
        }
    }
}

struct StatBlockSmall: View {
    let title: String
    let value: String
    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 246/255, green: 166/255, blue: 27/255))
                .shadow(color: .black.opacity(0.7), radius: 2)
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Color(red: 246/255, green: 166/255, blue: 27/255).opacity(0.8))
                .shadow(color: .black.opacity(0.7), radius: 2)
        }
        .frame(minWidth: 60)
    }
}

struct MetricView: View {
    let value: String
    let label: String
    var fixedWidth: Bool = false
    private let textColor = Color(red: 246/255, green: 166/255, blue: 27/255)

    var body: some View {
        VStack {
            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
            Text(label)
                .font(.headline)
                .foregroundColor(textColor)
                .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
        }
        .if(!fixedWidth) { view in
             view.frame(maxWidth: .infinity)
        }
    }
}

struct MapView: UIViewRepresentable {
    @ObservedObject var locationManager: LocationManager
    @ObservedObject var viewModel: MapViewModel
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.userTrackingMode = .followWithHeading
        mapView.mapType = .standard
        mapView.isZoomEnabled = true
        mapView.isScrollEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsCompass = true
        mapView.overrideUserInterfaceStyle = .dark
        
        context.coordinator.setupBindings(for: mapView)
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView
        private var recenterSubscription: AnyCancellable?
        
        init(parent: MapView) {
            self.parent = parent
        }
        
        func setupBindings(for mapView: MKMapView) {
            recenterSubscription = parent.viewModel.recenteringRequest
                .sink { [weak mapView] in
                    mapView?.setUserTrackingMode(.followWithHeading, animated: true)
                }
        }
    }
}

struct MapViewWithSpeedometer: View {
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var viewModel = MapViewModel()
    @Environment(\.verticalSizeClass) var verticalSizeClass

    var body: some View {
        ZStack {
            MapView(locationManager: locationManager, viewModel: viewModel)
                .edgesIgnoringSafeArea(.all)
            
            if verticalSizeClass == .compact {
                landscapeOverlay
            } else {
                portraitOverlay
            }
        }
    }
    
    var portraitOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                CompactSpeedometerView()
                    .padding(.top)
                Spacer()
            }
            
            recenterButton
        }
    }
    
    var landscapeOverlay: some View {
        ZStack(alignment: .bottomTrailing) {
            HStack {
                VStack(alignment: .leading, spacing: 20) {
                    MetricView(value: String(format: "%.0f", locationManager.speed), label: "KM/H", fixedWidth: true)
                    MetricView(value: String(format: "%.0f", locationManager.averageSpeed), label: "AVG", fixedWidth: true)
                    MetricView(value: String(format: "%.1f", locationManager.tripDistance / 1000), label: "TRIP", fixedWidth: true)
                }
                .padding()
                
                Spacer()
            }
            
            recenterButton
        }
    }
    
    var recenterButton: some View {
        Button(action: {
            viewModel.recenteringRequest.send()
        }) {
            Image(systemName: "location.north.line.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(red: 246/255, green: 166/255, blue: 27/255))
                .padding(12)
                .background(Color.black.opacity(0.6))
                .clipShape(Circle())
                .shadow(radius: 5)
        }
        .padding()
        .padding(.bottom, 20)
    }
}

struct CompactSpeedometerView: View {
    @EnvironmentObject var locationManager: LocationManager
    let maxSpeed: Double = 220
    
    var body: some View {
        HStack {
            MetricView(value: String(format: "%.0f", locationManager.averageSpeed), label: "AVG")
            MetricView(value: String(format: "%.0f", locationManager.speed), label: "KM/H")
            MetricView(value: String(format: "%.1f", locationManager.tripDistance / 1000), label: "TRIP")
        }
        .padding(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
        .padding(.horizontal)
    }
    
    var orange: Color {
        Color(red: 246/255, green: 166/255, blue: 27/255)
    }
}

#Preview {
    SpeedometerView()
        .environmentObject(LocationManager())
        .preferredColorScheme(.dark)
} 