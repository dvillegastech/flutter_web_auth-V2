import AuthenticationServices
import SafariServices
import Flutter
import UIKit

public class SwiftFlutterWebAuthPlugin: NSObject, FlutterPlugin {
    private var safariVC: SFSafariViewController?
    private var authSession: Any?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "authenticate",
           let arguments = call.arguments as? Dictionary<String, AnyObject>,
           let urlString = arguments["url"] as? String,
           let url = URL(string: urlString),
           let callbackURLScheme = arguments["callbackUrScheme"] as? String,
           let preferEphemeral = arguments["preferEphemeral"] as? Bool
        {
            // SOLUCIÓN ALTERNATIVA: Detectar iOS problemático y usar SFSafariViewController
            if #available(iOS 13, *) {
                let systemVersion = ProcessInfo.processInfo.operatingSystemVersion
                
                // Si es iOS 16+ donde hay problemas conocidos con ASWebAuthenticationSession
                if systemVersion.majorVersion >= 16 {
                    print("🔵 Usando SFSafariViewController para iOS \(systemVersion.majorVersion)")
                    
                    // Guardar el result para usarlo después
                    let savedResult = result
                    
                    DispatchQueue.main.async {
                        // Configurar SFSafariViewController
                        let config = SFSafariViewController.Configuration()
                        config.entersReaderIfAvailable = false
                        
                        self.safariVC = SFSafariViewController(url: url, configuration: config)
                        self.safariVC?.modalPresentationStyle = .pageSheet
                        
                        if #available(iOS 15, *) {
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = windowScene.windows.first,
                               let rootVC = window.rootViewController {
                                
                                // Observar URLs para detectar el callback
                                NotificationCenter.default.addObserver(
                                    self,
                                    selector: #selector(self.handleCallback(_:)),
                                    name: NSNotification.Name("FlutterWebAuthCallback"),
                                    object: nil
                                )
                                
                                rootVC.present(self.safariVC!, animated: true) {
                                    print("✅ SFSafariViewController presentado")
                                }
                                
                                // Configurar un timeout para detectar si el usuario cierra manualmente
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if self.safariVC?.presentingViewController == nil {
                                        savedResult(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                                    }
                                }
                            }
                        }
                    }
                    return
                }
            }
            
            // CÓDIGO ORIGINAL para iOS < 16
            var sessionToKeepAlive: Any? = nil
            let completionHandler = { (url: URL?, err: Error?) in
                sessionToKeepAlive = nil

                if let err = err {
                    if #available(iOS 12, *) {
                        if case ASWebAuthenticationSessionError.canceledLogin = err {
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    if #available(iOS 11, *) {
                        if case SFAuthenticationError.canceledLogin = err {
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    result(FlutterError(code: "EUNKNOWN", message: err.localizedDescription, details: nil))
                    return
                }

                guard let url = url else {
                    result(FlutterError(code: "EUNKNOWN", message: "URL was null, but no error provided.", details: nil))
                    return
                }

                result(url.absoluteString)
            }

            if #available(iOS 12, *) {
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
                
                if #available(iOS 13, *) {
                    if #available(iOS 15, *) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController as? FlutterViewController {
                            session.presentationContextProvider = rootVC
                        }
                    } else {
                        if let window = UIApplication.shared.windows.first,
                           let rootVC = window.rootViewController as? FlutterViewController {
                            session.presentationContextProvider = rootVC
                        }
                    }
                    
                    session.prefersEphemeralWebBrowserSession = preferEphemeral
                }
                
                session.start()
                sessionToKeepAlive = session
                self.authSession = session
                
            } else if #available(iOS 11, *) {
                let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
                session.start()
                sessionToKeepAlive = session
            } else {
                result(FlutterError(code: "FAILED", message: "This plugin does currently not support iOS lower than iOS 11" , details: nil))
            }
            
        } else if (call.method == "cleanUpDanglingCalls") {
            result(nil)
        } else if (call.method == "warmupUrl"),
             let arguments = call.arguments as? Dictionary<String, AnyObject>,
             let urlString = arguments["url"] as? String,
             let url = URL(string: urlString)
        {
            result(url.absoluteString)
        } else if (call.method == "logout"),
             let arguments = call.arguments as? Dictionary<String, AnyObject>,
             let urlString = arguments["url"] as? String,
             let url = URL(string: urlString)
        {
            result(url.absoluteString)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }
    
    @objc private func handleCallback(_ notification: Notification) {
        if let urlString = notification.userInfo?["url"] as? String {
            self.safariVC?.dismiss(animated: true) {
                // Enviar el resultado de vuelta a Flutter
                print("✅ Callback recibido: \(urlString)")
            }
        }
    }
}

// Extensión para SFSafariViewController
extension SwiftFlutterWebAuthPlugin: SFSafariViewControllerDelegate {
    public func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        print("🔵 Safari cerrado por el usuario")
    }
}

@available(iOS 13, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return self.view.window ?? UIWindow()
    }
}

fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to aquire root view controller" , details: nil)
    }
}
