import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  static var pendingInitialRoute: String? = nil

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Desktop visual polish: blend title bar with Flutter content
    // - Make title bar transparent and hide title text
    // - Allow content to extend into the title bar area
    // - Enable dragging by background to mimic native apps
    self.titleVisibility = .hidden
    self.titlebarAppearsTransparent = true
    self.isMovableByWindowBackground = true
    self.styleMask.insert(.fullSizeContentView)
    self.backgroundColor = NSColor.clear

    // Default fixed-size login/register style window (non-resizable)
    self.styleMask.remove(.resizable)
    let fixedSize = NSSize(width: 420, height: 620)
    self.setContentSize(fixedSize)
    self.minSize = fixedSize
    self.maxSize = fixedSize

    // Method channel for resizing/toggling resizable from Flutter side
    let channel = FlutterMethodChannel(name: "window_control", binaryMessenger: flutterViewController.engine.binaryMessenger)
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let window = self else { result(FlutterError(code: "no_window", message: "Window not available", details: nil)); return }
      switch call.method {
      case "setFixedSize":
        if let args = call.arguments as? [String: Any],
           let w = args["width"] as? CGFloat,
           let h = args["height"] as? CGFloat {
          window.styleMask.remove(.resizable)
          window.setContentSize(NSSize(width: w, height: h))
          window.minSize = NSSize(width: w, height: h)
          window.maxSize = NSSize(width: w, height: h)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "width/height missing", details: nil))
        }
      case "setResizable":
        if let args = call.arguments as? [String: Any],
           let enabled = args["enabled"] as? Bool {
          if enabled {
            window.styleMask.insert(.resizable)
            // Provide generous bounds when re-enabling resize
            window.minSize = NSSize(width: 480, height: 360)
            window.maxSize = NSSize(width: 10000, height: 10000)
          } else {
            window.styleMask.remove(.resizable)
            window.maxSize = window.frame.size
            window.minSize = window.frame.size
          }
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "enabled missing", details: nil))
        }
      case "setMinSize":
        if let args = call.arguments as? [String: Any],
           let w = args["width"] as? CGFloat,
           let h = args["height"] as? CGFloat {
          window.minSize = NSSize(width: w, height: h)
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "width/height missing", details: nil))
        }
      case "setContentSize":
        if let args = call.arguments as? [String: Any],
           let w = args["width"] as? CGFloat,
           let h = args["height"] as? CGFloat {
          window.setContentSize(NSSize(width: w, height: h))
          result(nil)
        } else {
          result(FlutterError(code: "bad_args", message: "width/height missing", details: nil))
        }

      case "openWindow":
        // Create a new non-resizable window with the same visual polish.
        guard let args = call.arguments as? [String: Any] else {
          result(FlutterError(code: "bad_args", message: "missing args", details: nil)); return
        }
        let route = (args["route"] as? String) ?? "/"
        let width = (args["width"] as? CGFloat) ?? 420
        let height = (args["height"] as? CGFloat) ?? 620
        let resizable = (args["resizable"] as? Bool) ?? false

        // New engine for the secondary window so it has its own navigation stack
        // Create a new FlutterEngine for the secondary window
        let engine = FlutterEngine(name: "secondary_\(route)", project: nil)
        let controller = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        RegisterGeneratedPlugins(registry: engine)
        engine.run(withEntrypoint: nil)
        let newWindow = NSWindow(contentRect: NSMakeRect(0, 0, width, height),
                                 styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                                 backing: .buffered,
                                 defer: false)
        newWindow.contentViewController = controller
        newWindow.titleVisibility = .hidden
        newWindow.titlebarAppearsTransparent = true
        newWindow.isMovableByWindowBackground = true
        if !resizable { newWindow.styleMask.remove(.resizable) }
        newWindow.setContentSize(NSSize(width: width, height: height))
        if !resizable {
          newWindow.minSize = NSSize(width: width, height: height)
          newWindow.maxSize = NSSize(width: width, height: height)
        }
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.makeKeyAndOrderFront(nil)
        // 通知 Flutter 导航到目标路由
        let navChannel = FlutterMethodChannel(name: "window_control", binaryMessenger: controller.engine.binaryMessenger)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
          navChannel.invokeMethod("navigate", arguments: ["route": route])
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.60) {
          navChannel.invokeMethod("navigate", arguments: ["route": route])
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
