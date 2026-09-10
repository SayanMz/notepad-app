package com.bca.project.notepad;

import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.database.Cursor;
import android.net.Uri;
import androidx.annotation.NonNull;
import androidx.core.content.ContextCompat;
import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.notepad.app/native_downloader";
    private DownloadManager downloadManager;

    // In-memory cache to avoid synchronous disk reads during high-frequency polling
    private Long cachedDownloadId = null;

    private long getSavedDownloadId() {
        if (cachedDownloadId != null) {
            return cachedDownloadId;
        }
        long id = getSharedPreferences("notepad_native_download", Context.MODE_PRIVATE)
                .getLong("active_download_id", -1L);
        cachedDownloadId = id;
        return id;
    }

    private void saveDownloadId(Long id) {
        cachedDownloadId = (id == null || id == -1L) ? -1L : id;
        SharedPreferences.Editor editor = getSharedPreferences("notepad_native_download", Context.MODE_PRIVATE).edit();
        if (id == null || id == -1L) {
            editor.remove("active_download_id");
        } else {
            editor.putLong("active_download_id", id);
        }
        editor.apply();
    }

    /**
     * Resolves subPath safely within app storage, preventing path traversal
     * attacks.
     */
    private File resolveSafeFile(String subPath, boolean isTmp) {
        File baseDir = getExternalFilesDir(null);
        if (baseDir == null) {
            baseDir = getFilesDir();
        }
        if (baseDir == null) {
            return null;
        }

        String filename = isTmp ? subPath + ".tmp" : subPath;
        try {
            File targetFile = new File(baseDir, filename).getCanonicalFile();
            String canonicalBase = baseDir.getCanonicalPath();
            String targetPath = targetFile.getPath();

            // Check if the path stays safely within the base directory
            boolean isInside = targetPath.equals(canonicalBase)
                    || targetPath.startsWith(canonicalBase + File.separator);

            if (!isInside) {
                return null;
            }

            return targetFile;
        } catch (IOException e) {
            return null;
        }
    }

    /**
     * Robust atomic/fallback copy-and-delete file move.
     */
    private boolean moveFile(File source, File destination) {
        if (!source.exists()) {
            return false;
        }

        File parent = destination.getParentFile();
        if (parent != null) {
            parent.mkdirs();
        }

        if (destination.exists()) {
            destination.delete();
        }

        if (source.renameTo(destination)) {
            return true;
        }

        // Fallback stream copy if rename fails across partition boundaries or file
        // locks
        try (FileInputStream input = new FileInputStream(source);
                FileOutputStream output = new FileOutputStream(destination)) {
            byte[] buffer = new byte[8192];
            int bytesRead;
            while ((bytesRead = input.read(buffer)) != -1) {
                output.write(buffer, 0, bytesRead);
            }
            return source.delete();
        } catch (Exception ignored) {
            return false;
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        downloadManager = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);

        // Safe background service start to prevent background transition crashes
        try {
            Intent serviceIntent = new Intent(this, DownloadCancelService.class);
            ContextCompat.startForegroundService(this, serviceIntent);
        } catch (Exception ignored) {
            // Service startup failure fallback
        }

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler(this::handleMethodCall);
    }

    private boolean isNullOrBlank(String str) {
        return str == null || str.trim().isEmpty();
    }

    private void handleMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "enqueueDownload": {
                String url = call.argument("url");
                String subPath = call.argument("subPath");
                String title = call.argument("title");

                if (isNullOrBlank(url) || isNullOrBlank(subPath)) {
                    result.error("INVALID_ARGS", "URL or subPath missing", null);
                    return;
                }

                // Enforce HTTPS scheme for transport security
                Uri uri = Uri.parse(url);
                if (!"https".equalsIgnoreCase(uri.getScheme())) {
                    result.error("SECURITY_ERROR", "Only secure HTTPS downloads are permitted", null);
                    return;
                }

                File destinationFile = resolveSafeFile(subPath, true);
                if (destinationFile == null) {
                    result.error("SECURITY_ERROR", "Invalid or unsafe file path", null);
                    return;
                }

                try {
                    File parent = destinationFile.getParentFile();
                    if (parent != null) {
                        parent.mkdirs();
                    }
                    if (destinationFile.exists()) {
                        destinationFile.delete();
                    }

                    // Cancel previous active download if any
                    long previousId = getSavedDownloadId();
                    if (previousId != -1L && downloadManager != null) {
                        downloadManager.remove(previousId);
                        saveDownloadId(null);
                    }

                    DownloadManager.Request request = new DownloadManager.Request(uri)
                            .setTitle(title != null ? title : "Downloading Asset")
                            .setDescription("Downloading required app data...")
                            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
                            .setAllowedOverMetered(true)
                            .setAllowedOverRoaming(true)
                            .setDestinationUri(Uri.fromFile(destinationFile));

                    long downloadId = downloadManager != null ? downloadManager.enqueue(request) : -1L;
                    if (downloadId != -1L) {
                        saveDownloadId(downloadId);
                        result.success(downloadId);
                    } else {
                        result.error("ENQUEUE_FAILED", "Failed to register download with DownloadManager", null);
                    }
                } catch (Exception e) {
                    result.error("DOWNLOAD_ERROR", e.getMessage(), null);
                }
                break;
            }

            case "getDownloadProgress": {
                Number argId = call.argument("downloadId");
                long downloadId = (argId != null) ? argId.longValue() : getSavedDownloadId();

                if (downloadId == -1L) {
                    Map<String, Object> response = new HashMap<>();
                    response.put("status", "FAILED");
                    response.put("progress", 0.0);
                    result.success(response);
                    return;
                }

                DownloadManager.Query query = new DownloadManager.Query().setFilterById(downloadId);
                Cursor cursor = null;

                try {
                    cursor = (downloadManager != null) ? downloadManager.query(query) : null;
                    if (cursor != null && cursor.moveToFirst()) {
                        long bytesDownloaded = cursor
                                .getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR));
                        long bytesTotal = cursor
                                .getLong(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_TOTAL_SIZE_BYTES));
                        int status = cursor.getInt(cursor.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));

                        double progress = 0.0;
                        if (bytesTotal > 0L) {
                            progress = (double) bytesDownloaded / (double) bytesTotal;
                            progress = Math.min(1.0, progress); // Cap ceiling at 100%
                            progress = Math.max(0.0, progress); // Floor at 0%
                        }

                        Map<String, Object> response = new HashMap<>();

                        switch (status) {
                            case DownloadManager.STATUS_SUCCESSFUL: {
                                // Prevent race conditions with onTaskRemoved by clearing ID first
                                saveDownloadId(null);

                                String subPath = call.argument("subPath");
                                boolean moveSucceeded = true;

                                if (!isNullOrBlank(subPath)) {
                                    File tmpFile = resolveSafeFile(subPath, true);
                                    File finalFile = resolveSafeFile(subPath, false);

                                    if (tmpFile != null && finalFile != null && tmpFile.exists()) {
                                        moveSucceeded = moveFile(tmpFile, finalFile);
                                    }
                                }

                                saveDownloadId(null);
                                if (moveSucceeded) {
                                    response.put("status", "SUCCESS");
                                    response.put("progress", 1.0);
                                    result.success(response);
                                } else {
                                    result.error("FILE_ERROR", "Failed to finalize downloaded file on disk", null);
                                }
                                break;
                            }
                            case DownloadManager.STATUS_FAILED: {
                                saveDownloadId(null);
                                response.put("status", "FAILED");
                                response.put("progress", 0.0);
                                result.success(response);
                                break;
                            }
                            case DownloadManager.STATUS_RUNNING: {
                                response.put("status", "RUNNING");
                                response.put("progress", progress);
                                result.success(response);
                                break;
                            }
                            case DownloadManager.STATUS_PENDING:
                            case DownloadManager.STATUS_PAUSED: {
                                response.put("status", "PENDING");
                                response.put("progress", progress);
                                result.success(response);
                                break;
                            }
                            default: {
                                response.put("status", "UNKNOWN");
                                response.put("progress", progress);
                                result.success(response);
                                break;
                            }
                        }
                    } else {
                        saveDownloadId(null);
                        Map<String, Object> response = new HashMap<>();
                        response.put("status", "NOT_FOUND");
                        response.put("progress", 0.0);
                        result.success(response);
                    }
                } catch (Exception e) {
                    result.error("QUERY_ERROR", e.getMessage(), null);
                } finally {
                    if (cursor != null) {
                        cursor.close();
                    }
                }
                break;
            }

            case "cancelDownload": {
                Number argId = call.argument("downloadId");
                long downloadId = (argId != null) ? argId.longValue() : getSavedDownloadId();

                if (downloadId != -1L && downloadManager != null) {
                    downloadManager.remove(downloadId);
                    saveDownloadId(null);
                }

                String subPath = call.argument("subPath");
                if (!isNullOrBlank(subPath)) {
                    File tmpFile = resolveSafeFile(subPath, true);
                    if (tmpFile != null && tmpFile.exists()) {
                        tmpFile.delete();
                    }
                }
                result.success(true);
                break;
            }

            default:
                result.notImplemented();
                break;
        }
    }
}