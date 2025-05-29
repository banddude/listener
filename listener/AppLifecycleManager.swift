import SwiftUI
import Combine

class AppLifecycleManager: ObservableObject {
    static let shared = AppLifecycleManager()
    
    @Published var isActive = true
    
    private init() {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func appDidBecomeActive() {
        isActive = true
    }
    
    @objc private func appDidEnterBackground() {
        isActive = false
    }
}