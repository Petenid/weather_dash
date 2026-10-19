#include "flutter_window.h"

#include <flutter/standard_method_codec.h>

#include <optional>

#include "flutter/generated_plugin_registrant.h"

FlutterWindow::FlutterWindow(const flutter::DartProject& project)
    : project_(project) {}

FlutterWindow::~FlutterWindow() {}

bool FlutterWindow::OnCreate() {
  if (!Win32Window::OnCreate()) {
    return false;
  }

  RECT frame = GetClientArea();

  // The size here must match the window dimensions to avoid unnecessary surface
  // creation / destruction in the startup path.
  flutter_controller_ = std::make_unique<flutter::FlutterViewController>(
      frame.right - frame.left, frame.bottom - frame.top, project_);
  // Ensure that basic setup of the controller was successful.
  if (!flutter_controller_->engine() || !flutter_controller_->view()) {
    return false;
  }
  RegisterPlugins(flutter_controller_->engine());
  SetChildContent(flutter_controller_->view()->GetNativeWindow());

  // Weather Dash: listen for "setMiniMode" messages from the Dart code.
  window_channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      flutter_controller_->engine()->messenger(), "weather_dash/window",
      &flutter::StandardMethodCodec::GetInstance());
  window_channel_->SetMethodCallHandler(
      [this](const flutter::MethodCall<flutter::EncodableValue>& call,
             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        if (call.method_name() == "setMiniMode") {
          const auto* on = std::get_if<bool>(call.arguments());
          SetMiniMode(on != nullptr && *on);
          result->Success();
        } else {
          result->NotImplemented();
        }
      });

  flutter_controller_->engine()->SetNextFrameCallback([&]() {
    this->Show();
  });

  // Flutter can complete the first frame before the "show window" callback is
  // registered. The following call ensures a frame is pending to ensure the
  // window is shown. It is a no-op if the first frame hasn't completed yet.
  flutter_controller_->ForceRedraw();

  return true;
}

// Shrinks the window to a small always-on-top size, or puts it back where
// and how big it was before.
void FlutterWindow::SetMiniMode(bool on) {
  HWND hwnd = GetHandle();
  if (hwnd == nullptr) {
    return;
  }
  if (on) {
    GetWindowRect(hwnd, &saved_bounds_);
    has_saved_bounds_ = true;
    if (IsZoomed(hwnd)) {
      ShowWindow(hwnd, SW_RESTORE);
    }
    // Sizes are in physical pixels, so scale for the display's zoom level.
    const double scale = FlutterDesktopGetDpiForHWND(hwnd) / 96.0;
    const int width = static_cast<int>(360 * scale);
    const int height = static_cast<int>(320 * scale);
    SetWindowPos(hwnd, HWND_TOPMOST, saved_bounds_.left, saved_bounds_.top,
                 width, height, SWP_SHOWWINDOW);
  } else {
    if (has_saved_bounds_) {
      SetWindowPos(hwnd, HWND_NOTOPMOST, saved_bounds_.left, saved_bounds_.top,
                   saved_bounds_.right - saved_bounds_.left,
                   saved_bounds_.bottom - saved_bounds_.top, SWP_SHOWWINDOW);
    } else {
      SetWindowPos(hwnd, HWND_NOTOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_SHOWWINDOW);
    }
  }
}

void FlutterWindow::OnDestroy() {
  window_channel_ = nullptr;
  if (flutter_controller_) {
    flutter_controller_ = nullptr;
  }

  Win32Window::OnDestroy();
}

LRESULT
FlutterWindow::MessageHandler(HWND hwnd, UINT const message,
                              WPARAM const wparam,
                              LPARAM const lparam) noexcept {
  // Give Flutter, including plugins, an opportunity to handle window messages.
  if (flutter_controller_) {
    std::optional<LRESULT> result =
        flutter_controller_->HandleTopLevelWindowProc(hwnd, message, wparam,
                                                      lparam);
    if (result) {
      return *result;
    }
  }

  switch (message) {
    case WM_FONTCHANGE:
      flutter_controller_->engine()->ReloadSystemFonts();
      break;
  }

  return Win32Window::MessageHandler(hwnd, message, wparam, lparam);
}
