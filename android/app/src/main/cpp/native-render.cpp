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

#include <thread>
#include <condition_variable>
#include <vector>
#include <atomic>

// Background thread state for TV rendering
std::vector<uint16_t> tvBuffer;
std::mutex tvMutex;
std::condition_variable tvCondVar;
std::atomic<bool> tvThreadRunning{false};
std::atomic<bool> tvFrameReady{false};
int tvWidth = 256;
int tvHeight = 224;

void TvRenderWorker() {
    while (tvThreadRunning) {
        std::unique_lock<std::mutex> lock(tvMutex);
        tvCondVar.wait(lock, [] { return tvFrameReady.load() || !tvThreadRunning.load(); });
        
        if (!tvThreadRunning) break;
        
        if (tvWindow) {
            const int scale = 4;
            int scaledWidth = tvWidth * scale;
            int scaledHeight = tvHeight * scale;
            
            ANativeWindow_setBuffersGeometry(tvWindow, scaledWidth, scaledHeight, WINDOW_FORMAT_RGB_565);
            
            ANativeWindow_Buffer buffer;
            if (ANativeWindow_lock(tvWindow, &buffer, nullptr) == 0) {
                uint16_t* dst = static_cast<uint16_t*>(buffer.bits);
                const uint16_t* src = tvBuffer.data();
                
                int dstStride = buffer.stride;
                
                for (int y = 0; y < tvHeight; ++y) {
                    for (int sy = 0; sy < scale; ++sy) {
                        uint16_t* dstRow = dst + (y * scale + sy) * dstStride;
                        const uint16_t* srcRow = src + y * tvWidth;
                        for (int x = 0; x < tvWidth; ++x) {
                            uint16_t pixel = srcRow[x];
                            for (int sx = 0; sx < scale; ++sx) {
                                *dstRow++ = pixel;
                            }
                        }
                    }
                }
                
                ANativeWindow_unlockAndPost(tvWindow);
            }
        }
        tvFrameReady = false;
    }
}

// C-API exposed to Dart FFI
extern "C" void render_to_window(const uint16_t* pixels, int width, int height) {
    std::lock_guard<std::mutex> lock(renderMutex);
    
    // Start background thread if not running
    if (!tvThreadRunning) {
        tvThreadRunning = true;
        std::thread(TvRenderWorker).detach();
    }
    
    // Dispatch to TV worker thread for crisp 4x scaling (non-blocking)
    if (tvWindow) {
        std::lock_guard<std::mutex> tvLock(tvMutex);
        tvWidth = width;
        tvHeight = height;
        size_t totalPixels = width * height;
        if (tvBuffer.size() != totalPixels) {
            tvBuffer.resize(totalPixels);
        }
        memcpy(tvBuffer.data(), pixels, totalPixels * sizeof(uint16_t));
        tvFrameReady = true;
        tvCondVar.notify_one();
    }
}
