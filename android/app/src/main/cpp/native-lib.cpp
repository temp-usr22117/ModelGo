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