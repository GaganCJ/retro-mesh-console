#include <jni.h>
#include <android/native_window_jni.h>
#include <android/native_window.h>
#include <android/log.h>
#include <cstring>
#include <mutex>

#define LOG_TAG "NativeRender"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

ANativeWindow* flutterWindow = nullptr;
ANativeWindow* tvWindow = nullptr;
std::mutex renderMutex;

extern "C" JNIEXPORT void JNICALL
Java_com_retromesh_retro_1mesh_1console_NativeRender_setFlutterSurface(JNIEnv* env, jclass clazz, jobject surface) {
    std::lock_guard<std::mutex> lock(renderMutex);
    if (flutterWindow) {
        ANativeWindow_release(flutterWindow);
        flutterWindow = nullptr;
    }
    if (surface != nullptr) {
        flutterWindow = ANativeWindow_fromSurface(env, surface);
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_retromesh_retro_1mesh_1console_NativeRender_setTvSurface(JNIEnv* env, jclass clazz, jobject surface) {
    std::lock_guard<std::mutex> lock(renderMutex);
    if (tvWindow) {
        ANativeWindow_release(tvWindow);
        tvWindow = nullptr;
    }
    if (surface != nullptr) {
        tvWindow = ANativeWindow_fromSurface(env, surface);
    }
}

// C-API exposed to Dart FFI
extern "C" void render_to_window(const uint8_t* pixels, int width, int height) {
    std::lock_guard<std::mutex> lock(renderMutex);
    
    auto drawToWindow = [&](ANativeWindow* window) {
        if (!window) return;
        
        ANativeWindow_setBuffersGeometry(window, width, height, WINDOW_FORMAT_RGBA_8888);
        
        ANativeWindow_Buffer buffer;
        if (ANativeWindow_lock(window, &buffer, nullptr) == 0) {
            uint8_t* dst = static_cast<uint8_t*>(buffer.bits);
            const uint8_t* src = pixels;
            
            int srcStride = width * 4;
            int dstStride = buffer.stride * 4;
            
            for (int y = 0; y < height; ++y) {
                std::memcpy(dst + y * dstStride, src + y * srcStride, srcStride);
            }
            
            ANativeWindow_unlockAndPost(window);
        }
    };
    
    drawToWindow(flutterWindow);
    drawToWindow(tvWindow);
}
