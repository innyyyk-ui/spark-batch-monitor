import SwiftUI
import UserNotifications

struct ContentView: View {
    @State private var backendURL = "https://spark-batch-monitor.onrender.com"
    @State private var minMoney: Double = 8.0
    @State private var maxMiles: Double = 5.0
    @State private var maxItems: Double = 20.0
    @State private var autoAccept = false
    @State private var acceptDelayMs: Double = 2000
    @State private var isMonitoring = false
    @State private var statusText = "🔴 Stopped"
    @State private var selectedTab = 0
    @State private var lastUpdate: String = "Ready"
    @State private var foundCount: Int = 0
    @State private var acceptedCount: Int = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // ===== TAB 1: MONITOR =====
            VStack(spacing: 20) {
                // Status Card
                VStack(spacing: 12) {
                    HStack {
                        Text("Status")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(statusText)
                            .font(.headline)
                            .fontWeight(.bold)
                    }
                    
                    HStack {
                        Text("Last Update")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text(lastUpdate)
                            .font(.caption2)
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                
                // Stats
                HStack(spacing: 12) {
                    VStack(spacing: 6) {
                        Text("\(foundCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Found")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(10)
                    
                    VStack(spacing: 6) {
                        Text("\(acceptedCount)")
                            .font(.headline)
                            .fontWeight(.bold)
                        Text("Accepted")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(10)
                }
                
                // Action Button
                if isMonitoring {
                    Button(action: stopMonitoring) {
                        HStack {
                            Image(systemName: "stop.circle.fill")
                            Text("Stop Monitoring")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .cornerRadius(12)
                    }
                } else {
                    Button(action: startMonitoring) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                            Text("Start Monitoring SPARK")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .cornerRadius(12)
                    }
                }
                
                Spacer()
            }
            .padding()
            .tabItem { 
                Label("Monitor", systemImage: "radio.fill") 
            }
            .tag(0)
            
            // ===== TAB 2: SETTINGS =====
            VStack {
                Form {
                    Section("Backend URL") {
                        TextField("https://spark-monitor-xxx.onrender.com", text: $backendURL)
                            .textInputAutocapitalization(.none)
                            .onChange(of: backendURL) { _ in
                                saveSettings()
                            }
                    }
                    
                    Section("Auto-Accept (HUMANLIKE)") {
                        Toggle("Enable Auto-Accept", isOn: $autoAccept)
                            .onChange(of: autoAccept) { _ in
                                saveSettings()
                                sendConfigToBackend()
                            }
                        
                        if autoAccept {
                            HStack {
                                Text("Accept Delay")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(acceptDelayMs))ms")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            Slider(value: $acceptDelayMs, in: 500...5000, step: 100)
                                .onChange(of: acceptDelayMs) { _ in
                                    saveSettings()
                                    sendConfigToBackend()
                                }
                            
                            Text("Humanlike range: 1000-3000ms (faster = more risk)")
                                .font(.caption2)
                                .foregroundColor(.orange)
                        } else {
                            Text("You will receive notifications. Accept manually in Spark app.")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                    }
                    
                    Section("Minimum Money") {
                        HStack {
                            Text("$\(String(format: "%.2f", minMoney))")
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                            Text("$1 - $50")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $minMoney, in: 1...50, step: 0.5)
                            .onChange(of: minMoney) { _ in
                                saveSettings()
                                sendConfigToBackend()
                            }
                    }
                    
                    Section("Maximum Miles") {
                        HStack {
                            Text("\(String(format: "%.1f", maxMiles)) mi")
                                .font(.headline)
                                .foregroundColor(.blue)
                            Spacer()
                            Text("0.5 - 20 mi")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $maxMiles, in: 0.5...20, step: 0.5)
                            .onChange(of: maxMiles) { _ in
                                saveSettings()
                                sendConfigToBackend()
                            }
                    }
                    
                    Section("Maximum Items") {
                        HStack {
                            Text("\(Int(maxItems))")
                                .font(.headline)
                                .foregroundColor(.orange)
                            Spacer()
                            Text("1 - 70 items")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        Slider(value: $maxItems, in: 1...70, step: 1)
                            .onChange(of: maxItems) { _ in
                                saveSettings()
                                sendConfigToBackend()
                            }
                    }
                    
                    Section("Safety") {
                        Text("✅ Auto-Accept is humanlike (1-5 sec delays)")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("✅ Real GPS location (no spoofing)")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Text("✅ Manual accept recommended for zero ban risk")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
            }
            .tabItem { 
                Label("Settings", systemImage: "slider.horizontal.3") 
            }
            .tag(1)
            
            // ===== TAB 3: STATS =====
            VStack {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    
                    Text("Statistics")
                        .font(.headline)
                    
                    Text("Batch statistics will appear here")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .tabItem { 
                Label("Stats", systemImage: "chart.bar") 
            }
            .tag(2)
        }
        .accentColor(.orange)
        .onAppear {
            loadSettings()
            requestNotificationPermission()
        }
    }
    
    // MARK: - Functions
    func loadSettings() {
        backendURL = UserDefaults.standard.string(forKey: "spark_backendURL") ?? "https://spark-monitor-xxx.onrender.com"
        minMoney = UserDefaults.standard.double(forKey: "spark_minMoney") == 0 ? 8.0 : UserDefaults.standard.double(forKey: "spark_minMoney")
        maxMiles = UserDefaults.standard.double(forKey: "spark_maxMiles") == 0 ? 5.0 : UserDefaults.standard.double(forKey: "spark_maxMiles")
        maxItems = UserDefaults.standard.double(forKey: "spark_maxItems") == 0 ? 20.0 : UserDefaults.standard.double(forKey: "spark_maxItems")
        autoAccept = UserDefaults.standard.bool(forKey: "spark_autoAccept")
        acceptDelayMs = UserDefaults.standard.double(forKey: "spark_acceptDelayMs") == 0 ? 2000 : UserDefaults.standard.double(forKey: "spark_acceptDelayMs")
    }
    
    func saveSettings() {
        UserDefaults.standard.set(backendURL, forKey: "spark_backendURL")
        UserDefaults.standard.set(minMoney, forKey: "spark_minMoney")
        UserDefaults.standard.set(maxMiles, forKey: "spark_maxMiles")
        UserDefaults.standard.set(maxItems, forKey: "spark_maxItems")
        UserDefaults.standard.set(autoAccept, forKey: "spark_autoAccept")
        UserDefaults.standard.set(acceptDelayMs, forKey: "spark_acceptDelayMs")
    }
    
    func sendConfigToBackend() {
        guard !backendURL.isEmpty else { return }
        
        let config: [String: Any] = [
            "minMoney": minMoney,
            "maxMiles": maxMiles,
            "maxItems": Int(maxItems),
            "autoAccept": autoAccept,
            "acceptDelayMs": Int(acceptDelayMs)
        ]
        
        DispatchQueue.global(qos: .background).async {
            guard let url = URL(string: "\(backendURL)/config") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.timeoutInterval = 3
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: config)
                URLSession.shared.dataTask(with: request).resume()
            } catch {
                print("Error: \(error)")
            }
        }
    }
    
    func startMonitoring() {
        guard !backendURL.isEmpty else {
            statusText = "❌ Configure URL"
            return
        }
        
        isMonitoring = true
        statusText = "🟢 Monitoring SPARK"
        foundCount = 0
        acceptedCount = 0
        
        DispatchQueue.global(qos: .background).async {
            guard let url = URL(string: "\(backendURL)/start") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            
            URLSession.shared.dataTask(with: request) { _, _, error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if error != nil {
                        statusText = "❌ Connection Error"
                        isMonitoring = false
                    } else {
                        lastUpdate = "Started"
                    }
                }
            }.resume()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        statusText = "⏹️ Stopped"
        
        DispatchQueue.global(qos: .background).async {
            guard let url = URL(string: "\(backendURL)/stop") else { return }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 5
            
            URLSession.shared.dataTask(with: request) { _, _, error in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if error == nil {
                        lastUpdate = "Stopped"
                    }
                }
            }.resume()
        }
    }
    
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
