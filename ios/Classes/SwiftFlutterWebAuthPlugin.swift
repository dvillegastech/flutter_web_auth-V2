import Flutter
import UIKit
import WebKit

public class SwiftFlutterWebAuthPlugin: NSObject, FlutterPlugin, WKNavigationDelegate {
    
    private static var webView: WKWebView?
    private static var webViewController: UIViewController?
    private static var pendingResult: FlutterResult?
    private static var callbackScheme: String?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate" {
            guard let arguments = call.arguments as? Dictionary<String, AnyObject>,
                  let urlString = arguments["url"] as? String,
                  let url = URL(string: urlString),
                  let callbackURLScheme = arguments["callbackUrlScheme"] as? String else {
                result(FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            
            SwiftFlutterWebAuthPlugin.pendingResult = result
            SwiftFlutterWebAuthPlugin.callbackScheme = callbackURLScheme
            
            DispatchQueue.main.async {
                let config = WKWebViewConfiguration()
                config.preferences.javaScriptEnabled = true
                
                let webView = WKWebView(frame: UIScreen.main.bounds, configuration: config)
                webView.navigationDelegate = self
                // Agregar User-Agent para evitar detección
                webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
                
                let webViewController = UIViewController()
                webViewController.view = webView
                webViewController.modalPresentationStyle = .pageSheet
                
                // Agregar navbar con botón cancelar
                let navController = UINavigationController(rootViewController: webViewController)
                webViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                    barButtonSystemItem: .cancel,
                    target: self,
                    action: #selector(self.closeWebView)
                )
                webViewController.title = "Connexion" // Título opcional
                
                SwiftFlutterWebAuthPlugin.webView = webView
                SwiftFlutterWebAuthPlugin.webViewController = navController
                
                webView.load(URLRequest(url: url))
                
                if let windowScene = UIApplication.shared.connectedScenes
                    .compactMap({ $0 as? UIWindowScene })
                    .first(where: { $0.activationState == .foregroundActive }),
                   let window = windowScene.windows.first(where: { $0.isKeyWindow }),
                   let rootVC = window.rootViewController {
                    
                    rootVC.present(navController, animated: true)
                }
            }
            
        } else if call.method == "cleanUpDanglingCalls" {
            // Limpiar cualquier sesión pendiente
            self.cleanup()
            result(nil)
            
        } else if call.method == "warmupUrl" {
            // Pre-cargar URL para mejorar performance
            if let arguments = call.arguments as? Dictionary<String, AnyObject>,
               let urlString = arguments["url"] as? String,
               let url = URL(string: urlString) {
                // Pre-cargar en background
                let request = URLRequest(url: url)
                URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
                result(urlString)
            } else {
                result(nil)
            }
            
        } else if call.method == "logout" {
            // Limpiar cookies para logout
            if let arguments = call.arguments as? Dictionary<String, AnyObject>,
               let urlString = arguments["url"] as? String {
                
                // Limpiar cookies del dominio
                let dataStore = WKWebsiteDataStore.default()
                dataStore.fetchDataRecords(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes()) { records in
                    dataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), 
                                       for: records) {
                        result(urlString)
                    }
                }
            } else {
                result(nil)
            }
            
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    // WKNavigationDelegate - Interceptar navegación
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        
        if let url = navigationAction.request.url,
           let scheme = url.scheme,
           let callbackScheme = SwiftFlutterWebAuthPlugin.callbackScheme,
           scheme == callbackScheme {
            
            // Encontramos el callback
            SwiftFlutterWebAuthPlugin.webViewController?.dismiss(animated: true) {
                SwiftFlutterWebAuthPlugin.pendingResult?(url.absoluteString)
                self.cleanup()
            }
            decisionHandler(.cancel)
            return
        }
        
        decisionHandler(.allow)
    }
    
    // Manejar errores de carga
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        SwiftFlutterWebAuthPlugin.pendingResult?(FlutterError(code: "LOAD_ERROR", 
                                                              message: error.localizedDescription, 
                                                              details: nil))
        self.cleanup()
    }
    
    @objc private func closeWebView() {
        SwiftFlutterWebAuthPlugin.webViewController?.dismiss(animated: true) {
            SwiftFlutterWebAuthPlugin.pendingResult?(FlutterError(code: "CANCELED", 
                                                                  message: "User canceled login", 
                                                                  details: nil))
            self.cleanup()
        }
    }
    
    private func cleanup() {
        SwiftFlutterWebAuthPlugin.webView = nil
        SwiftFlutterWebAuthPlugin.webViewController = nil
        SwiftFlutterWebAuthPlugin.pendingResult = nil
        SwiftFlutterWebAuthPlugin.callbackScheme = nil
    }
}

// Extensión para compatibilidad con el código anterior
fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", 
                          message: "Failed to aquire root view controller", 
                          details: nil)
    }
}
