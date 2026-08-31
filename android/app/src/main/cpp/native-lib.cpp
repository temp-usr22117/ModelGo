#include <jni.h>
#include <android/log.h>
#include <algorithm>
#include <cstring>
#include <mutex>
#include <string>
#include <utility>
#include <vector>

#include "llama.h"

static llama_model * g_model = nullptr;
static llama_context * g_ctx = nullptr;
static std::mutex g_mutex;
static std::vector<std::pair<std::string, std::string>> g_messages;
static int32_t g_formatted_length = 0;

#define MODELGO_LOG(...) __android_log_print(ANDROID_LOG_INFO, "ModelGoNative", __VA_ARGS__)

static jstring to_jstring(JNIEnv * env, const std::string & value) {
    jbyteArray bytes = env->NewByteArray(static_cast<jsize>(value.size()));
    if (bytes == nullptr) {
        return nullptr;
    }

    env->SetByteArrayRegion(
        bytes,
        0,
        static_cast<jsize>(value.size()),
        reinterpret_cast<const jbyte *>(value.data()));

    jclass string_class = env->FindClass("java/lang/String");
    jmethodID constructor = env->GetMethodID(
        string_class,
        "<init>",
        "([BLjava/lang/String;)V");
    jstring charset = env->NewStringUTF("UTF-8");

    return static_cast<jstring>(env->NewObject(
        string_class,
        constructor,
        bytes,
        charset));
}

static std::vector<llama_chat_message> make_chat_messages() {
    std::vector<llama_chat_message> messages;
    messages.reserve(g_messages.size());

    for (const auto & message : g_messages) {
        messages.push_back({message.first.c_str(), message.second.c_str()});
    }

    return messages;
}

static void clear_chat() {
    g_messages.clear();
    g_formatted_length = 0;

    if (g_ctx != nullptr) {
        llama_memory_clear(llama_get_memory(g_ctx), true);
    }
}

extern "C"
JNIEXPORT jboolean JNICALL
Java_com_example_modelgo_MainActivity_loadModel(
        JNIEnv * env,
        jobject,
        jstring model_path) {
    const char * path = env->GetStringUTFChars(model_path, nullptr);
    if (path == nullptr) {
        return JNI_FALSE;
    }

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_ctx != nullptr) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }

    g_messages.clear();
    g_formatted_length = 0;
    llama_backend_init();

    const int64_t load_started = llama_time_us();
    const llama_model_params model_params = llama_model_default_params();
    g_model = llama_model_load_from_file(path, model_params);
    env->ReleaseStringUTFChars(model_path, path);

    if (g_model == nullptr) {
        return JNI_FALSE;
    }

    llama_context_params context_params = llama_context_default_params();
    context_params.n_ctx = 2048;
    context_params.n_batch = 512;

    g_ctx = llama_init_from_model(g_model, context_params);
    if (g_ctx == nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
        return JNI_FALSE;
    }

    MODELGO_LOG(
        "Loaded model in %.2f seconds",
        static_cast<double>(llama_time_us() - load_started) / 1000000.0);

    return JNI_TRUE;
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_example_modelgo_MainActivity_infer(
        JNIEnv * env,
        jobject,
        jstring prompt) {
    const char * prompt_chars = env->GetStringUTFChars(prompt, nullptr);
    if (prompt_chars == nullptr) {
        return nullptr;
    }
    std::string user_prompt(prompt_chars);
    env->ReleaseStringUTFChars(prompt, prompt_chars);

    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_model == nullptr || g_ctx == nullptr) {
        return to_jstring(env, "Error: no model is loaded.");
    }

    g_messages.emplace_back("user", std::move(user_prompt));
    std::vector<llama_chat_message> chat_messages = make_chat_messages();
    const char * chat_template = llama_model_chat_template(g_model, nullptr);

    int32_t new_formatted_length = llama_chat_apply_template(
        chat_template,
        chat_messages.data(),
        chat_messages.size(),
        true,
        nullptr,
        0);

    if (new_formatted_length <= g_formatted_length) {
        g_messages.pop_back();
        return to_jstring(env, "Error: the model chat template is not supported.");
    }

    std::vector<char> formatted(static_cast<size_t>(new_formatted_length) + 1);
    new_formatted_length = llama_chat_apply_template(
        chat_template,
        chat_messages.data(),
        chat_messages.size(),
        true,
        formatted.data(),
        static_cast<int32_t>(formatted.size()));

    if (new_formatted_length <= g_formatted_length) {
        g_messages.pop_back();
        return to_jstring(env, "Error: failed to format the conversation.");
    }

    const std::string formatted_prompt(
        formatted.data() + g_formatted_length,
        static_cast<size_t>(new_formatted_length - g_formatted_length));
    const llama_vocab * vocab = llama_model_get_vocab(g_model);
    const bool is_first =
        llama_memory_seq_pos_max(llama_get_memory(g_ctx), 0) == -1;

    int32_t token_count = llama_tokenize(
        vocab,
        formatted_prompt.data(),
        static_cast<int32_t>(formatted_prompt.size()),
        nullptr,
        0,
        is_first,
        true);

    if (token_count >= 0) {
        g_messages.pop_back();
        return to_jstring(env, "Error: failed to calculate the prompt size.");
    }

    token_count = -token_count;
    std::vector<llama_token> tokens(static_cast<size_t>(token_count));
    token_count = llama_tokenize(
        vocab,
        formatted_prompt.data(),
        static_cast<int32_t>(formatted_prompt.size()),
        tokens.data(),
        static_cast<int32_t>(tokens.size()),
        is_first,
        true);

    if (token_count < 0) {
        g_messages.pop_back();
        return to_jstring(env, "Error: prompt tokenization failed.");
    }
    tokens.resize(static_cast<size_t>(token_count));

    const int32_t used_context =
        llama_memory_seq_pos_max(llama_get_memory(g_ctx), 0) + 1;
    if (used_context + token_count >= static_cast<int32_t>(llama_n_ctx(g_ctx))) {
        g_messages.pop_back();
        return to_jstring(env, "Error: this conversation has reached the context limit. Start a new chat.");
    }

    const int64_t prompt_started = llama_time_us();
    const int32_t maximum_batch = static_cast<int32_t>(llama_n_batch(g_ctx));
    if (maximum_batch <= 0) {
        g_messages.pop_back();
        return to_jstring(env, "Error: invalid model batch size.");
    }

    for (int32_t offset = 0; offset < token_count; offset += maximum_batch) {
        const int32_t batch_size = std::min(maximum_batch, token_count - offset);
        llama_batch prompt_batch = llama_batch_get_one(
            tokens.data() + offset,
            batch_size);
        if (llama_decode(g_ctx, prompt_batch) != 0) {
            g_messages.pop_back();
            return to_jstring(env, "Error: failed to process the prompt.");
        }
    }

    const double prompt_seconds =
        static_cast<double>(llama_time_us() - prompt_started) / 1000000.0;
    MODELGO_LOG(
        "Processed %d prompt tokens in %.2f seconds (%.2f tokens/second)",
        token_count,
        prompt_seconds,
        prompt_seconds > 0.0 ? token_count / prompt_seconds : 0.0);

    llama_sampler * sampler = llama_sampler_chain_init(
        llama_sampler_chain_default_params());
    if (sampler == nullptr) {
        g_messages.pop_back();
        return to_jstring(env, "Error: failed to initialize generation.");
    }

    llama_sampler_chain_add(sampler, llama_sampler_init_min_p(0.05f, 1));
    llama_sampler_chain_add(sampler, llama_sampler_init_temp(0.8f));
    llama_sampler_chain_add(sampler, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));

    std::string response;
    int32_t generated_tokens = 0;
    const int64_t generation_started = llama_time_us();
    for (int i = 0; i < 128; ++i) {
        llama_token token = llama_sampler_sample(sampler, g_ctx, -1);
        for (int retry = 0;
             response.empty() && llama_vocab_is_eog(vocab, token) && retry < 3;
             ++retry) {
            token = llama_sampler_sample(sampler, g_ctx, -1);
        }
        if (llama_vocab_is_eog(vocab, token)) {
            break;
        }

        char piece_buffer[256];
        int32_t piece_size = llama_token_to_piece(
            vocab,
            token,
            piece_buffer,
            sizeof(piece_buffer),
            0,
            true);

        if (piece_size < 0) {
            std::vector<char> larger_buffer(static_cast<size_t>(-piece_size));
            piece_size = llama_token_to_piece(
                vocab,
                token,
                larger_buffer.data(),
                static_cast<int32_t>(larger_buffer.size()),
                0,
                true);
            if (piece_size > 0) {
                response.append(larger_buffer.data(), static_cast<size_t>(piece_size));
            }
        } else if (piece_size > 0) {
            response.append(piece_buffer, static_cast<size_t>(piece_size));
        }

        const int32_t current_position =
            llama_memory_seq_pos_max(llama_get_memory(g_ctx), 0) + 1;
        if (current_position >= static_cast<int32_t>(llama_n_ctx(g_ctx))) {
            break;
        }

        llama_token next_token = token;
        llama_batch token_batch = llama_batch_get_one(&next_token, 1);
        if (llama_decode(g_ctx, token_batch) != 0) {
            break;
        }
        ++generated_tokens;
    }

    llama_sampler_free(sampler);
    const double generation_seconds =
        static_cast<double>(llama_time_us() - generation_started) / 1000000.0;
    MODELGO_LOG(
        "Generated %d tokens in %.2f seconds (%.2f tokens/second)",
        generated_tokens,
        generation_seconds,
        generation_seconds > 0.0 ? generated_tokens / generation_seconds : 0.0);
    g_messages.emplace_back("assistant", response);
    chat_messages = make_chat_messages();
    g_formatted_length = llama_chat_apply_template(
        chat_template,
        chat_messages.data(),
        chat_messages.size(),
        false,
        nullptr,
        0);

    return to_jstring(env, response);
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_modelgo_MainActivity_resetChat(
        JNIEnv *,
        jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    clear_chat();
}

extern "C"
JNIEXPORT void JNICALL
Java_com_example_modelgo_MainActivity_unloadModel(
        JNIEnv *,
        jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);

    if (g_ctx != nullptr) {
        llama_free(g_ctx);
        g_ctx = nullptr;
    }
    if (g_model != nullptr) {
        llama_model_free(g_model);
        g_model = nullptr;
    }

    g_messages.clear();
    g_formatted_length = 0;
}
