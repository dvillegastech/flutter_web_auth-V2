import AuthenticationServices
import SafariServices
import Flutter
import UIKit

public class SwiftFlutterWebAuthPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_web_auth", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterWebAuthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("🔵 Flutter Web Auth: Método llamado: \(call.method)")
        
        if call.method == "authenticate",
           let arguments = call.arguments as? Dictionary<String, AnyObject>,
           let urlString = arguments["url"] as? String,
           let url = URL(string: urlString),
           let callbackURLScheme = arguments["callbackUrlScheme"] as? String,
           let preferEphemeral = arguments["preferEphemeral"] as? Bool
        {
            print("🔵 Flutter Web Auth: URL: \(urlString)")
            print("🔵 Flutter Web Auth: Callback Scheme: \(callbackURLScheme)")
            print("🔵 Flutter Web Auth: Prefer Ephemeral: \(preferEphemeral)")

            var sessionToKeepAlive: Any? = nil
            let completionHandler = { (url: URL?, err: Error?) in
                sessionToKeepAlive = nil
                
                print("🔵 Flutter Web Auth: Completion handler llamado")
                print("🔵 Flutter Web Auth: URL resultado: \(url?.absoluteString ?? "nil")")
                print("🔵 Flutter Web Auth: Error: \(err?.localizedDescription ?? "nil")")

                if let err = err {
                    if #available(iOS 12, *) {
                        if case ASWebAuthenticationSessionError.canceledLogin = err {
                            print("🔴 Flutter Web Auth: Usuario canceló el login")
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    if #available(iOS 11, *) {
                        if case SFAuthenticationError.canceledLogin = err {
                            print("🔴 Flutter Web Auth: Usuario canceló el login (SF)")
                            result(FlutterError(code: "CANCELED", message: "User canceled login", details: nil))
                            return
                        }
                    }

                    print("🔴 Flutter Web Auth: Error desconocido: \(err.localizedDescription)")
                    result(FlutterError(code: "EUNKNOWN", message: err.localizedDescription, details: nil))
                    return
                }

                guard let url = url else {
                    print("🔴 Flutter Web Auth: URL es nil sin error")
                    result(FlutterError(code: "EUNKNOWN", message: "URL was null, but no error provided.", details: nil))
                    return
                }

                print("✅ Flutter Web Auth: Autenticación exitosa: \(url.absoluteString)")
                result(url.absoluteString)
            }

            if #available(iOS 12, *) {
                print("🔵 Flutter Web Auth: Creando ASWebAuthenticationSession")
                let session = ASWebAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)

                if #available(iOS 13, *) {
                    print("🔵 Flutter Web Auth: iOS 13+ detectado, buscando FlutterViewController")
                    
                    // Debug: Imprimir información sobre las ventanas
                    if #available(iOS 15, *) {
                        print("🔵 Flutter Web Auth: iOS 15+ - Usando UIWindowScene")
                        let scenes = UIApplication.shared.connectedScenes
                        print("🔵 Flutter Web Auth: Número de scenes: \(scenes.count)")
                        
                        if let windowScene = scenes.first as? UIWindowScene {
                            print("🔵 Flutter Web Auth: WindowScene encontrado")
                            print("🔵 Flutter Web Auth: Número de ventanas: \(windowScene.windows.count)")
                            
                            for (index, window) in windowScene.windows.enumerated() {
                                print("🔵 Flutter Web Auth: Ventana \(index):")
                                print("  - Root VC: \(type(of: window.rootViewController))")
                                print("  - Is Key: \(window.isKeyWindow)")
                                print("  - Is Hidden: \(window.isHidden)")
                                
                                if let rootVC = window.rootViewController {
                                    print("  - Root VC Class: \(String(describing: rootVC))")
                                    
                                    // Verificar si es FlutterViewController
                                    if rootVC is FlutterViewController {
                                        print("✅ Flutter Web Auth: FlutterViewController encontrado!")
                                        session.presentationContextProvider = rootVC as? ASWebAuthenticationPresentationContextProviding
                                        session.prefersEphemeralWebBrowserSession = preferEphemeral
                                        
                                        print("🔵 Flutter Web Auth: Iniciando sesión...")
                                        let started = session.start()
                                        print("🔵 Flutter Web Auth: Sesión iniciada: \(started)")
                                        sessionToKeepAlive = session
                                        return
                                    }
                                    
                                    // Buscar en presented view controllers
                                    var currentVC = rootVC.presentedViewController
                                    var depth = 1
                                    while currentVC != nil {
                                        print("  - Presented VC nivel \(depth): \(type(of: currentVC))")
                                        if currentVC is FlutterViewController {
                                            print("✅ Flutter Web Auth: FlutterViewController encontrado en nivel \(depth)!")
                                            session.presentationContextProvider = currentVC as? ASWebAuthenticationPresentationContextProviding
                                            session.prefersEphemeralWebBrowserSession = preferEphemeral
                                            
                                            print("🔵 Flutter Web Auth: Iniciando sesión...")
                                            let started = session.start()
                                            print("🔵 Flutter Web Auth: Sesión iniciada: \(started)")
                                            sessionToKeepAlive = session
                                            return
                                        }
                                        currentVC = currentVC?.presentedViewController
                                        depth += 1
                                    }
                                }
                            }
                        }
                    } else {
                        // iOS 13-14
                        print("🔵 Flutter Web Auth: iOS 13-14 - Usando UIApplication.shared.windows")
                        let windows = UIApplication.shared.windows
                        print("🔵 Flutter Web Auth: Número de ventanas: \(windows.count)")
                        
                        for (index, window) in windows.enumerated() {
                            print("🔵 Flutter Web Auth: Ventana \(index):")
                            print("  - Root VC: \(type(of: window.rootViewController))")
                            print("  - Is Key: \(window.isKeyWindow)")
                            
                            if let rootVC = window.rootViewController {
                                if rootVC is FlutterViewController {
                                    print("✅ Flutter Web Auth: FlutterViewController encontrado!")
                                    session.presentationContextProvider = rootVC as? ASWebAuthenticationPresentationContextProviding
                                    session.prefersEphemeralWebBrowserSession = preferEphemeral
                                    
                                    print("🔵 Flutter Web Auth: Iniciando sesión...")
                                    let started = session.start()
                                    print("🔵 Flutter Web Auth: Sesión iniciada: \(started)")
                                    sessionToKeepAlive = session
                                    return
                                }
                            }
                        }
                    }
                    
                    print("🔴 Flutter Web Auth: No se pudo encontrar FlutterViewController")
                    result(FlutterError.aquireRootViewControllerFailed)
                    return
                }

                print("🔵 Flutter Web Auth: iOS 12 - Iniciando sesión sin presentation context")
                session.start()
                sessionToKeepAlive = session
                
            } else if #available(iOS 11, *) {
                print("🔵 Flutter Web Auth: iOS 11 - Usando SFAuthenticationSession")
                let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
                session.start()
                sessionToKeepAlive = session
            } else {
                print("🔴 Flutter Web Auth: iOS < 11 no soportado")
                result(FlutterError(code: "FAILED", message: "This plugin does currently not support iOS lower than iOS 11" , details: nil))
            }
            
        } else if (call.method == "cleanUpDanglingCalls") {
            print("🔵 Flutter Web Auth: cleanUpDanglingCalls llamado")
            result(nil)
        } else if (call.method == "warmupUrl"),
             let arguments = call.arguments as? Dictionary<String, AnyObject>,
             let urlString = arguments["url"] as? String,
             let url = URL(string: urlString)
        {
            print("🔵 Flutter Web Auth: warmupUrl llamado: \(urlString)")
            result(url.absoluteString)
        } else if (call.method == "logout"),
             let arguments = call.arguments as? Dictionary<String, AnyObject>,
             let urlString = arguments["url"] as? String,
             let url = URL(string: urlString)
        {
            print("🔵 Flutter Web Auth: logout llamado: \(urlString)")
            result(url.absoluteString)
        } else {
            print("🔴 Flutter Web Auth: Método no implementado: \(call.method)")
            result(FlutterMethodNotImplemented)
        }
    }
}

@available(iOS 13, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        print("🔵 Flutter Web Auth: presentationAnchor llamado")
        print("🔵 Flutter Web Auth: self.view.window: \(self.view.window != nil ? "exists" : "nil")")
        
        if let window = self.view.window {
            print("✅ Flutter Web Auth: Retornando window desde FlutterViewController")
            return window
        }
        
        print("⚠️ Flutter Web Auth: Window es nil, creando UIWindow vacío")
        return UIWindow()
    }
}

fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to aquire root view controller" , details: nil)
    }
}
