//
//  ContentView.swift
//  motodash
//
//  Created by Kenny Timmer on 14/06/2025.
//

import SwiftUI
import MapKit
import UIKit

struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        
        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
    
    var body: some View {
        TabView {
            SpeedometerView()
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "speedometer")
                    Text("Speedometer")
                }
            
            MapViewWithSpeedometer()
                .environmentObject(locationManager)
                .tabItem {
                    Image(systemName: "map")
                    Text("Kaart")
                }
        }
        .accentColor(Color(red: 246/255, green: 166/255, blue: 27/255))
        .onAppear {
            locationManager.requestPermission()
            locationManager.startUpdating()
        }
    }
}

#Preview {
    ContentView()
}
