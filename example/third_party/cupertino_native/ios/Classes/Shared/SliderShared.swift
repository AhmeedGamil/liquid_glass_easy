import SwiftUI

struct CupertinoSliderView: View {
  @ObservedObject var model: SliderModel

  var body: some View {
    Slider(value: $model.value, in: model.min...model.max)
      .disabled(!model.enabled)
      .onChange(of: model.value) { newValue in
        model.onChange(newValue)
      }
      .accentColor(model.tintColor)
  }
}

class SliderModel: ObservableObject {
  @Published var value: Double
  @Published var min: Double
  @Published var max: Double
  @Published var enabled: Bool
  @Published var tintColor: Color = .accentColor
  var onChange: (Double) -> Void

  init(value: Double, min: Double, max: Double, enabled: Bool, onChange: @escaping (Double) -> Void) {
    self.value = value
    self.min = min
    self.max = max
    self.enabled = enabled
    self.onChange = onChange
  }
}
