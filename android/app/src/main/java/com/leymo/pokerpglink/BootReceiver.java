package com.leymo.pokerpglink;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.os.Environment;
import android.provider.Settings;

/** Optional: put the panel on the bottom screen as soon as the Thor has started. */
public class BootReceiver extends BroadcastReceiver {
    @Override
    public void onReceive(Context c, Intent i) {
        if (!Intent.ACTION_BOOT_COMPLETED.equals(i.getAction()) && !"android.intent.action.QUICKBOOT_POWERON".equals(i.getAction())) return;
        if (!Prefs.startOnBoot(c) || !Settings.canDrawOverlays(c) || !Environment.isExternalStorageManager()) return;
        try { c.startForegroundService(new Intent(c, OverlayService.class)); } catch (Exception ignored) { }
    }
}
