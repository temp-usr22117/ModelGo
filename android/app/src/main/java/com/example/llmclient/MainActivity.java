// android/app/src/main/java/com/example/llmclient/MainActivity.java

package com.example.llmclient;

import androidx.appcompat.app.AppCompatActivity;
import android.os.Bundle;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends AppCompatActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        // Load the native library
        System.loadLibrary("native-lib");
    }
}