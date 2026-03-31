package aaravgupta.ituneskit

import android.content.Context
import java.io.File

public interface iTunesCacheDirectoryProvider {
    public fun cacheDirectory(): File
}

public class AndroidContextCacheDirectoryProvider(
    private val context: Context
) : iTunesCacheDirectoryProvider {
    override fun cacheDirectory(): File = context.cacheDir
}

public object SystemCacheDirectoryProvider : iTunesCacheDirectoryProvider {
    override fun cacheDirectory(): File =
        File(System.getProperty("java.io.tmpdir") ?: ".")
}