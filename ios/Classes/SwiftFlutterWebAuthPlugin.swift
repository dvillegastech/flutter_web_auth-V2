import AuthenticationServices
import SafariServices
import Flutter
import UIKit

public class SwiftFlutterWebAuthPlugin: NSObject, FlutterPlugin {
    private var authSession: Any? // Mantener referencia fuerte
    //v5
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
           let callbackURLScheme = arguments["callbackUrlScheme"] as? String,
           let preferEphemeral = arguments["preferEphemeral"] as? Bool
        {
            // Limpiar sesión anterior si existe
            self.authSession = nil
            
            let completionHandler = { (url: URL?, err: Error?) in
                // Limpiar la referencia después de completar
                DispatchQueue.main.async {
                    self.authSession = nil
                }
                
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
                    // SOLUCIÓN CRÍTICA: Ejecutar todo en el main queue con delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        // Obtener el window correcto
                        var window: UIWindow?
                        
                        if #available(iOS 15, *) {
                            window = UIApplication.shared.connectedScenes
                                .compactMap { $0 as? UIWindowScene }
                                .flatMap { $0.windows }
                                .first { $0.isKeyWindow }
                        } else {
                            window = UIApplication.shared.windows.first { $0.isKeyWindow }
                        }
                        
                        guard let window = window,
                              let rootVC = window.rootViewController else {
                            result(FlutterError.aquireRootViewControllerFailed)
                            return
                        }
                        
                        // Buscar el FlutterViewController en la jerarquía
                        var flutterVC: FlutterViewController?
                        
                        func findFlutterViewController(in viewController: UIViewController?) -> FlutterViewController? {
                            if let vc = viewController as? FlutterViewController {
                                return vc
                            }
                            
                            if let presented = viewController?.presentedViewController {
                                return findFlutterViewController(in: presented)
                            }
                            
                            if let nav = viewController as? UINavigationController {
                                return findFlutterViewController(in: nav.visibleViewController)
                            }
                            
                            return nil
                        }
                        
                        flutterVC = findFlutterViewController(in: rootVC) ?? rootVC as? FlutterViewController
                        
                        if let flutterVC = flutterVC {
                            session.presentationContextProvider = flutterVC
                        } else {
                            // Fallback: usar el root directamente
                            session.presentationContextProvider = rootVC as? ASWebAuthenticationPresentationContextProviding
                        }
                        
                        // IMPORTANTE: NO usar preferEphemeral true en iOS 16+
                        if #available(iOS 16, *) {
                            session.prefersEphemeralWebBrowserSession = false
                        } else {
                            session.prefersEphemeralWebBrowserSession = preferEphemeral
                        }
                        
                        // Iniciar la sesión
                        if session.start() {
                            // Mantener referencia fuerte
                            self.authSession = session
                            print("✅ Sesión iniciada correctamente")
                        } else {
                            print("❌ Error al iniciar la sesión")
                            result(FlutterError(code: "FAILED", message: "Failed to start authentication session", details: nil))
                        }
                    }
                } else {
                    // iOS 12
                    session.start()
                    self.authSession = session
                }
                
            } else if #available(iOS 11, *) {
                let session = SFAuthenticationSession(url: url, callbackURLScheme: callbackURLScheme, completionHandler: completionHandler)
                session.start()
                self.authSession = session
            } else {
                result(FlutterError(code: "FAILED", message: "This plugin does currently not support iOS lower than iOS 11" , details: nil))
            }
            
        } else if (call.method == "cleanUpDanglingCalls") {
            self.authSession = nil
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
}

@available(iOS 13, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Asegurar que la ventana esté lista
        self.view.window?.makeKeyAndVisible()
        return self.view.window ?? UIWindow()
    }
}

fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to aquire root view controller" , details: nil)
    }
}
