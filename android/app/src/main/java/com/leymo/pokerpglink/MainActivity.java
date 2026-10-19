package com.leymo.pokerpglink;

import android.app.Activity;
import android.app.ActivityOptions;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.hardware.display.DisplayManager;
import android.net.Uri;
import android.os.Bundle;
import android.os.Environment;
import android.provider.Settings;
import android.view.Display;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Locale;

/**
 * PokeRPGLink's home screen. It walks through setup one step at a time and does
 * everything it can on its own:
 *   1. permissions (only the ones still missing are shown)
 *   2. finding games — searched automatically, supported ones added automatically
 *   3. the mod — installed and kept up to date automatically
 *   4. one big Start button: panel on the bottom screen + the game app on top
 * The panel always goes on the bottom (external) screen.
 */
public class MainActivity extends Activity {
    private static final int INK = Color.rgb(0x1a, 0x15, 0x30);
    private static final int PANEL = Color.rgb(0x25, 0x1e, 0x40);
    private static final int TEXT = Color.rgb(0xef, 0xea, 0xfb);
    private static final int MUTED = Color.rgb(0xa4, 0x9c, 0xc4);
    private static final int AMBER = Color.rgb(0xf3, 0xb2, 0x3c);
    private static final int GOOD = Color.rgb(0x5b, 0xd0, 0x8a);
    private static final int BAD = Color.rgb(0xff, 0x8a, 0x7a);

    /** Opens this screen even when quick start is on (icon long-press → Setup, the notification, the panel's ⚙). */
    static final String ACTION_SETUP = "com.leymo.pokerpglink.SETUP";

    private LinearLayout root;
    private boolean scanning = false;
    private boolean scannedOnce = false;
    private boolean showMore = false;
    private String notice = null;

    // ------------------------------------------------------------------ lifecycle

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);
        // Set up already? Tapping the icon just starts everything: panel below, game app on top.
        if (quickStart()) return;
        // PokeRPGLink lives on the bottom screen, so the top screen stays free for the game.
        if (moveToBottomScreen()) return;
        getWindow().setStatusBarColor(INK);
        ScrollView sv = new ScrollView(this);
        sv.setBackgroundColor(INK);
        root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setPadding(dp(18), dp(14), dp(18), dp(30));
        sv.addView(root);
        setContentView(sv);
    }

    @Override
    protected void onNewIntent(Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        quickStart();
    }

    /** Opened from the app icon with setup done: start the panel + game app, skip this screen. */
    private boolean quickStart() {
        Intent i = getIntent();
        if (i == null || !Intent.ACTION_MAIN.equals(i.getAction()) || !i.hasCategory(Intent.CATEGORY_LAUNCHER)) return false;
        if (!Prefs.quickStart(this) || !permsOk() || Prefs.games(this).isEmpty()) return false;
        if (GameLauncher.preferred(this) == null) return false;
        try { autoSetup(); } catch (Exception ignored) { }    // keeps the mod current (e.g. after a game update)
        boolean ready = false;
        for (String g : Prefs.games(this)) {
            GameInfo gi = new GameInfo(new File(g));
            if (gi.supported() && gi.installedMod() != null && !gi.needsLoader()) ready = true;
        }
        if (!ready) return false;
        startForegroundService(new Intent(this, OverlayService.class));
        GameLauncher.open(this, null);
        finish();
        return true;
    }

    @Override
    protected void onResume() {
        super.onResume();
        if (root == null) return;
        // the panel floats above every app, so tuck it away while this screen is open
        if (OverlayService.running) sendToPanel(OverlayService.ACTION_COLLAPSE);
        notice = null;
        autoSetup();
        build();
    }

    @Override
    protected void onPause() {
        super.onPause();
        if (OverlayService.running) sendToPanel(OverlayService.ACTION_EXPAND);
    }

    private void sendToPanel(String action) {
        try { startService(new Intent(this, OverlayService.class).setAction(action)); } catch (Exception ignored) { }
    }

    // ------------------------------------------------------------------ screens

    /** The bottom screen = the first display that isn't the main one. */
    static Display bottomDisplay(android.content.Context c) {
        DisplayManager dm = c.getSystemService(DisplayManager.class);
        for (Display d : dm.getDisplays()) if (d.getDisplayId() != Display.DEFAULT_DISPLAY) return d;
        return null;
    }

    private boolean moveToBottomScreen() {
        if (getIntent().getBooleanExtra("stay", false)) return false;
        Display here = getDisplay();
        Display bottom = bottomDisplay(this);
        if (bottom == null || (here != null && here.getDisplayId() == bottom.getDisplayId())) return false;
        try {
            ActivityOptions opts = ActivityOptions.makeBasic();
            opts.setLaunchDisplayId(bottom.getDisplayId());
            startActivity(new Intent(this, MainActivity.class).putExtra("stay", true)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK), opts.toBundle());
            finish();
            return true;
        } catch (Exception e) {
            return false;   // the bottom screen won't take apps — stay where we are
        }
    }

    // ------------------------------------------------------------------ automatic setup

    private boolean permsOk() {
        return Settings.canDrawOverlays(this) && Environment.isExternalStorageManager();
    }

    /** Runs every time the screen opens: find games, add supported ones, install/refresh the mod. */
    private void autoSetup() {
        if (!Environment.isExternalStorageManager()) return;
        moveOldStorage();
        if (Prefs.games(this).isEmpty() && !scannedOnce) { scan(); return; }
        for (String g : Prefs.games(this)) {
            GameInfo gi = new GameInfo(new File(g));
            if (!gi.supported() || !GameInfo.looksLikeGame(gi.dir)) continue;
            File mod = gi.installedMod();
            if (mod == null || !sameAsBundled(mod) || gi.needsLoader()) {
                boolean had = mod != null;
                if (installMod(gi)) notice = (had ? "Updated" : "Installed") + " the PokeRPGLink mod in " + gi.title
                        + ". If the game is open, close it and start it again.";
            }
        }
    }

    private void scan() {
        if (scanning) return;
        scanning = true;
        new Thread(() -> {
            List<File> out = new ArrayList<>();
            List<File> roots = new ArrayList<>();
            roots.add(Environment.getExternalStorageDirectory());
            File[] vols = new File("/storage").listFiles();
            if (vols != null) for (File v : vols) if (!v.getName().equals("emulated") && !v.getName().equals("self")) roots.add(v);
            for (File r : roots) walk(r, 0, out);
            int added = 0;
            for (File f : out) {
                if (new GameInfo(f).supported()) { Prefs.addGame(this, f.getAbsolutePath()); added++; }
            }
            final int n = added;
            runOnUiThread(() -> {
                scanning = false;
                scannedOnce = true;
                if (n > 0) autoSetup();
                build();
            });
        }).start();
    }

    private void walk(File dir, int depth, List<File> out) {
        if (depth > 5 || out.size() > 20) return;
        if (dir.getName().equals("Android") && depth == 1) return;
        File[] kids = dir.listFiles();
        if (kids == null) return;
        if (GameInfo.looksLikeGame(dir) && (new File(dir, "Scripts").isDirectory() || new File(dir, "Data/Scripts").isDirectory()
                || PluginInjector.present(dir))) { out.add(dir); return; }
        for (File k : kids) if (k.isDirectory() && !k.getName().startsWith(".")) walk(k, depth + 1, out);
    }

    private byte[] bundledMod() {
        try (InputStream in = getAssets().open("PokeRPGLink.rb")) {
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            byte[] buf = new byte[8192];
            int n;
            while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
            return b.toByteArray();
        } catch (Exception e) {
            return null;
        }
    }

    private boolean sameAsBundled(File f) {
        byte[] want = bundledMod();
        if (want == null || f.length() != want.length) return false;
        try (FileInputStream in = new FileInputStream(f)) {
            byte[] have = new byte[want.length];
            int off = 0, n;
            while (off < have.length && (n = in.read(have, off, have.length - off)) > 0) off += n;
            return Arrays.equals(want, have);
        } catch (Exception e) {
            return false;
        }
    }

    // The app used to be called ThorLink. Clear that version out of a game so the mod can't
    // load twice, and keep the player's data folder (custom icons, extensions) under the new name.
    private static final String OLD = "Thor" + "Link";

    private static void removeOldName(File game) {
        for (String p : new String[] { "Data/Mods/", "patch/Mods/", "Patch/Mods/", "Data/Scripts/998_" + OLD + "/", "Plugins/" + OLD + "/" }) {
            new File(game, p + OLD + ".rb").delete();
        }
        new File(game, "Plugins/" + OLD + "/meta.txt").delete();
        new File(game, "Plugins/" + OLD).delete();                 // only removed when empty
        new File(game, "Data/Scripts/998_" + OLD).delete();
        File oldData = new File(game, OLD), newData = new File(game, "PokeRPGLink");
        if (oldData.isDirectory() && !newData.exists()) oldData.renameTo(newData);
    }

    /** Skins and type icon packs from the ThorLink days move to the new folder once. */
    private static void moveOldStorage() {
        File root = Environment.getExternalStorageDirectory();
        File oldDir = new File(root, OLD), newDir = new File(root, "PokeRPGLink");
        if (oldDir.isDirectory() && !newDir.exists()) oldDir.renameTo(newDir);
    }

    private boolean installMod(GameInfo gi) {
        byte[] mod = bundledMod();
        if (mod == null) return false;
        try {
            File dir = gi.modsDir();
            dir.mkdirs();
            // only one copy may exist, otherwise it could load twice
            for (String p : new String[] { "Data/Mods/PokeRPGLink.rb", "patch/Mods/PokeRPGLink.rb", "Patch/Mods/PokeRPGLink.rb", "Data/Scripts/998_PokeRPGLink/PokeRPGLink.rb", "Plugins/PokeRPGLink/PokeRPGLink.rb" }) {
                File old = new File(gi.dir, p);
                if (!old.getParentFile().equals(dir)) old.delete();
            }
            removeOldName(gi.dir);
            try (FileOutputStream out = new FileOutputStream(new File(dir, "PokeRPGLink.rb"))) { out.write(mod); }
            if ("plugins".equals(gi.engine)) {
                // a meta.txt keeps the folder valid if the game is ever started in debug mode
                try (FileOutputStream out = new FileOutputStream(new File(dir, "meta.txt"))) {
                    out.write("Name    = PokeRPGLink\nVersion = 1\nCredits = Leymo\n".getBytes(java.nio.charset.StandardCharsets.UTF_8));
                }
                PluginInjector.inject(gi.dir);
            }
            return true;
        } catch (Exception e) {
            notice = "Couldn't install the mod in " + gi.title + ": " + e.getMessage();
            return false;
        }
    }

    // ------------------------------------------------------------------ the screen

    private void build() {
        root.removeAllViews();
        title("PokeRPGLink", 26);
        para("by Leymo");

        boolean overlay = Settings.canDrawOverlays(this);
        boolean files = Environment.isExternalStorageManager();
        List<String> games = Prefs.games(this);
        List<String> ready = new ArrayList<>();
        for (String g : games) {
            GameInfo gi = new GameInfo(new File(g));
            if (gi.supported() && gi.installedMod() != null) ready.add(g);
        }

        if (notice != null) { LinearLayout n = card(null, true); line(n, notice, true); }

        // step 1 — permissions
        if (!overlay || !files) {
            para("Two permissions and you're set.");
            LinearLayout c = card("Step 1 of 2 · Permissions", false);
            if (!overlay) {
                line(c, "Let PokeRPGLink show its panel on the bottom screen.", false);
                button(c, "Allow showing on top", true, v -> startActivity(new Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:" + getPackageName()))));
            } else line(c, "✓ Can show on the bottom screen", true);
            if (!files) {
                line(c, "Let PokeRPGLink read your game folder.", false);
                button(c, "Allow file access", !overlay ? false : true, v -> startActivity(new Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, Uri.parse("package:" + getPackageName()))));
            } else line(c, "✓ Can read your game folder", true);
            para("Switch PokeRPGLink on in each screen, then press Back to return here.");
            more();
            return;
        }

        // step 2 — games
        if (ready.isEmpty()) {
            LinearLayout c = card("Step 2 of 2 · Find your game", false);
            if (scanning) {
                line(c, "Looking for Pokémon fangames on this device…", true);
            } else if (games.isEmpty()) {
                line(c, "No supported game found yet.", false);
                para(c, "Extract the game into your device storage (for example Internal storage › Games › Rejuvenation) — not inside the Android folder. Then search again.");
                button(c, "Search again", true, v -> { scannedOnce = false; scan(); build(); });
            } else {
                for (String g : games) {
                    GameInfo gi = new GameInfo(new File(g));
                    line(c, gi.title + (gi.supported() ? "" : " — not supported (its scripts are packed)"), gi.supported());
                }
            }
            more();
            return;
        }

        // ready — one button
        Display bottom = bottomDisplay(this);
        LinearLayout c = card(null, OverlayService.running);
        for (String g : ready) {
            GameInfo gi = new GameInfo(new File(g));
            File st = new File(g, "PokeRPGLink/state.json");
            long age = st.exists() ? System.currentTimeMillis() - st.lastModified() : -1;
            boolean live = age >= 0 && age < 5000;
            line(c, (live ? "● " : "○ ") + gi.title + (live ? " — connected" : " — ready"), live);
        }
        List<GameLauncher.Runtime> rts = GameLauncher.runtimes(this);
        String app = rts.isEmpty() ? null : rts.get(0).label;
        if (!OverlayService.running) {
            bigButton(c, app != null ? "Start  (panel + " + app + ")" : "Start panel", v -> start(true));
            if (app != null) button(c, "Start panel only", false, v -> start(false));
        } else {
            bigButton(c, app != null ? "Play  (open " + app + " on top)" : "Back to the panel", v -> { GameLauncher.open(this, null); finish(); });
            button(c, "Stop panel", false, v -> { stopService(new Intent(this, OverlayService.class)); root.postDelayed(this::build, 300); });
        }
        if (rts.size() > 1) {
            para(c, "Play with:");
            for (GameLauncher.Runtime r : rts) {
                boolean on = r == rts.get(0);
                button(c, (on ? "● " : "○ ") + r.label, false, v -> { Prefs.setRuntime(this, r.pkg); build(); });
            }
        } else if (rts.isEmpty()) {
            para(c, "Install Kirin or JoiPlay to play — PokeRPGLink opens it on the top screen for you.");
        }
        if (bottom == null) para(c, "No second screen detected right now — the panel will appear on this screen. Open the Thor's lid fully if it's closed.");
        LinearLayout q = card("Quick start", false);
        toggle(q, "Tap the PokeRPGLink icon to play",
                "Opens the panel on the bottom screen and " + (app != null ? app : "your game app") + " on the top screen in one tap — from either screen. Long-press the icon and choose Setup to come back here.",
                Prefs.quickStart(this), v -> { Prefs.setQuickStart(this, !Prefs.quickStart(this)); build(); });
        toggle(q, "Show the panel when the Thor turns on",
                "The panel waits on the bottom screen with a Play button, so you never have to open anything on the top screen.",
                Prefs.startOnBoot(this), v -> { Prefs.setStartOnBoot(this, !Prefs.startOnBoot(this)); build(); });
        para("If the game doesn't connect: close it completely and start it again, and make sure your game app (Kirin or JoiPlay) has \"All files access\" in Android settings.");
        more();
    }

    private void start(boolean withGame) {
        startForegroundService(new Intent(this, OverlayService.class));
        if (withGame) GameLauncher.open(this, null);
        // this screen and the panel share the bottom display: step aside for the panel
        root.postDelayed(this::finish, 400);
    }

    // ------------------------------------------------------------------ game app (Kirin / JoiPlay)

    // ------------------------------------------------------------------ "More" (rarely needed)

    private void more() {
        button(root, showMore ? "Hide more options" : "More options", false, v -> { showMore = !showMore; build(); });
        if (!showMore) return;

        LinearLayout g = card("Games", false);
        List<String> games = Prefs.games(this);
        if (games.isEmpty()) line(g, "None yet.", false);
        for (String p : games) {
            GameInfo gi = new GameInfo(new File(p));
            File mod = gi.installedMod();
            line(g, gi.title, mod != null);
            para(g, p + "\n" + (gi.supported() ? (mod != null ? "Mod installed in " + gi.modsPath : "Mod not installed") : "Not supported (scripts packed inside the game)"));
            if (gi.supported()) button(g, "Reinstall mod", false, v -> { if (installMod(gi)) notice = "Reinstalled the mod in " + gi.title + "."; build(); });
            button(g, "Remove " + gi.title, false, v -> { Prefs.removeGame(this, p); build(); });
        }
        button(g, scanning ? "Searching…" : "Search for games again", false, v -> { scannedOnce = false; scan(); build(); });
        EditText et = new EditText(this);
        et.setHint("Game folder path, if it wasn't found");
        et.setHintTextColor(MUTED);
        et.setTextColor(TEXT);
        et.setTextSize(14);
        et.setSingleLine(true);
        g.addView(et);
        button(g, "Add this folder", false, v -> {
            String p = et.getText().toString().trim();
            if (p.isEmpty()) return;
            if (!GameInfo.looksLikeGame(new File(p))) { notice = "That folder doesn't look like a game (no Game.exe / Data)."; build(); return; }
            Prefs.addGame(this, p);
            autoSetup();
            build();
        });

        LinearLayout s = card("Skins & type icons", false);
        File sk = BridgeJs.skinsDir(), tp = BridgeJs.typePacksDir();
        sk.mkdirs();
        tp.mkdirs();
        para(s, "Choose them from the ⚙ button on the panel. Extra skins go in:\n" + sk.getAbsolutePath()
                + "\nType icon packs (FIRE.png, WATER.png …) go in:\n" + tp.getAbsolutePath());
    }

    // ------------------------------------------------------------------ view helpers

    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }

    private void title(String s, int size) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(TEXT);
        t.setTextSize(size);
        t.setTypeface(Typeface.DEFAULT_BOLD);
        root.addView(t);
    }

    private void para(String s) { para(root, s); }

    private void para(LinearLayout parent, String s) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(MUTED);
        t.setTextSize(14);
        t.setPadding(0, dp(4), 0, dp(6));
        parent.addView(t);
    }

    private LinearLayout card(String heading, boolean done) {
        LinearLayout c = new LinearLayout(this);
        c.setOrientation(LinearLayout.VERTICAL);
        c.setPadding(dp(14), dp(12), dp(14), dp(12));
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(PANEL);
        bg.setCornerRadius(dp(14));
        if (done) bg.setStroke(dp(2), GOOD);
        c.setBackground(bg);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(12);
        root.addView(c, lp);
        if (heading != null) {
            TextView h = new TextView(this);
            h.setText(heading);
            h.setTextColor(TEXT);
            h.setTextSize(17);
            h.setTypeface(Typeface.DEFAULT_BOLD);
            c.addView(h);
        }
        return c;
    }

    private void line(LinearLayout c, String s, boolean ok) {
        TextView t = new TextView(this);
        t.setText(s);
        t.setTextColor(ok ? GOOD : BAD);
        t.setTextSize(15);
        t.setPadding(0, dp(4), 0, dp(2));
        c.addView(t);
    }

    private void bigButton(LinearLayout c, String label, View.OnClickListener l) {
        Button b = button(c, label, true, l);
        b.setTextSize(20);
        b.setGravity(Gravity.CENTER);
        b.setMinHeight(dp(64));
        b.setTypeface(Typeface.DEFAULT_BOLD);
    }

    private void toggle(LinearLayout c, String label, String help, boolean on, View.OnClickListener l) {
        Button b = button(c, (on ? "✓  " : "○  ") + label + (on ? "  — on" : "  — off"), false, l);
        if (on) ((GradientDrawable) b.getBackground()).setStroke(dp(2), GOOD);
        para(c, help);
    }

    private Button button(LinearLayout c, String label, boolean primary, View.OnClickListener l) {
        Button b = new Button(this);
        b.setText(label);
        b.setAllCaps(false);
        b.setTextSize(15);
        b.setGravity(Gravity.START | Gravity.CENTER_VERTICAL);
        b.setMinHeight(dp(46));
        b.setTextColor(primary ? INK : TEXT);
        GradientDrawable bg = new GradientDrawable();
        bg.setColor(primary ? AMBER : Color.rgb(0x30, 0x28, 0x5a));
        bg.setCornerRadius(dp(10));
        b.setBackground(bg);
        b.setPadding(dp(14), dp(10), dp(14), dp(10));
        b.setOnClickListener(l);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(8);
        c.addView(b, lp);
        return b;
    }
}
