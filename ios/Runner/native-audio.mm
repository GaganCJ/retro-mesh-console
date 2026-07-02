#define MINIAUDIO_IMPLEMENTATION
#include "miniaudio.h"
#include <mutex>
#include <vector>
#include <string.h>

extern "C" {
    #include <stdint.h>
}

// Global miniaudio device and config
static ma_device g_audio_device;
static ma_device_config g_device_config;
static bool g_audio_initialized = false;

// Ring buffer for audio samples
static std::vector<int16_t> g_audio_buffer;
static std::mutex g_audio_mutex;
static size_t g_read_index = 0;
static size_t g_write_index = 0;

static void data_callback(ma_device* pDevice, void* pOutput, const void* pInput, ma_uint32 frameCount) {
    std::lock_guard<std::mutex> lock(g_audio_mutex);
    int16_t* out = static_cast<int16_t*>(pOutput);
    size_t samples_requested = frameCount * 2; // Stereo
    
    size_t samples_available = g_write_index >= g_read_index ? 
                               (g_write_index - g_read_index) : 
                               (g_audio_buffer.size() - g_read_index + g_write_index);
                               
    if (samples_available < samples_requested) {
        // Underrun, fill with zeros for now
        memset(out, 0, samples_requested * sizeof(int16_t));
        return;
    }
    
    for (size_t i = 0; i < samples_requested; ++i) {
        out[i] = g_audio_buffer[g_read_index];
        g_read_index = (g_read_index + 1) % g_audio_buffer.size();
    }
}

extern "C" {

__attribute__((visibility("default"))) __attribute__((used))
void native_audio_init(double sample_rate) {
    if (g_audio_initialized) return;

    g_device_config = ma_device_config_init(ma_device_type_playback);
    g_device_config.playback.format   = ma_format_s16;
    g_device_config.playback.channels = 2; // Stereo
    g_device_config.sampleRate        = (sample_rate > 0) ? (ma_uint32)sample_rate : 44100;
    g_device_config.dataCallback      = data_callback;
    
    // Low latency
    g_device_config.periodSizeInFrames = (ma_uint32)(g_device_config.sampleRate * 0.015);

    g_audio_buffer.resize(g_device_config.sampleRate * 2);

    if (ma_device_init(NULL, &g_device_config, &g_audio_device) != MA_SUCCESS) {
        return;
    }

    ma_device_start(&g_audio_device);
    g_audio_initialized = true;
}

__attribute__((visibility("default"))) __attribute__((used))
void native_audio_deinit() {
    if (!g_audio_initialized) return;
    ma_device_uninit(&g_audio_device);
    g_audio_initialized = false;
    g_read_index = 0;
    g_write_index = 0;
}

__attribute__((visibility("default"))) __attribute__((used))
size_t native_audio_sample_batch_cb(const int16_t* data, size_t frames) {
    if (!g_audio_initialized) return frames;
    
    std::lock_guard<std::mutex> lock(g_audio_mutex);
    size_t samples_to_write = frames * 2;
    
    for (size_t i = 0; i < samples_to_write; ++i) {
        g_audio_buffer[g_write_index] = data[i];
        g_write_index = (g_write_index + 1) % g_audio_buffer.size();
        
        // Prevent overflow, just push read index forward
        if (g_write_index == g_read_index) {
            g_read_index = (g_read_index + 1) % g_audio_buffer.size();
        }
    }
    return frames;
}

}
