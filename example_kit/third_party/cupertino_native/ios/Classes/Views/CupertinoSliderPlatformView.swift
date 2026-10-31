import Flutter
import UIKit

class CupertinoSliderPlatformView: NSObject, FlutterPlatformView {
  private let channel: FlutterMethodChannel
  private let container: UIView
  private let slider: UISlider
  private var minValue: Float
  private var maxValue: Float
  private var step: Double = 0 // 0 = no stepping

  init(frame: CGRect, viewId: Int64, args: Any?, messenger: FlutterBinaryMessenger) {
    self.channel = FlutterMethodChannel(name: "CupertinoNativeSlider_\(viewId)", binaryMessenger: messenger)
    self.container = UIView(frame: frame)
    self.slider = UISlider(frame: .zero)
    self.minValue = 0
    self.maxValue = 1

    var initialValue: Double = 0
    var enabled: Bool = true
    var isDark: Bool = false
    var tint: UIColor? = nil
    var thumbTint: UIColor? = nil
    var trackTint: UIColor? = nil
    var trackBgTint: UIColor? = nil
    var step: Double = 0

    if let dict = args as? [String: Any] {
      if let v = dict["value"] as? NSNumber { initialValue = v.doubleValue }
      if let v = dict["min"] as? NSNumber { self.minValue = v.floatValue }
      if let v = dict["max"] as? NSNumber { self.maxValue = v.floatValue }
      if let v = dict["enabled"] as? NSNumber { enabled = v.boolValue }
      if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
      if let v = dict["step"] as? NSNumber { step = v.doubleValue }
      if let style = dict["style"] as? [String: Any] {
        if let n = style["tint"] as? NSNumber { tint = Self.colorFromARGB(n.intValue) }
        if let n = style["thumbTint"] as? NSNumber { thumbTint = Self.colorFromARGB(n.intValue) }
        if let n = style["trackTint"] as? NSNumber { trackTint = Self.colorFromARGB(n.intValue) }
        if let n = style["trackBackgroundTint"] as? NSNumber { trackBgTint = Self.colorFromARGB(n.intValue) }
      }
    }

    super.init()

    self.step = step

    container.backgroundColor = .clear
    if #available(iOS 13.0, *) {
      container.overrideUserInterfaceStyle = isDark ? .dark : .light
    }

    slider.minimumValue = self.minValue
    slider.maximumValue = self.maxValue
    slider.value = Float(initialValue)
    slider.isEnabled = enabled
    if let c = trackTint ?? tint { slider.minimumTrackTintColor = c }
    if let c = trackBgTint { slider.maximumTrackTintColor = c }
    if let c = thumbTint ?? tint { slider.thumbTintColor = c }

    slider.translatesAutoresizingMaskIntoConstraints = false
    container.addSubview(slider)
    NSLayoutConstraint.activate([
      slider.leadingAnchor.constraint(equalTo: container.leadingAnchor),
      slider.trailingAnchor.constraint(equalTo: container.trailingAnchor),
      slider.topAnchor.constraint(equalTo: container.topAnchor),
      slider.bottomAnchor.constraint(equalTo: container.bottomAnchor)
    ])

    slider.addTarget(self, action: #selector(onSliderChanged(_:)), for: .valueChanged)

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "setValue":
        if let args = call.arguments as? [String: Any], let value = (args["value"] as? NSNumber)?.doubleValue {
          let animated = (args["animated"] as? NSNumber)?.boolValue ?? false
          self.slider.setValue(Float(value), animated: animated)
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing value", details: nil)) }
      case "setRange":
        if let args = call.arguments as? [String: Any],
           let min = (args["min"] as? NSNumber)?.doubleValue,
           let max = (args["max"] as? NSNumber)?.doubleValue {
          self.minValue = Float(min)
          self.maxValue = Float(max)
          self.slider.minimumValue = self.minValue
          self.slider.maximumValue = self.maxValue
          if self.slider.value < self.minValue { self.slider.value = self.minValue }
          if self.slider.value > self.maxValue { self.slider.value = self.maxValue }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing min/max", details: nil)) }
      case "setEnabled":
        if let args = call.arguments as? [String: Any], let enabled = (args["enabled"] as? NSNumber)?.boolValue {
          self.slider.isEnabled = enabled
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing enabled", details: nil)) }
      case "setStyle":
        if let args = call.arguments as? [String: Any] {
          if let n = args["trackTint"] as? NSNumber { self.slider.minimumTrackTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["trackBackgroundTint"] as? NSNumber { self.slider.maximumTrackTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["thumbTint"] as? NSNumber { self.slider.thumbTintColor = Self.colorFromARGB(n.intValue) }
          if let n = args["tint"] as? NSNumber {
            let c = Self.colorFromARGB(n.intValue)
            if self.slider.minimumTrackTintColor == nil { self.slider.minimumTrackTintColor = c }
            if self.slider.thumbTintColor == nil { self.slider.thumbTintColor = c }
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing style", details: nil)) }
      case "setBrightness":
        if let args = call.arguments as? [String: Any], let isDark = (args["isDark"] as? NSNumber)?.boolValue {
          if #available(iOS 13.0, *) {
            self.container.overrideUserInterfaceStyle = isDark ? .dark : .light
          }
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing isDark", details: nil)) }
      case "setStep":
        if let args = call.arguments as? [String: Any], let step = (args["step"] as? NSNumber)?.doubleValue {
          self.step = step
          result(nil)
        } else { result(FlutterError(code: "bad_args", message: "Missing step", details: nil)) }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func view() -> UIView { container }

  @objc private func onSliderChanged(_ sender: UISlider) {
    var value = Double(sender.value)
    if step > 0 {
      let lo = Double(minValue)
      let hi = Double(maxValue)
      let steps = round((value - lo) / step)
      value = lo + steps * step
      value = Swift.max(lo, Swift.min(value, hi))
      sender.value = Float(value)
    }
    channel.invokeMethod("valueChanged", arguments: ["value": value])
  }

  private static func colorFromARGB(_ argb: Int) -> UIColor {
    let a = CGFloat((argb >> 24) & 0xFF) / 255.0
    let r = CGFloat((argb >> 16) & 0xFF) / 255.0
    let g = CGFloat((argb >> 8) & 0xFF) / 255.0
    let b = CGFloat(argb & 0xFF) / 255.0
    return UIColor(red: r, green: g, blue: b, alpha: a)
  }
}
