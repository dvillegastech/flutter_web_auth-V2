//v3
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
        if call.method == "authenticate",
           let arguments = call.arguments as? Dictionary<String, AnyObject>,
           let urlString = arguments["url"] as? String,
           let url = URL(string: urlString),
           let callbackURLScheme = arguments["callbackUrlScheme"] as? String,
           let preferEphemeral = arguments["preferEphemeral"] as? Bool
        {

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
                    // SOLUCIÓN: Buscar correctamente el FlutterViewController
                    var flutterViewController: FlutterViewController?
                    
                    if #available(iOS 15, *) {
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                            for window in windowScene.windows {
                                if let rootVC = window.rootViewController as? FlutterViewController {
                                    flutterViewController = rootVC
                                    break
                                }
                                // Buscar en view controllers presentados
                                var currentVC = window.rootViewController
                                while currentVC != nil {
                                    if let flutterVC = currentVC as? FlutterViewController {
                                        flutterViewController = flutterVC
                                        break
                                    }
                                    currentVC = currentVC?.presentedViewController
                                }
                            }
                        }
                    } else {
                        // iOS 13-14
                        for window in UIApplication.shared.windows {
                            if let rootVC = window.rootViewController as? FlutterViewController {
                                flutterViewController = rootVC
                                break
                            }
                            // Buscar en view controllers presentados
                            var currentVC = window.rootViewController
                            while currentVC != nil {
                                if let flutterVC = currentVC as? FlutterViewController {
                                    flutterViewController = flutterVC
                                    break
                                }
                                currentVC = currentVC?.presentedViewController
                            }
                        }
                    }
                    
                    guard let contextProvider = flutterViewController else {
                        result(FlutterError.aquireRootViewControllerFailed)
                        return
                    }
                    
                    session.presentationContextProvider = contextProvider
                    session.prefersEphemeralWebBrowserSession = preferEphemeral
                }

                session.start()
                sessionToKeepAlive = session
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
}

@available(iOS 13, *)
extension FlutterViewController: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Asegurar que devolvemos una ventana válida
        guard let window = self.view.window else {
            // Si no hay ventana, buscar la primera ventana disponible
            if #available(iOS 15, *) {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let firstWindow = windowScene.windows.first {
                    return firstWindow
                }
            } else {
                if let firstWindow = UIApplication.shared.windows.first {
                    return firstWindow
                }
            }
            return UIWindow()
        }
        return window
    }
}

fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to aquire root view controller" , details: nil)
    }
}
