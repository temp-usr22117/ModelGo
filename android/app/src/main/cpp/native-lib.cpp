#include <jni.h>
#include <string>
#include <vector>
#include <mutex>
#include <cstring>
#include "llama.h"


static llama_model *g_model = nullptr;
static llama_context *g_ctx = nullptr;
static std::mutex g_mutex;

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_modelgo_MainActivity_loadModel(
        JNIEnv *env,
        jobject thiz,
        jstring modelPath) {

    const char *path = env->GetStringUTFChars(modelPath, nullptr);

    if (path == nullptr) {
        return JNI_FALSE;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    // Free an existing context/model.
    if (g_ctx != nullptr) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }

    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }

    llama_backend_init();

    llama_model_params model_params = llama_model_default_params();

    g_model = llama_model_load_from_file(path, model_params);

    env->ReleaseStringUTFChars(modelPath, path);

    if (g_model == nullptr) {
        return JNI_FALSE;
    }

    llama_context_params context_params =
        llama_context_default_params();

    // Start with a reasonable context size for a mobile device.
    context_params.n_ctx = 2048;
    context_params.n_batch = 512;

    g_ctx = llama_init_from_model(g_model, context_params);

    if (g_ctx == nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
        return JNI_FALSE;
    }

    return JNI_TRUE;
}


extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_modelgo_MainActivity_infer(
        JNIEnv *env,
        jobject thiz,
        jstring prompt) {

    const char *promptStr =
        env->GetStringUTFChars(prompt, nullptr);

    if (promptStr == nullptr) {
        return nullptr;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_model == nullptr || g_ctx == nullptr) {
        env->ReleaseStringUTFChars(prompt, promptStr);

        return env->NewStringUTF(
            "Error: no model is loaded."
        );
    }

    const llama_vocab *vocab =
        llama_model_get_vocab(g_model);

    // First determine how many tokens are needed.
    int32_t tokenCount = llama_tokenize(
        vocab,
        promptStr,
        static_cast<int32_t>(strlen(promptStr)),
        nullptr,
        0,
        true,
        false
    );

    if (tokenCount >= 0) {
        env->ReleaseStringUTFChars(prompt, promptStr);

        return env->NewStringUTF(
            "Error: failed to calculate token count."
        );
    }

    tokenCount = -tokenCount;

    std::vector<llama_token> tokens(tokenCount);

    tokenCount = llama_tokenize(
        vocab,
        promptStr,
        static_cast<int32_t>(strlen(promptStr)),
        tokens.data(),
        static_cast<int32_t>(tokens.size()),
        true,
        false
    );

    env->ReleaseStringUTFChars(prompt, promptStr);

    if (tokenCount < 0) {
        return env->NewStringUTF(
            "Error: tokenization failed."
        );
    }

    tokens.resize(tokenCount);

    // Evaluate the prompt.
    llama_batch batch =
        llama_batch_get_one(tokens.data(), tokenCount);

    int result = llama_decode(g_ctx, batch);

    if (result != 0) {
        return env->NewStringUTF(
            "Error: llama_decode failed."
        );
    }

    // Create a sampler.
    llama_sampler_chain_params sampler_params =
        llama_sampler_chain_default_params();

    llama_sampler *sampler =
        llama_sampler_chain_init(sampler_params);

    if (sampler == nullptr) {
        return env->NewStringUTF(
            "Error: sampler initialization failed."
        );
    }

    llama_sampler_chain_add(
        sampler,
        llama_sampler_init_greedy()
    );

    std::string response;

    // Generate up to 256 tokens.
    for (int i = 0; i < 256; ++i) {

        llama_token token =
            llama_sampler_sample(sampler, g_ctx, -1);

        if (llama_vocab_is_eog(vocab, token)) {
            break;
        }

        char piece[256];

        int pieceSize = llama_token_to_piece(
            vocab,
            token,
            piece,
            sizeof(piece),
            0,
            false
        );

        if (pieceSize > 0) {
            response.append(piece, pieceSize);
        }

        batch = llama_batch_get_one(&token, 1);

        if (llama_decode(g_ctx, batch) != 0) {
            break;
        }
    }

    llama_sampler_free(sampler);

    return env->NewStringUTF(response.c_str());
}


extern "C"
JNIEXPORT void JNICALL
Java_com_example_modelgo_MainActivity_unloadModel(
        JNIEnv *env,
        jobject thiz) {

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_ctx != nullptr) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }

    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }
}