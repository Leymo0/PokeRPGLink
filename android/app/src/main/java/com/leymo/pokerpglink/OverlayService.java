package com.leymo.pokerpglink;

import android.annotation.SuppressLint;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.hardware.display.DisplayManager;
import android.os.Handler;
import android.os.IBinder;
import android.os.Looper;
import android.view.Display;
import android.view.Gravity;
import android.view.View;
import android.view.WindowManager;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.widget.TextView;

/**
 * Puts the PokeRPGLink touch panel on the second (bottom) screen as an overlay
 * window that can NEVER take input focus (FLAG_NOT_FOCUSABLE). Touches still
 * reach the panel, but Android keeps key/controller focus on the game on the
 * top screen — so tapping the bottom screen doesn't stop your buttons from
 * working up top.
 */
public class OverlayService extends Service {
    public static final String ACTION_STOP = "com.leymo.pokerpglink.STOP";
    public static final String ACTION_TOGGLE = "com.leymo.pokerpglink.TOGGLE";
    public static final String ACTION_COLLAPSE = "com.leymo.pokerpglink.COLLAPSE";
    public static final String ACTION_EXPAND = "com.leymo.pokerpglink.EXPAND";
    private static final String CHANNEL = "pokerpglink";
    public static volatile boolean running = false;

    private final Handler main = new Handler(Looper.getMainLooper());
    private WindowManager wm;
    private WebView web;
    private View bubble;
    private Display display;
    private boolean collapsed = false;
    private DisplayManager.DisplayListener listener;

    @Override
    public IBinder onBind(Intent intent) { return null; }

    @Override
    public void onCreate() {
        super.onCreate();
        running = true;
        startForeground(1, buildNotification());
        DisplayManager dm = getSystemService(DisplayManager.class);
        listener = new DisplayManager.DisplayListener() {
            @Override public void onDisplayAdded(int id) { main.postDelayed(OverlayService.this::moveToBottomIfPossible, 400); }
            @Override public void onDisplayRemoved(int id) { if (display != null && display.getDisplayId() == id) { detach(); main.postDelayed(OverlayService.this::attachIfNeeded, 400); } }
            @Override public void onDisplayChanged(int id) { }
        };
        dm.registerDisplayListener(listener, main);
        attachIfNeeded();
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        if (intent != null && ACTION_STOP.equals(intent.getAction())) {
            stopSelf();
            return START_NOT_STICKY;
        }
        if (intent != null && ACTION_TOGGLE.equals(intent.getAction())) setCollapsed(!collapsed);
        if (intent != null && ACTION_COLLAPSE.equals(intent.getAction())) setCollapsed(true);
        if (intent != null && ACTION_EXPAND.equals(intent.getAction())) setCollapsed(false);
        return START_STICKY;
    }

    @Override
    public void onDestroy() {
        running = false;
        try { getSystemService(DisplayManager.class).unregisterDisplayListener(listener); } catch (Exception ignored) { }
        detach();
        super.onDestroy();
    }

    // ------------------------------------------------------------------

    /** Always the bottom (external) screen; the main screen only if there is no second screen. */
    private Display pickDisplay() {
        Display bottom = MainActivity.bottomDisplay(this);
        if (bottom != null) return bottom;
        return getSystemService(DisplayManager.class).getDisplay(Display.DEFAULT_DISPLAY);
    }

    /** A second screen showed up while the panel sat on the main screen: move it down. */
    private void moveToBottomIfPossible() {
        Display bottom = MainActivity.bottomDisplay(this);
        if (bottom == null) return;
        if (display != null && display.getDisplayId() == bottom.getDisplayId() && (web != null || bubble != null)) return;
        triedMain = false;
        detach();
        attachIfNeeded();
    }

    private WindowManager.LayoutParams params(boolean full) {
        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                full ? WindowManager.LayoutParams.MATCH_PARENT : dp(58),
                full ? WindowManager.LayoutParams.MATCH_PARENT : dp(58),
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE            // never steal controller focus
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL // touches outside go to whatever is below
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
                        | WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.TOP | Gravity.END;
        lp.layoutInDisplayCutoutMode = WindowManager.LayoutParams.LAYOUT_IN_DISPLAY_CUTOUT_MODE_ALWAYS;
        if (!full) { lp.x = dp(8); lp.y = dp(8); }
        return lp;
    }

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    private void attachIfNeeded() {
        if (web != null || bubble != null) return;
        display = pickDisplay();
        if (display == null) return;
        attachTo(display);
    }

    @SuppressLint({"SetJavaScriptEnabled", "JavascriptInterface"})
    private void attachTo(Display display) {
        this.display = display;
        if (display == null) return;
        Context dctx = createDisplayContext(display)
                .createWindowContext(WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY, null);
        wm = dctx.getSystemService(WindowManager.class);

        web = new WebView(dctx);
        web.setBackgroundColor(Color.rgb(0x1a, 0x15, 0x30));
        web.setFocusable(false);
        web.setFocusableInTouchMode(false);
        web.setVerticalScrollBarEnabled(false);
        web.setHorizontalScrollBarEnabled(false);
        web.setOverScrollMode(View.OVER_SCROLL_NEVER);
        WebSettings s = web.getSettings();
        s.setJavaScriptEnabled(true);
        s.setDomStorageEnabled(true);
        s.setAllowFileAccess(true);
        s.setAllowContentAccess(true);
        s.setAllowFileAccessFromFileURLs(true);
        s.setAllowUniversalAccessFromFileURLs(true);
        s.setTextZoom(100);
        s.setMediaPlaybackRequiresUserGesture(false);   // skins may play sounds on game events, not just taps
        s.setCacheMode(WebSettings.LOAD_NO_CACHE);
        web.addJavascriptInterface(new BridgeJs(this), "PokeRPGBridge");
        web.loadUrl("file:///android_asset/ui/index.html");

        bubble = makeBubble(dctx);
        try {
            wm.addView(web, params(true));
            wm.addView(bubble, params(false));
            bubble.setVisibility(View.GONE);
            collapsed = false;
        } catch (Exception e) {
            // that screen refused the panel: clean up and fall back to the main screen once
            boolean wasBottom = display.getDisplayId() != Display.DEFAULT_DISPLAY;
            detach();
            if (wasBottom && !triedMain) { triedMain = true; display = getSystemService(DisplayManager.class).getDisplay(Display.DEFAULT_DISPLAY); attachTo(display); }
        }
    }
    private boolean triedMain = false;

    private View makeBubble(Context c) {
        TextView t = new TextView(c);
        t.setText("TL");
        t.setTextColor(Color.rgb(0x1a, 0x15, 0x30));
        t.setTextSize(15);
        t.setGravity(Gravity.CENTER);
        t.getPaint().setFakeBoldText(true);
        GradientDrawable bg = new GradientDrawable();
        bg.setShape(GradientDrawable.OVAL);
        bg.setColor(Color.rgb(0xf3, 0xb2, 0x3c));
        t.setBackground(bg);
        t.setOnClickListener(v -> setCollapsed(false));
        return t;
    }

    /** Hide the panel behind a small bubble so the bottom screen can be used for something else. */
    public void setCollapsed(boolean c) {
        main.post(() -> {
            if (web == null || bubble == null) return;
            collapsed = c;
            web.setVisibility(c ? View.GONE : View.VISIBLE);
            bubble.setVisibility(c ? View.VISIBLE : View.GONE);
            try {
                // a hidden full-screen window would still swallow touches, so shrink it
                WindowManager.LayoutParams lp = params(!c);
                if (c) { lp.width = 1; lp.height = 1; }
                wm.updateViewLayout(web, lp);
            } catch (Exception ignored) { }
        });
    }

    private void detach() {
        try { if (web != null) { wm.removeView(web); web.destroy(); } } catch (Exception ignored) { }
        try { if (bubble != null) wm.removeView(bubble); } catch (Exception ignored) { }
        web = null;
        bubble = null;
    }

    private Notification buildNotification() {
        NotificationManager nm = getSystemService(NotificationManager.class);
        nm.createNotificationChannel(new NotificationChannel(CHANNEL, "Bottom-screen panel", NotificationManager.IMPORTANCE_MIN));
        PendingIntent open = PendingIntent.getActivity(this, 0, new Intent(this, MainActivity.class).setAction(MainActivity.ACTION_SETUP), PendingIntent.FLAG_IMMUTABLE);
        PendingIntent stop = PendingIntent.getService(this, 1, new Intent(this, OverlayService.class).setAction(ACTION_STOP), PendingIntent.FLAG_IMMUTABLE);
        PendingIntent toggle = PendingIntent.getService(this, 2, new Intent(this, OverlayService.class).setAction(ACTION_TOGGLE), PendingIntent.FLAG_IMMUTABLE);
        return new Notification.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.ic_launcher)
                .setContentTitle("PokeRPGLink panel is on")
                .setContentText("Showing on the bottom screen")
                .setContentIntent(open)
                .addAction(new Notification.Action.Builder(null, "Hide / show", toggle).build())
                .addAction(new Notification.Action.Builder(null, "Stop", stop).build())
                .setOngoing(true)
                .build();
    }
}
