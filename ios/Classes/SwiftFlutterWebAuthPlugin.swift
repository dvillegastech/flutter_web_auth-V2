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
                    // Obtener la ventana activa correctamente para iOS 13+
                    var presentationContext: ASWebAuthenticationPresentationContextProviding?

                    if #available(iOS 15, *) {
                        // Para iOS 15+ usar el método más moderno
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let window = windowScene.windows.first,
                           let rootVC = window.rootViewController {
                            presentationContext = rootVC as? ASWebAuthenticationPresentationContextProviding
                        }
                    } else {
                        // Para iOS 13-14
                        if let window = UIApplication.shared.windows.first,
                           let rootVC = window.rootViewController {
                            presentationContext = rootVC as? ASWebAuthenticationPresentationContextProviding
                        }
                    }

                    guard let contextProvider = presentationContext else {
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
        return self.view.window ?? UIWindow()
    }
}

fileprivate extension FlutterError {
    static var aquireRootViewControllerFailed: FlutterError {
        return FlutterError(code: "AQUIRE_ROOT_VIEW_CONTROLLER_FAILED", message: "Failed to aquire root view controller" , details: nil)
    }
}