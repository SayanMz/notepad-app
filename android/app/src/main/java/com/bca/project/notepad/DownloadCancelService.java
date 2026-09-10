package com.bca.project.notepad;

import android.app.DownloadManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.IBinder;

public class DownloadCancelService extends Service {

    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @Override
    public void onTaskRemoved(Intent rootIntent) {
        SharedPreferences prefs = getSharedPreferences("notepad_native_download", Context.MODE_PRIVATE);
        long activeId = prefs.getLong("active_download_id", -1L);

        if (activeId != -1L) {
            DownloadManager dm = (DownloadManager) getSystemService(Context.DOWNLOAD_SERVICE);
            if (dm != null) {
                dm.remove(activeId);
            }
            prefs.edit().remove("active_download_id").commit();
        }
        stopSelf();
    }
}