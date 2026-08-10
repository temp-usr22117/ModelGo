// android/app/src/main/cpp/native-lib.cpp

#include <jni.h>
#include "llm.h"

extern "C" JNIEXPORT void JNICALL
Java_com_example_llmclient_MainActivity_loadModel(JNIEnv *env, jobject thiz, jstring modelPath) {
    const char *path = env->GetStringUTFChars(modelPath, nullptr);
    llama_model *model = llama_init_from_file(path);
    if (model == nullptr) {
        env->ReleaseStringUTFChars(modelPath, path);
        return;
    }
    // Store the model in a global variable for later use
    extern llama_context *g_llama_ctx;
    g_llama_ctx = (llama_context *)malloc(sizeof(llama_context));
    memcpy(g_llama_ctx, &model->ctx, sizeof(llama_context));
    env->ReleaseStringUTFChars(modelPath, path);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_llmclient_MainActivity_infer(JNIEnv *env, jobject thiz, jstring prompt) {
    const char *promptStr = env->GetStringUTFChars(prompt, nullptr);
    llama_context *ctx = g_llama_ctx;
    if (ctx == nullptr) {
        env->ReleaseStringUTFChars(prompt, promptStr);
        return;
    }

    // Perform inference
    std::vector<llama_token> tokens = llama_tokenize(ctx, promptStr);
    std::string response = llama_generate_text(ctx, tokens.data(), tokens.size());

    // Send the response back to Flutter
    jclass channelClass = env->FindClass("com/example/llmclient/MainActivity");
    jmethodID sendResponseMethod = env->GetStaticMethodID(channelClass, "sendResponse", "(Ljava/lang/String;)V");
    env->CallStaticVoidMethod(channelClass, sendResponseMethod, env->NewStringUTF(response.c_str()));

    env->ReleaseStringUTFChars(prompt, promptStr);
}