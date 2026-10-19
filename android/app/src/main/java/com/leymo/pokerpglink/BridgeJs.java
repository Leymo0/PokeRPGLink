package com.leymo.pokerpglink;

import android.content.Context;
import android.content.Intent;
import android.os.VibrationEffect;
import android.os.Vibrator;
import android.webkit.JavascriptInterface;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.List;

/**
 * The JavaScript side of the bottom-screen UI talks to the game only through
 * files inside <game folder>/PokeRPGLink/:
 *   state.json  written by PokeRPGLink.rb a few times per second
 *   dex.json / map.json  written on request
 *   cmd/*.cmd   one command per file, written here, consumed (deleted) by the game
 *
 * Several games can be registered; the bridge follows whichever one wrote
 * state.json most recently, i.e. the game that's running.
 */
public class BridgeJs {
    private final Context ctx;
    private File gameDir;
    private long lastStateTime = -1;
    private long lastStateLen = -1;
    private long lastPick = 0;
    private long counter = 0;

    public BridgeJs(Context ctx) {
        this.ctx = ctx;
        pickGame(true);
    }

    private File linkDir() { return new File(gameDir, "PokeRPGLink"); }

    /** Re-check every couple of seconds which registered game is live. */
    private void pickGame(boolean force) {
        long now = System.currentTimeMillis();
        if (!force && now - lastPick < 2000) return;
        lastPick = now;
        List<String> games = Prefs.games(ctx);
        File best = null;
        long bestTime = -1;
        for (String g : games) {
            long t = new File(g, "PokeRPGLink/state.json").lastModified();
            if (best == null || t > bestTime) { best = new File(g); bestTime = t; }
        }
        if (best == null) best = new File("/nonexistent");
        if (gameDir == null || !gameDir.equals(best)) {
            gameDir = best;
            pngIndex = null;
            lastStateTime = -1;
            lastStateLen = -1;
        }
    }

    private static String readAll(File f) {
        try (FileInputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream out = new ByteArrayOutputStream((int) Math.max(1024, f.length()));
            byte[] buf = new byte[16384];
            int n;
            while ((n = in.read(buf)) > 0) out.write(buf, 0, n);
            return out.toString(StandardCharsets.UTF_8.name());
        } catch (Exception e) {
            return "";
        }
    }

    private static boolean safeName(String name) {
        return name != null && name.matches("[A-Za-z0-9_.-]+") && !name.contains("..");
    }

    /** New state JSON, or "" when nothing changed since the last call. */
    @JavascriptInterface
    public synchronized String readState() {
        pickGame(false);
        File f = new File(linkDir(), "state.json");
        long t = f.lastModified();
        long len = f.length();
        if (t == 0 || (t == lastStateTime && len == lastStateLen)) return "";
        String s = readAll(f);
        // the game replaces the file atomically, but guard against a half-read anyway
        if (s.isEmpty() || !s.trim().endsWith("}")) return "";
        lastStateTime = t;
        lastStateLen = len;
        return s;
    }

    /** The page (re)loaded — e.g. after a skin change: hand it the current state again. */
    @JavascriptInterface
    public synchronized void resetState() {
        lastStateTime = -1;
        lastStateLen = -1;
    }

    @JavascriptInterface
    public synchronized String readFile(String name) {
        if (!safeName(name)) return "";
        return readAll(new File(linkDir(), name));
    }

    @JavascriptInterface
    public synchronized double fileTime(String name) {
        if (!safeName(name)) return 0;
        return (double) new File(linkDir(), name).lastModified();
    }

    @JavascriptInterface
    public synchronized void send(String line) {
        if (line == null) return;
        String clean = line.replaceAll("[\\r\\n]+", " ").trim();
        if (clean.isEmpty() || clean.length() > 200) return;
        try {
            File cmdDir = new File(linkDir(), "cmd");
            if (!cmdDir.isDirectory()) cmdDir.mkdirs();
            String base = String.format("%015d_%05d", System.currentTimeMillis(), (counter++) % 100000);
            File tmp = new File(cmdDir, base + ".tmp");
            try (FileOutputStream out = new FileOutputStream(tmp)) {
                out.write(clean.getBytes(StandardCharsets.UTF_8));
            }
            File done = new File(cmdDir, base + ".cmd");
            if (!tmp.renameTo(done)) {
                try (FileOutputStream out = new FileOutputStream(done)) {
                    out.write(clean.getBytes(StandardCharsets.UTF_8));
                }
                tmp.delete();
            }
        } catch (Exception ignored) {
        }
    }

    /** file:// URL of the active game's folder, ending in "/". */
    @JavascriptInterface
    public synchronized String root() {
        String p = gameDir.getAbsolutePath();
        return "file://" + p + (p.endsWith("/") ? "" : "/");
    }

    @JavascriptInterface
    public int gameCount() {
        return Prefs.games(ctx).size();
    }

    @JavascriptInterface
    public void haptic() {
        try {
            Vibrator v = ctx.getSystemService(Vibrator.class);
            if (v != null && v.hasVibrator()) v.vibrate(VibrationEffect.createOneShot(12, 120));
        } catch (Exception ignored) {
        }
    }

    // ---------------------------------------------------------------- images
    // Images are handed to the panel as data: URIs, so they show even where the
    // WebView can't read the game folder directly.
    private final java.util.LinkedHashMap<String, String> imgCache = new java.util.LinkedHashMap<String, String>(64, 0.75f, true) {
        @Override protected boolean removeEldestEntry(java.util.Map.Entry<String, String> e) { return size() > 400; }
    };
    private java.util.Map<String, String> pngIndex;
    private File pngIndexFor;

    @JavascriptInterface
    public synchronized String image(String rel) {
        if (rel == null || rel.isEmpty() || rel.contains("..")) return "";
        String key = gameDir + "|" + rel;
        String hit = imgCache.get(key);
        if (hit != null) return hit;
        File f = new File(gameDir, rel);
        if (!f.isFile()) {
            for (String ext : new String[] { ".png", ".PNG", ".gif" }) {
                File g = new File(gameDir, rel + ext);
                if (g.isFile()) { f = g; break; }
            }
        }
        String out = "";
        if (f.isFile() && f.length() < 3_000_000) {
            try (FileInputStream in = new FileInputStream(f)) {
                byte[] b = new byte[(int) f.length()];
                int off = 0, n;
                while (off < b.length && (n = in.read(b, off, b.length - off)) > 0) off += n;
                String mime = f.getName().toLowerCase(java.util.Locale.US).endsWith(".gif") ? "image/gif" : "image/png";
                out = "data:" + mime + ";base64," + android.util.Base64.encodeToString(b, 0, off, android.util.Base64.NO_WRAP);
            } catch (Exception ignored) { }
        }
        // icons the game is still drawing into PokeRPGLink/cache: don't remember a miss
        if (!out.isEmpty() || !rel.startsWith("PokeRPGLink/cache/")) imgCache.put(key, out);
        return out;
    }

    /** Last-resort icon lookup by file name anywhere under Graphics/, for games whose paths we don't know. */
    @JavascriptInterface
    public synchronized String findIcon(String species, int dex) {
        if (pngIndex == null || !gameDir.equals(pngIndexFor)) {
            pngIndex = new java.util.HashMap<>();
            pngIndexFor = gameDir;
            indexPngs(new File(gameDir, "Graphics"), "Graphics", 0);
        }
        String sp = species == null ? "" : species.toLowerCase(java.util.Locale.US);
        String d3 = dex > 0 ? String.format(java.util.Locale.US, "%03d", dex) : null;
        java.util.List<String> keys = new java.util.ArrayList<>();
        if (!sp.isEmpty()) { keys.add("icons/icon" + sp); keys.add("icons/" + sp); keys.add("icon" + sp); }
        if (d3 != null) { keys.add("icons/icon" + d3); keys.add("icon" + d3); keys.add("icons/" + d3); keys.add("icon" + dex); }
        if (!sp.isEmpty()) keys.add(sp);
        for (String k : keys) { String hit = pngIndex.get(k); if (hit != null) return hit; }
        return "";
    }

    private void indexPngs(File dir, String rel, int depth) {
        if (depth > 4) return;
        File[] kids = dir.listFiles();
        if (kids == null) return;
        String parent = dir.getName().toLowerCase(java.util.Locale.US);
        for (File k : kids) {
            String n = k.getName();
            if (k.isDirectory()) { indexPngs(k, rel + "/" + n, depth + 1); continue; }
            String lower = n.toLowerCase(java.util.Locale.US);
            if (!lower.endsWith(".png")) continue;
            String base = lower.substring(0, lower.length() - 4);
            String path = rel + "/" + n;
            pngIndex.putIfAbsent(parent + "/" + base, path);   // e.g. "icons/icon025"
            if (parent.contains("icon")) pngIndex.putIfAbsent(base, path);
        }
    }

    // ---------------------------------------------------------------- skins & settings

    /** Skins = built-in ones in assets/ui/skins plus folders in <storage>/PokeRPGLink/skins. */
    public static File skinsDir() {
        return new File(android.os.Environment.getExternalStorageDirectory(), "PokeRPGLink/skins");
    }

    @JavascriptInterface
    public String listSkins() {
        org.json.JSONArray out = new org.json.JSONArray();
        try {
            org.json.JSONObject def = new org.json.JSONObject();
            def.put("id", "default").put("name", "Default").put("author", "PokeRPGLink").put("builtin", true);
            out.put(def);
            String[] built = ctx.getAssets().list("ui/skins");
            if (built != null) for (String id : built) {
                org.json.JSONObject meta = readMeta(ctx.getAssets().open("ui/skins/" + id + "/skin.json"));
                if (meta == null) continue;
                String[] files = ctx.getAssets().list("ui/skins/" + id);
                java.util.List<String> fl = files == null ? new java.util.ArrayList<>() : java.util.Arrays.asList(files);
                meta.put("id", id).put("builtin", true);
                if (fl.contains("skin.css")) meta.put("css", "skins/" + id + "/skin.css");
                if (fl.contains("skin.js")) meta.put("js", "skins/" + id + "/skin.js");
                out.put(meta);
            }
            File[] ext = skinsDir().listFiles();
            if (ext != null) for (File d : ext) {
                File js = new File(d, "skin.json");
                if (!d.isDirectory() || !js.isFile()) continue;
                org.json.JSONObject meta = readMeta(new FileInputStream(js));
                if (meta == null) continue;
                meta.put("id", "ext:" + d.getName()).put("builtin", false);
                if (new File(d, "skin.css").isFile()) meta.put("css", "file://" + new File(d, "skin.css").getAbsolutePath() + "?t=" + new File(d, "skin.css").lastModified());
                if (new File(d, "skin.js").isFile()) meta.put("js", "file://" + new File(d, "skin.js").getAbsolutePath() + "?t=" + new File(d, "skin.js").lastModified());
                out.put(meta);
            }
        } catch (Exception ignored) {
        }
        return out.toString();
    }

    private static org.json.JSONObject readMeta(java.io.InputStream in) {
        try (java.io.InputStream i = in) {
            ByteArrayOutputStream b = new ByteArrayOutputStream();
            byte[] buf = new byte[4096];
            int n;
            while ((n = i.read(buf)) > 0) b.write(buf, 0, n);
            return new org.json.JSONObject(b.toString(StandardCharsets.UTF_8.name()));
        } catch (Exception e) {
            return null;
        }
    }

    /** Type icon packs: <storage>/PokeRPGLink/typeicons/<pack>/<TYPE>.png (e.g. FIRE.png). */
    public static File typePacksDir() {
        return new File(android.os.Environment.getExternalStorageDirectory(), "PokeRPGLink/typeicons");
    }

    private String typePacksCache;

    @JavascriptInterface
    public synchronized String listTypePacks() {
        if (typePacksCache != null) return typePacksCache;
        org.json.JSONArray out = new org.json.JSONArray();
        try {
            File[] packs = typePacksDir().listFiles(File::isDirectory);
            if (packs != null) for (File d : packs) {
                org.json.JSONObject icons = new org.json.JSONObject();
                File[] fs = d.listFiles();
                if (fs == null) continue;
                for (File f : fs) {
                    String n = f.getName();
                    String lower = n.toLowerCase(java.util.Locale.US);
                    if (!(lower.endsWith(".png") || lower.endsWith(".webp")) || f.length() > 400_000) continue;
                    try (FileInputStream in = new FileInputStream(f)) {
                        byte[] b = new byte[(int) f.length()];
                        int off = 0, r;
                        while (off < b.length && (r = in.read(b, off, b.length - off)) > 0) off += r;
                        String mime = lower.endsWith(".webp") ? "image/webp" : "image/png";
                        icons.put(n.substring(0, n.lastIndexOf('.')).toUpperCase(java.util.Locale.US),
                                "data:" + mime + ";base64," + android.util.Base64.encodeToString(b, 0, off, android.util.Base64.NO_WRAP));
                    }
                }
                if (icons.length() > 0) out.put(new org.json.JSONObject().put("id", d.getName()).put("name", d.getName()).put("icons", icons));
            }
        } catch (Exception ignored) { }
        typePacksCache = out.toString();
        return typePacksCache;
    }

    @JavascriptInterface
    public String getSetting(String key) {
        return ctx.getSharedPreferences("panel", Context.MODE_PRIVATE).getString(key, "");
    }

    @JavascriptInterface
    public void setSetting(String key, String value) {
        ctx.getSharedPreferences("panel", Context.MODE_PRIVATE).edit().putString(key, value).apply();
    }

    @JavascriptInterface
    public void setCollapsed(boolean collapsed) {
        if (ctx instanceof OverlayService) ((OverlayService) ctx).setCollapsed(collapsed);
    }

    // ---- starting the game from the panel ------------------------------------

    /** [{id, label}] — installed game apps (Kirin, JoiPlay, …), the one used last first. */
    @JavascriptInterface
    public String runtimes() {
        org.json.JSONArray out = new org.json.JSONArray();
        try {
            for (GameLauncher.Runtime r : GameLauncher.runtimes(ctx)) out.put(new org.json.JSONObject().put("id", r.pkg).put("label", r.label));
        } catch (Exception ignored) { }
        return out.toString();
    }

    /** [{title, live}] — the games set up in PokeRPGLink. */
    @JavascriptInterface
    public String games() {
        org.json.JSONArray out = new org.json.JSONArray();
        try {
            for (String g : Prefs.games(ctx)) {
                GameInfo gi = new GameInfo(new File(g));
                if (!gi.supported()) continue;
                out.put(new org.json.JSONObject().put("title", gi.title).put("needsSetup", gi.installedMod() == null || gi.needsLoader()));
            }
        } catch (Exception ignored) { }
        return out.toString();
    }

    /** Opens a game app on the top screen; "" = the usual one. */
    @JavascriptInterface
    public boolean play(String pkg) {
        return GameLauncher.open(ctx, pkg == null || pkg.isEmpty() ? null : pkg);
    }

    /** Opens PokeRPGLink's setup screen on the bottom screen. */
    @JavascriptInterface
    public void openSetup() {
        Intent i = new Intent(ctx, MainActivity.class).setAction(MainActivity.ACTION_SETUP).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        android.view.Display d = MainActivity.bottomDisplay(ctx);
        try {
            if (d != null) {
                android.app.ActivityOptions o = android.app.ActivityOptions.makeBasic();
                o.setLaunchDisplayId(d.getDisplayId());
                ctx.startActivity(i.putExtra("stay", true), o.toBundle());
            } else ctx.startActivity(i);
        } catch (Exception e) {
            try { ctx.startActivity(i); } catch (Exception ignored) { }
        }
    }
}
