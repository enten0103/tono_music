// lyrics_overlay.cpp
#include "lyrics_overlay.h"

#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/standard_method_codec.h>
// Flutter view controller definition is needed for controller->view()->GetNativeWindow()
#include <flutter/flutter_view_controller.h>

#include <windows.h>
#include <shellapi.h>
#include <fstream>
#include <sstream>
#include <string>
#include <vector>
#include <cmath>
#include <variant>

// Keep overlay state in this compilation unit.
static HWND overlay_hwnd = nullptr;
// Separate topmost window used to render opaque text via UpdateLayeredWindow.
static HWND overlay_text_hwnd = nullptr;
static std::wstring overlay_text = L"";
static int overlay_x = 100;
static int overlay_y = 100;
static int overlay_w = 600;
static int overlay_h = 64;
static ATOM overlay_class_atom = 0;
// Current alpha value for layered window (0..255). Default to previous 230.
static int overlay_alpha = 230;
static std::wstring overlay_font_family = L"Segoe UI";
static int overlay_font_size = 14; // points
static HFONT overlay_hfont = nullptr;
// Bold flag for font weight
static bool overlay_font_bold = false;
// Text color for drawing (RGB). Default white.
static COLORREF overlay_text_color = RGB(255, 255, 255);

// Forward declaration of logging helper (defined later).
static void AppendOverlayLog(const std::string& s);

// Create or recreate HFONT based on current overlay_font_family and overlay_font_size.
static void update_overlay_font() {
  if (overlay_hfont) {
    DeleteObject(overlay_hfont);
    overlay_hfont = nullptr;
  }
  // CreateFont expects height in logical units (pixels). Convert points to pixels.
  HDC hdc = GetDC(NULL);
  int logpixely = GetDeviceCaps(hdc, LOGPIXELSY);
  ReleaseDC(NULL, hdc);
  int height = -MulDiv(overlay_font_size, logpixely, 72);
  int weight = overlay_font_bold ? FW_BOLD : FW_NORMAL;
  overlay_hfont = CreateFontW(
      height, 0, 0, 0, weight, FALSE, FALSE, FALSE,
      DEFAULT_CHARSET, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS,
    ANTIALIASED_QUALITY, VARIABLE_PITCH | FF_DONTCARE,
      overlay_font_family.c_str());
  std::ostringstream ss;
  ss << "update_overlay_font: family='" << std::string("(wide)") << "' size=" << overlay_font_size << " bold=" << (overlay_font_bold?1:0);
  AppendOverlayLog(ss.str());
}

// Logging helper that appends a line to %TEMP%\tono_lyrics_overlay.log
static void AppendOverlayLog(const std::string& s) {
  char* tmp_buf = nullptr;
  size_t bufsize = 0;
  std::string path;
  if (_dupenv_s(&tmp_buf, &bufsize, "TEMP") == 0 && tmp_buf != nullptr) {
    path = tmp_buf;
    free(tmp_buf);
  } else {
    path = ".";
  }
  path += "\\tono_lyrics_overlay.log";
  std::ofstream f(path, std::ios::app);
  if (f) f << s << std::endl;
}

static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam);
// Forward declare text layer updater
static void update_text_layer();

// Robust parsing helpers for EncodableValue -> int/bool/color
static bool ParseIntFromEncodable(const flutter::EncodableValue* v, int& out) {
  if (!v) return false;
  if (const int64_t* pi = std::get_if<int64_t>(v)) {
    out = (int)*pi;
    return true;
  }
  if (const double* pd = std::get_if<double>(v)) {
    out = (int)std::round(*pd);
    return true;
  }
  if (const std::string* ps = std::get_if<std::string>(v)) {
    try {
      out = std::stoi(*ps);
      return true;
    } catch (...) {
      return false;
    }
  }
  if (const std::vector<uint8_t>* pb = std::get_if<std::vector<uint8_t>>(v)) {
    try {
      std::string s(pb->begin(), pb->end());
      out = std::stoi(s);
      return true;
    } catch (...) {
      return false;
    }
  }
  return false;
}

static bool ParseBoolFromEncodable(const flutter::EncodableValue* v, bool& out) {
  if (!v) return false;
    if (const std::string* ps = std::get_if<std::string>(v)) {
    std::string s = *ps;
    for (auto &c : s) c = (char)tolower(c);
    if (s == "true" || s == "1") { out = true; return true; }
    if (s == "false" || s == "0") { out = false; return true; }
  }
  return false;
}

static bool ParseColorFromEncodable(const flutter::EncodableValue* v, int& out_rgb) {
  if (!v) return false;
  // Prefer string hex
  if (const std::string* ps = std::get_if<std::string>(v)) {
    try {
      std::string s = *ps;
      if (!s.empty() && s[0] == '#') s = s.substr(1);
      if (s.rfind("0x", 0) == 0 || s.rfind("0X", 0) == 0) s = s.substr(2);
      out_rgb = (int)std::stoul(s, nullptr, 16) & 0xFFFFFF;
      return true;
    } catch (...) {
      // fall through
    }
  }
  int tmp;
  if (ParseIntFromEncodable(v, tmp)) {
    out_rgb = tmp & 0xFFFFFF;
    return true;
  }
  if (const std::vector<uint8_t>* pb = std::get_if<std::vector<uint8_t>>(v)) {
    try {
      std::string s(pb->begin(), pb->end());
      if (!s.empty() && s[0] == '#') s = s.substr(1);
      out_rgb = (int)std::stoul(s, nullptr, 16) & 0xFFFFFF;
      return true;
    } catch (...) {}
  }
  return false;
}

static const wchar_t* kOverlayClass = L"TonoMusicLyricsOverlay";

static void ensure_overlay_class() {
  WNDCLASSEX existing = {};
  if (GetClassInfoEx(GetModuleHandle(NULL), kOverlayClass, &existing)) {
    AppendOverlayLog("ensure_overlay_class: class already registered");
    return;
  }
  WNDCLASSEX wcex = {};
  wcex.cbSize = sizeof(WNDCLASSEX);
  wcex.style = CS_HREDRAW | CS_VREDRAW;
  wcex.lpfnWndProc = OverlayWndProc;
  wcex.cbClsExtra = 0;
  wcex.cbWndExtra = sizeof(LONG_PTR);
  wcex.hInstance = GetModuleHandle(NULL);
  wcex.hCursor = LoadCursor(NULL, IDC_ARROW);
  wcex.hbrBackground = NULL;
  wcex.lpszClassName = kOverlayClass;
  ATOM atom = RegisterClassEx(&wcex);
  if (atom) {
    overlay_class_atom = atom;
    AppendOverlayLog("ensure_overlay_class: RegisterClassEx succeeded");
  } else {
    std::ostringstream ss;
    ss << "ensure_overlay_class: RegisterClassEx failed, GetLastError=" << GetLastError();
    AppendOverlayLog(ss.str());
  }
}

static bool create_overlay() {
  if (overlay_hwnd) return true;
  AppendOverlayLog("create_overlay: starting");
  ensure_overlay_class();
  {
    std::ostringstream ss;
    ss << "create_overlay: params x=" << overlay_x << " y=" << overlay_y << " w=" << overlay_w << " h=" << overlay_h;
    AppendOverlayLog(ss.str());
  }
  HMODULE hInst = GetModuleHandle(NULL);
  std::ostringstream ss_mod;
  ss_mod << "create_overlay: module=" << reinterpret_cast<void*>(hInst);
  AppendOverlayLog(ss_mod.str());

  const std::vector<DWORD> exstyles_to_try = {
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW | WS_EX_NOACTIVATE,
      WS_EX_LAYERED | WS_EX_TOPMOST | WS_EX_TOOLWINDOW,
      WS_EX_LAYERED | WS_EX_TOPMOST,
  };
  DWORD last_err = 0;
  for (size_t i = 0; i < exstyles_to_try.size(); ++i) {
    DWORD ex = exstyles_to_try[i];
    std::ostringstream ss;
    ss << "create_overlay: trying CreateWindowEx with ex=0x" << std::hex << ex;
    AppendOverlayLog(ss.str());
    SetLastError(0);
    LPCWSTR class_name_or_atom = kOverlayClass;
    if (overlay_class_atom) {
      class_name_or_atom = MAKEINTATOM(overlay_class_atom);
    }
    overlay_hwnd = CreateWindowExW(
        ex,
        class_name_or_atom, L"TonoLyrics", WS_POPUP, overlay_x, overlay_y, overlay_w, overlay_h,
        NULL, NULL, hInst, NULL);
    if (overlay_hwnd) break;
    last_err = GetLastError();
    char buf[512] = {0};
    FormatMessageA(FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                   NULL, last_err, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), buf, sizeof(buf), NULL);
    std::ostringstream serr;
    serr << "create_overlay: CreateWindowEx failed (ex=0x" << std::hex << ex << ") GetLastError=" << std::dec << last_err << " msg=" << buf;
    AppendOverlayLog(serr.str());
  }
  if (!overlay_hwnd) {
    std::ostringstream serr;
    serr << "create_overlay: all CreateWindowEx attempts failed, last_err=" << last_err;
    AppendOverlayLog(serr.str());
    return false;
  }
  AppendOverlayLog("create_overlay: window created");
  auto ptr = new std::wstring(overlay_text);
  SetWindowLongPtr(overlay_hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(ptr));
  BOOL sla = SetLayeredWindowAttributes(overlay_hwnd, 0, (BYTE)overlay_alpha, LWA_ALPHA);
  if (!sla) {
    std::ostringstream ss;
    ss << "create_overlay: SetLayeredWindowAttributes failed, GetLastError=" << GetLastError();
    AppendOverlayLog(ss.str());
  } else {
    AppendOverlayLog("create_overlay: SetLayeredWindowAttributes succeeded");
  }
  ShowWindow(overlay_hwnd, SW_SHOWNOACTIVATE);
  AppendOverlayLog("create_overlay: ShowWindow done");
  UpdateWindow(overlay_hwnd);
  AppendOverlayLog("create_overlay: UpdateWindow done");
  // Create the text window which will receive a per-pixel alpha bitmap via UpdateLayeredWindow.
  LPCWSTR class_name_for_text = overlay_class_atom ? MAKEINTATOM(overlay_class_atom) : kOverlayClass;
  for (size_t i = 0; i < exstyles_to_try.size(); ++i) {
    DWORD ex = exstyles_to_try[i];
    SetLastError(0);
    overlay_text_hwnd = CreateWindowExW(
        ex,
        class_name_for_text, L"TonoLyricsText", WS_POPUP, overlay_x, overlay_y, overlay_w, overlay_h,
        NULL, NULL, hInst, NULL);
    if (overlay_text_hwnd) break;
  }
  if (overlay_text_hwnd) {
    // Keep same userdata pointer for text window
    SetWindowLongPtr(overlay_text_hwnd, GWLP_USERDATA, reinterpret_cast<LONG_PTR>(ptr));
    ShowWindow(overlay_text_hwnd, SW_SHOWNOACTIVATE);
    AppendOverlayLog("create_overlay: text window created");
    // Push initial text content
    update_text_layer();
  } else {
    AppendOverlayLog("create_overlay: failed to create text window");
  }
  return true;
}

static void destroy_overlay() {
  if (overlay_text_hwnd) {
    DestroyWindow(overlay_text_hwnd);
    overlay_text_hwnd = nullptr;
  }
  if (overlay_hwnd) {
    DestroyWindow(overlay_hwnd);
    overlay_hwnd = nullptr;
  }
}

static void set_overlay_text(const std::wstring& t) {
  overlay_text = t;
  if (overlay_hwnd) {
    auto ptr = reinterpret_cast<std::wstring*>(GetWindowLongPtr(overlay_hwnd, GWLP_USERDATA));
    if (ptr) *ptr = overlay_text;
    // Update layered text window content (opaque text)
    if (overlay_text_hwnd) {
      update_text_layer();
    }
    InvalidateRect(overlay_hwnd, NULL, TRUE);
  }
}

// Helper: create a 32-bit ARGB DIB with the overlay_text drawn and call UpdateLayeredWindow
static void update_text_layer() {
  if (!overlay_text_hwnd) return;
  // Get client size
  RECT r;
  GetClientRect(overlay_text_hwnd, &r);
  int w = r.right - r.left;
  int h = r.bottom - r.top;
  if (w <= 0 || h <= 0) return;

  HDC screenDC = GetDC(NULL);
  HDC memDC = CreateCompatibleDC(screenDC);

  BITMAPINFO bmi = {};
  bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  bmi.bmiHeader.biWidth = w;
  // top-down DIB
  bmi.bmiHeader.biHeight = -h;
  bmi.bmiHeader.biPlanes = 1;
  bmi.bmiHeader.biBitCount = 32;
  // Use BI_RGB (default DIB ordering). We'll detect the byte ordering at runtime
  // after CreateDIBSection and adapt reads/writes accordingly. Using BI_BITFIELDS
  // caused platform-dependent interpretation issues, so prefer BI_RGB + detection.
  bmi.bmiHeader.biCompression = BI_RGB;

  void* pvBits = nullptr;
  HBITMAP hBitmap = CreateDIBSection(memDC, &bmi, DIB_RGB_COLORS, &pvBits, NULL, 0);
  if (!hBitmap) {
    DeleteDC(memDC);
    ReleaseDC(NULL, screenDC);
    return;
  }

  HGDIOBJ oldBmp = SelectObject(memDC, hBitmap);

  // Detect byte ordering for the DIB pixels by drawing a known test pixel at (0,0)
  // and inspecting pvBits. This allows us to handle differences in channel ordering
  // (e.g., whether memory layout is BGRA or RGBA).
  int byteIndexR = 2;
  int byteIndexG = 1;
  int byteIndexB = 0;
  if (pvBits) {
    // Set a red pixel at (0,0)
    SetPixel(memDC, 0, 0, RGB(255, 0, 0));
    // Read the first pixel bytes
    uint8_t* testPix = (uint8_t*)pvBits;
    uint8_t b0 = testPix[0];
    uint8_t b1 = testPix[1];
    uint8_t b2 = testPix[2];
    // Find which byte equals 255
  if (b0 == 255) { byteIndexR = 0; byteIndexG = 1; byteIndexB = 2; }
  else if (b1 == 255) { byteIndexR = 1; byteIndexG = 0; byteIndexB = 2; }
  else if (b2 == 255) { byteIndexR = 2; byteIndexG = 1; byteIndexB = 0; }
  std::ostringstream ssmap;
  ssmap << "update_text_layer: detected byte ordering R=" << byteIndexR << " G=" << byteIndexG << " B=" << byteIndexB;
  AppendOverlayLog(ssmap.str());
    // Clear test pixel by filling black background again (we'll redraw later)
    SetPixel(memDC, 0, 0, RGB(0,0,0));
    std::ostringstream ssinit;
    ssinit << "update_text_layer: initial pixel bytes before draw: [0]=" << (int)b0 << " [1]=" << (int)b1 << " [2]=" << (int)b2;
    AppendOverlayLog(ssinit.str());
    std::ostringstream ssclr;
    ssclr << "update_text_layer: desired color R=" << (int)GetRValue(overlay_text_color) << " G=" << (int)GetGValue(overlay_text_color) << " B=" << (int)GetBValue(overlay_text_color);
    AppendOverlayLog(ssclr.str());
  }

  // Fill background with black (transparent later)
  HBRUSH black = CreateSolidBrush(RGB(0,0,0));
  FillRect(memDC, &r, black);
  DeleteObject(black);

  SetBkMode(memDC, TRANSPARENT);
  SetTextColor(memDC, overlay_text_color);
  HFONT oldf = nullptr;
  if (overlay_hfont) oldf = (HFONT)SelectObject(memDC, overlay_hfont);

  // Draw text left/top
  RECT tr = {0,0,w,h};
  // Draw white text as a mask; we'll recolor below using premultiplied alpha.
  SetTextColor(memDC, RGB(255,255,255));
  DrawTextW(memDC, overlay_text.c_str(), -1, &tr, DT_LEFT | DT_SINGLELINE | DT_VCENTER | DT_END_ELLIPSIS);

  if (oldf) SelectObject(memDC, oldf);

  // Convert pixels: use the rendered grayscale mask (from white text) as alpha
  // and apply the desired overlay_text_color with premultiplied alpha.
  if (pvBits) {
    uint8_t* pix = (uint8_t*)pvBits;
    uint8_t desired_r = (uint8_t)GetRValue(overlay_text_color);
    uint8_t desired_g = (uint8_t)GetGValue(overlay_text_color);
    uint8_t desired_b = (uint8_t)GetBValue(overlay_text_color);
    int alphaIndex = 3;
    for (int y = 0; y < h; ++y) {
      for (int x = 0; x < w; ++x) {
        int idx = (y * w + x) * 4;
        uint8_t src_r = pix[idx + byteIndexR];
        uint8_t src_g = pix[idx + byteIndexG];
        uint8_t src_b = pix[idx + byteIndexB];
        // compute mask intensity (grayscale). Use max channel to better capture subpixel AA.
        uint8_t intensity = src_r;
        if (src_g > intensity) intensity = src_g;
        if (src_b > intensity) intensity = src_b;
        uint8_t a = intensity; // 0..255
        if (a == 0) {
          // fully transparent
          pix[idx + byteIndexB] = 0;
          pix[idx + byteIndexG] = 0;
          pix[idx + byteIndexR] = 0;
          pix[idx + alphaIndex] = 0;
        } else {
          // premultiply desired color by alpha
          uint8_t out_r = (uint8_t)((desired_r * (int)a + 127) / 255);
          uint8_t out_g = (uint8_t)((desired_g * (int)a + 127) / 255);
          uint8_t out_b = (uint8_t)((desired_b * (int)a + 127) / 255);
          pix[idx + byteIndexR] = out_r;
          pix[idx + byteIndexG] = out_g;
          pix[idx + byteIndexB] = out_b;
          pix[idx + alphaIndex] = a;
        }
      }
    }
    // Log a sample pixel after conversion (center)
    int cx = w/2;
    int cy = h/2;
    if (cx >= 0 && cy >= 0 && cx < w && cy < h) {
      int cidx = (cy * w + cx) * 4;
      uint8_t p0 = ((uint8_t*)pvBits)[cidx + 0];
      uint8_t p1 = ((uint8_t*)pvBits)[cidx + 1];
      uint8_t p2 = ((uint8_t*)pvBits)[cidx + 2];
      uint8_t p3 = ((uint8_t*)pvBits)[cidx + 3];
      std::ostringstream ssp;
      ssp << "update_text_layer: sample pixel after conv idx=" << cidx << " bytes=[" << (int)p0 << "," << (int)p1 << "," << (int)p2 << "," << (int)p3 << "]";
      AppendOverlayLog(ssp.str());
    }
  }

  POINT ptSrc = {0,0};
  SIZE sizeWnd = {w,h};
  POINT ptDst = {overlay_x, overlay_y};

  BLENDFUNCTION bf = {};
  bf.BlendOp = AC_SRC_OVER;
  bf.BlendFlags = 0;
  bf.SourceConstantAlpha = 255;
  bf.AlphaFormat = AC_SRC_ALPHA;

  HDC hdcScreen = GetDC(NULL);
  BOOL ok = UpdateLayeredWindow(overlay_text_hwnd, hdcScreen, &ptDst, &sizeWnd, memDC, &ptSrc, 0, &bf, ULW_ALPHA);
  ReleaseDC(NULL, hdcScreen);

  SelectObject(memDC, oldBmp);
  DeleteObject(hBitmap);
  DeleteDC(memDC);
  ReleaseDC(NULL, screenDC);

  if (!ok) {
    AppendOverlayLog("update_text_layer: UpdateLayeredWindow failed");
  }
}

static void set_overlay_pos(int x, int y) {
  overlay_x = x;
  overlay_y = y;
  if (overlay_hwnd) {
    SetWindowPos(overlay_hwnd, HWND_TOPMOST, overlay_x, overlay_y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
  }
  if (overlay_text_hwnd) {
    SetWindowPos(overlay_text_hwnd, HWND_TOPMOST, overlay_x, overlay_y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

static void set_overlay_clickthrough(bool enable) {
  if (!overlay_hwnd && !overlay_text_hwnd) return;
  if (overlay_hwnd) {
    LONG_PTR ex = GetWindowLongPtr(overlay_hwnd, GWL_EXSTYLE);
    if (enable) SetWindowLongPtr(overlay_hwnd, GWL_EXSTYLE, ex | WS_EX_TRANSPARENT);
    else SetWindowLongPtr(overlay_hwnd, GWL_EXSTYLE, ex & ~WS_EX_TRANSPARENT);
  }
  if (overlay_text_hwnd) {
    LONG_PTR ex2 = GetWindowLongPtr(overlay_text_hwnd, GWL_EXSTYLE);
    if (enable) SetWindowLongPtr(overlay_text_hwnd, GWL_EXSTYLE, ex2 | WS_EX_TRANSPARENT);
    else SetWindowLongPtr(overlay_text_hwnd, GWL_EXSTYLE, ex2 & ~WS_EX_TRANSPARENT);
  }
}

// Set the overlay alpha value (0..255). If the overlay window exists the
// layered alpha is updated immediately; otherwise the value is stored and
// applied when the window is created.
static void set_overlay_opacity_impl(int alpha) {
  if (alpha < 0) alpha = 0;
  if (alpha > 255) alpha = 255;
  overlay_alpha = alpha;
  AppendOverlayLog(std::string("set_overlay_opacity_impl: alpha=") + std::to_string(overlay_alpha));
  if (overlay_hwnd) {
    BOOL sla = SetLayeredWindowAttributes(overlay_hwnd, 0, (BYTE)overlay_alpha, LWA_ALPHA);
    if (!sla) {
      std::ostringstream ss;
      ss << "set_overlay_opacity_impl: SetLayeredWindowAttributes failed, GetLastError=" << GetLastError();
      AppendOverlayLog(ss.str());
    } else {
      AppendOverlayLog("set_overlay_opacity_impl: applied alpha");
    }
  }
}

// External API wrapper
void SetLyricsOverlayOpacity(int alpha) {
  set_overlay_opacity_impl(alpha);
}

// Window proc implementation
static LRESULT CALLBACK OverlayWndProc(HWND hwnd, UINT uMsg, WPARAM wParam, LPARAM lParam) {
  switch (uMsg) {
    case WM_PAINT: {
      // If this is the background window, paint background only.
      if (hwnd == overlay_hwnd) {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT r;
        GetClientRect(hwnd, &r);
        HBRUSH br = CreateSolidBrush(RGB(0, 0, 0));
        FillRect(hdc, &r, br);
        DeleteObject(br);
        EndPaint(hwnd, &ps);
        return 0;
      }
      // For text window we rely on UpdateLayeredWindow; nothing to do here.
      return 0;
    }
    case WM_LBUTTONDOWN: {
      LONG_PTR ex = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
      if (!(ex & WS_EX_TRANSPARENT)) {
        ReleaseCapture();
        SendMessage(hwnd, WM_SYSCOMMAND, SC_MOVE | HTCAPTION, 0);
      }
      return 0;
    }
    case WM_MOVE: {
      // Sync positions between the background and text windows so dragging moves both together.
      int new_x = (int)(short)LOWORD(lParam);
      int new_y = (int)(short)HIWORD(lParam);
      // If the background moved, move the text window to match, and vice versa.
      if (hwnd == overlay_hwnd) {
        overlay_x = new_x;
        overlay_y = new_y;
        if (overlay_text_hwnd) {
          SetWindowPos(overlay_text_hwnd, HWND_TOPMOST, overlay_x, overlay_y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
        }
      } else if (hwnd == overlay_text_hwnd) {
        overlay_x = new_x;
        overlay_y = new_y;
        if (overlay_hwnd) {
          SetWindowPos(overlay_hwnd, HWND_TOPMOST, overlay_x, overlay_y, 0, 0, SWP_NOSIZE | SWP_NOACTIVATE);
        }
      }
      return 0;
    }
    case WM_DESTROY: {
      auto ptr = reinterpret_cast<std::wstring*>(GetWindowLongPtr(hwnd, GWLP_USERDATA));
      if (ptr) delete ptr;
      return 0;
    }
  }
  return DefWindowProc(hwnd, uMsg, wParam, lParam);
}

void RegisterLyricsOverlayChannel(flutter::BinaryMessenger* messenger,
                                  flutter::FlutterViewController* controller) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
    messenger, "com.enten0103.tono_music/window",
    &flutter::StandardMethodCodec::GetInstance());

  channel->SetMethodCallHandler(
      [controller](const flutter::MethodCall<flutter::EncodableValue>& call,
                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        const std::string method = call.method_name();
        if (method == "setClickThrough") {
          bool enable = false;
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("enabled"));
            if (it != map->end()) {
              if (const bool* b = std::get_if<bool>(&it->second)) {
                enable = *b;
              }
            }
          } else if (const bool* b = std::get_if<bool>(call.arguments())) {
            enable = *b;
          }
          HWND hwnd = controller->view()->GetNativeWindow();
          if (hwnd) {
            LONG_PTR ex = GetWindowLongPtr(hwnd, GWL_EXSTYLE);
            if (enable) {
              SetLastError(0);
              SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex | WS_EX_LAYERED | WS_EX_TRANSPARENT);
            } else {
              SetLastError(0);
              SetWindowLongPtr(hwnd, GWL_EXSTYLE, ex & ~WS_EX_TRANSPARENT);
            }
            result->Success(flutter::EncodableValue(enable));
          } else {
            result->Error("no_window", "Native window handle not available");
          }
          return;
        }

        if (method == "createLyricsWindow") {
          bool ok = create_overlay();
          result->Success(flutter::EncodableValue(ok));
          return;
        }
        if (method == "destroyLyricsWindow") {
          destroy_overlay();
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "showLyricsWindow") {
          if (!create_overlay()) {
            result->Error("create_failed", "Failed to create overlay");
            return;
          }
          if (overlay_hwnd) ShowWindow(overlay_hwnd, SW_SHOWNOACTIVATE);
          if (overlay_text_hwnd) ShowWindow(overlay_text_hwnd, SW_SHOWNOACTIVATE);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "hideLyricsWindow") {
          if (overlay_hwnd) ShowWindow(overlay_hwnd, SW_HIDE);
          if (overlay_text_hwnd) ShowWindow(overlay_text_hwnd, SW_HIDE);
          result->Success(flutter::EncodableValue(true));
          return;
        }
        if (method == "setLyricsText") {
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("text"));
            if (it != map->end()) {
              if (const std::string* s = std::get_if<std::string>(&it->second)) {
                int size_needed = MultiByteToWideChar(CP_UTF8, 0, s->c_str(), (int)s->size(), NULL, 0);
                std::wstring wstrTo(size_needed, 0);
                MultiByteToWideChar(CP_UTF8, 0, s->c_str(), (int)s->size(), &wstrTo[0], size_needed);
                set_overlay_text(wstrTo);
                result->Success(flutter::EncodableValue(true));
                return;
              }
            }
          }
          result->Error("bad_args", "Expected {text: string}");
          return;
        }

        if(method == "setLyricsFontFamily") {
          if (const std::string* s = std::get_if<std::string>(call.arguments())) {
            int size_needed = MultiByteToWideChar(CP_UTF8, 0, s->c_str(), (int)s->size(), NULL, 0);
            std::wstring wstrTo(size_needed, 0);
            MultiByteToWideChar(CP_UTF8, 0, s->c_str(), (int)s->size(), &wstrTo[0], size_needed);
            overlay_font_family = wstrTo;
            update_overlay_font();
            if (overlay_hwnd) InvalidateRect(overlay_hwnd, NULL, TRUE);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("bad_args", "Expected string font family");
          return;
        }

        // Individual style setters (replaces legacy setLyricsStyle map).
        if (method == "setLyricsFontSize") {
          // Accept either a map {fontSize: value} or a direct string/int
          int parsed = -1;
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("fontSize"));
            if (it != map->end()) {
              if (const std::string* ss = std::get_if<std::string>(&it->second)) {
                try { parsed = std::stoi(*ss); } catch (...) { parsed = -1; }
              } else {
                if (ParseIntFromEncodable(&it->second, parsed) == false) parsed = -1;
              }
            }
          } else {
            if (const std::string* ss = std::get_if<std::string>(call.arguments())) {
              try { parsed = std::stoi(*ss); } catch (...) { parsed = -1; }
            } else {
              if (!ParseIntFromEncodable(call.arguments(), parsed)) parsed = -1;
            }
          }
          if (parsed >= 0) {
            overlay_font_size = parsed;
            update_overlay_font();
            if (overlay_hwnd) InvalidateRect(overlay_hwnd, NULL, TRUE);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("bad_args", "Expected fontSize (int|string)");
          return;
        }

        if (method == "setLyricsTextColor") {
          int rgb = -1;
          std::ostringstream ssdet;
          // Detect top-level argument type for debugging
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            ssdet << "setLyricsTextColor: arg is EncodableMap";
            AppendOverlayLog(ssdet.str());
            auto it = map->find(flutter::EncodableValue("textColor"));
            if (it != map->end()) {
              if (const std::string* cs = std::get_if<std::string>(&it->second)) {
                try {
                  std::string s = *cs;
                  AppendOverlayLog(s);
                  if (!s.empty() && s[0] == '#') s = s.substr(1);
                  if (s.rfind("0x", 0) == 0 || s.rfind("0X", 0) == 0) s = s.substr(2);
                  rgb = (int)std::stoul(s, nullptr, 16) & 0xFFFFFF;
                } catch (...) {
                  rgb = -1;
                }
                std::ostringstream ss; ss << "setLyricsTextColor: parsed from map string=" << (cs?*cs:"(null)") << " -> rgb=" << rgb; AppendOverlayLog(ss.str());
              } else if (const int64_t* pi = std::get_if<int64_t>(&it->second)) {
                rgb = (int)(*pi & 0xFFFFFF);
                std::ostringstream ss; ss << "setLyricsTextColor: parsed from map int=" << *pi << " -> rgb=" << rgb; AppendOverlayLog(ss.str());
              } else {
                bool ok = ParseColorFromEncodable(&it->second, rgb);
                std::ostringstream ss; ss << "setLyricsTextColor: parsed from map via ParseColorFromEncodable -> ok=" << ok << " rgb=" << rgb; AppendOverlayLog(ss.str());
              }
            } else {
              AppendOverlayLog("setLyricsTextColor: map provided but no 'textColor' key");
            }
          } else if (const std::string* cs = std::get_if<std::string>(call.arguments())) {
            std::ostringstream ss; ss << "setLyricsTextColor: arg is string='" << *cs << "'"; AppendOverlayLog(ss.str());
            try {
              std::string s = *cs;
              if (!s.empty() && s[0] == '#') s = s.substr(1);
              if (s.rfind("0x", 0) == 0 || s.rfind("0X", 0) == 0) s = s.substr(2);
              rgb = (int)std::stoul(s, nullptr, 16) & 0xFFFFFF;
            } catch (...) { rgb = -1; }
            std::ostringstream ss2; ss2 << "setLyricsTextColor: parsed from string -> rgb=" << rgb; AppendOverlayLog(ss2.str());
          } else if (const int64_t* pi = std::get_if<int64_t>(call.arguments())) {
            rgb = (int)(*pi & 0xFFFFFF);
            std::ostringstream ss; ss << "setLyricsTextColor: arg is int64=" << *pi << " -> rgb=" << rgb; AppendOverlayLog(ss.str());
          } else if (const double* pd = std::get_if<double>(call.arguments())) {
            rgb = (int)std::round(*pd) & 0xFFFFFF;
            std::ostringstream ss; ss << "setLyricsTextColor: arg is double=" << *pd << " -> rgb=" << rgb; AppendOverlayLog(ss.str());
          } else if (const std::vector<uint8_t>* pb = std::get_if<std::vector<uint8_t>>(call.arguments())) {
            try {
              std::string s(pb->begin(), pb->end());
              std::ostringstream ss; ss << "setLyricsTextColor: arg is bytevector->'" << s << "'"; AppendOverlayLog(ss.str());
              if (!s.empty() && s[0] == '#') s = s.substr(1);
              rgb = (int)std::stoul(s, nullptr, 16) & 0xFFFFFF;
              std::ostringstream ss2; ss2 << "setLyricsTextColor: parsed from bytevector -> rgb=" << rgb; AppendOverlayLog(ss2.str());
            } catch (...) { rgb = -1; }
          } else {
            AppendOverlayLog("setLyricsTextColor: arg type not recognized");
            // Fallback: try general parser
            ParseColorFromEncodable(call.arguments(), rgb);
            std::ostringstream ss; ss << "setLyricsTextColor: fallback parse rgb=" << rgb; AppendOverlayLog(ss.str());
          }

          // If parsing succeeded (rgb may be 0 for black which is valid), we accept >=0
          if (rgb >= 0) {
            std::ostringstream ss; ss << "setLyricsTextColor: final rgb=0x" << std::hex << (rgb & 0xFFFFFF) << std::dec;
            AppendOverlayLog(ss.str());
            overlay_text_color = RGB((rgb >> 16) & 0xFF, (rgb >> 8) & 0xFF, rgb & 0xFF);
            // If using separate text layer, update it; otherwise repaint.
            update_text_layer();
            if (overlay_hwnd) InvalidateRect(overlay_hwnd, NULL, TRUE);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("bad_args", "Expected textColor (int|string)");
          return;
        }

        if (method == "setLyricsBold") {
          bool bval = false;
          bool parsed = false;
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("bold"));
            if (it != map->end()) {
              if (const std::string* bs = std::get_if<std::string>(&it->second)) {
                std::string s = *bs;
                for (auto &c : s) c = (char)tolower(c);
                if (s == "true" || s == "1") { bval = true; parsed = true; }
                else if (s == "false" || s == "0") { bval = false; parsed = true; }
                else { try { bval = (std::stoi(s) != 0); parsed = true; } catch (...) { parsed = false; } }
              } else {
                if (ParseBoolFromEncodable(&it->second, bval)) parsed = true;
              }
            }
          } else {
            if (const std::string* bs = std::get_if<std::string>(call.arguments())) {
              std::string s = *bs;
              for (auto &c : s) c = (char)tolower(c);
              if (s == "true" || s == "1") { bval = true; parsed = true; }
              else if (s == "false" || s == "0") { bval = false; parsed = true; }
              else { try { bval = (std::stoi(s) != 0); parsed = true; } catch (...) { parsed = false; } }
            } else {
              if (ParseBoolFromEncodable(call.arguments(), bval)) parsed = true;
            }
          }
          if (parsed) {
            overlay_font_bold = bval;
            update_overlay_font();
            if (overlay_hwnd) InvalidateRect(overlay_hwnd, NULL, TRUE);
            result->Success(flutter::EncodableValue(true));
            return;
          }
          result->Error("bad_args", "Expected bold (bool|int|string)");
          return;
        }
        if (method == "setLyricsPosition") {
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto itx = map->find(flutter::EncodableValue("x"));
            auto ity = map->find(flutter::EncodableValue("y"));
            if (itx != map->end() && ity != map->end()) {
              if (const int64_t* xi = std::get_if<int64_t>(&itx->second)) {
                if (const int64_t* yi = std::get_if<int64_t>(&ity->second)) {
                  set_overlay_pos((int)*xi, (int)*yi);
                  result->Success(flutter::EncodableValue(true));
                  return;
                }
              }
            }
          }
          result->Error("bad_args", "Expected {x: int, y: int}");
          return;
        }
        if (method == "setOverlayClickThrough") {
          bool enable = false;
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("enabled"));
            if (it != map->end()) {
              if (const bool* b = std::get_if<bool>(&it->second)) {
                enable = *b;
              }
            }
          }
          set_overlay_clickthrough(enable);
          result->Success(flutter::EncodableValue(enable));
          return;
        }

        if (method == "setOverlayOpacity") {
          if (const auto* map = std::get_if<flutter::EncodableMap>(call.arguments())) {
            auto it = map->find(flutter::EncodableValue("alpha"));
            if (it != map->end()) {
              if (const std::string* alpha = std::get_if<std::string>(&it->second)) {
                set_overlay_opacity_impl(std::stoi(*alpha));
                result->Success(flutter::EncodableValue(*alpha));
                return;
              }
            }
          }
          result->Error("bad_args", "Expected {alpha: int}");
          return;
        }

        result->NotImplemented();
      });
  // Attach channel to messenger by releasing ownership (messenger holds it).
  (void)channel.release();
}
