import Flutter
import UIKit

@available(iOS 16.0, *)
public class IntelligencePlugin: NSObject, FlutterPlugin {
  public static let notifier = SelectionsPushOnlyStreamHandler()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "intelligence", binaryMessenger: registrar.messenger())
    let instance = IntelligencePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    let eventChannel = FlutterEventChannel(name: "intelligence/links", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(notifier)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "populate":
      handlePopulate(call, result: result)
    case "getCachedValue":
      handleGetCachedValue(call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  func handlePopulate(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    do {
      if let args = call.arguments as? String {
        let populateArgument = try JSONDecoder().decode(PopulateArgument.self, from: Data(args.utf8))
        let storageItems = populateArgument.items.map() { item in
          return item.forStorage()
        }
        IntelligencePlugin.storage.set(items: storageItems)
        if #available(iOS 18.0, *) {
          IntelligencePlugin.spotlightCore.index(items: storageItems)
        }
        result(true)
      }
    } catch {
      result(FlutterError(
        code: "POPULATE_ARGUMENT_PARSING",
        message: ".populate called with missing or malformed argument",
        details: nil
      ))
    }
  }

  func handleGetCachedValue(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let key = call.arguments as? String else {
      result(FlutterError(
        code: "GET_CACHED_VALUE_ARGUMENT_MISSING",
        message: "getCachedValue called with missing argument",
        details: nil
      ))
      return
    }

    if let value = UserDefaults.standard.string(forKey: IntelligencePlugin.cachedKey(key)) {
      result(value)
    } else {
      result(nil)
    }
  }

  public static func setCached(_ value: String?, forKey key: String) {
    UserDefaults.standard.set(value, forKey: cachedKey(key))
  }

  private static func cachedKey(_ key: String) -> String {
    return "intelligence_cache_\(key)"
  }

  public static let storage = IntelligenceStorage()
  @available(iOS 18.0, *)
  public static let spotlightCore = IntelligenceSearchableItems()
}

struct PopulateArgument: Decodable {
  let items: [PopulateItem]
}

struct PopulateItem: Decodable {
  let id: String;
  let representation: String;

  func forStorage() -> IntelligenceItem {
    return (id: id, representation: representation)
  }
}

public class SelectionsPushOnlyStreamHandler: NSObject, FlutterStreamHandler {
  var sink: FlutterEventSink?

  var selectionsBuffer: [String] = []

  public func push(_ selection: String) {
    selectionsBuffer.append(selection)
    if let sink {
      flushSelectionsBuffer(sink)
    }
  }

  func flushSelectionsBuffer(_ sink: FlutterEventSink) {
    for link in selectionsBuffer {
      sink(link)
    }
    selectionsBuffer = []
  }

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    flushSelectionsBuffer(events)
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    sink = nil
    return nil
  }
}
