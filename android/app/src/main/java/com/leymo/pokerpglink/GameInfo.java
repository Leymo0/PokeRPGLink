package com.leymo.pokerpglink;

import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Looks inside a game folder to work out what it is and where it loads .rb mods from.
 * Rebornverse games (Reborn, Rejuvenation, Desolation) load every file matching
 * something like Dir["./patch/Mods/*.rb"]; we read that path straight out of the
 * game's own scripts so new versions that move the folder keep working.
 */
final class GameInfo {
    final File dir;
    String title;
    /** folder the game loads mods from, relative to the game folder; null = no mod loader found */
    String modsPath;
    boolean scriptsLoose;
    /** "rebornverse" (loads Mods/*.rb), "essentials" (loose Data/Scripts),
     *  "plugins" (Essentials v19+ with Data/PluginScripts.rxdata, e.g. Pokémon Tectonic), or null */
    String engine;

    private static final Pattern MODS = Pattern.compile("Dir\\[\\s*[\"']\\.?/?([A-Za-z0-9_ ./-]*?Mods)/\\*\\.rb[\"']\\s*\\]");
    private static final Pattern TITLE = Pattern.compile("GAMETITLE\\s*=\\s*[\"']([^\"']+)[\"']");

    GameInfo(File dir) {
        this.dir = dir;
        scan();
    }

    static boolean looksLikeGame(File d) {
        File[] kids = d.listFiles();
        if (kids == null) return false;
        boolean scripts = false, data = false, exe = false;
        for (File k : kids) {
            String n = k.getName();
            if (n.equals("Scripts") && k.isDirectory()) scripts = true;
            else if (n.equals("Data") && k.isDirectory()) data = true;
            else if (n.equalsIgnoreCase("Game.exe") || n.equalsIgnoreCase("mkxp.json") || n.equalsIgnoreCase("Game.ini")) exe = true;
        }
        return (scripts || data) && exe;
    }

    boolean supported() { return modsPath != null; }

    String engineLabel() {
        if ("essentials".equals(engine)) return "Pokémon Essentials (loose scripts)";
        if ("rebornverse".equals(engine)) return "Rebornverse .rb mods";
        if ("plugins".equals(engine)) return "Pokémon Essentials plugins";
        return "not supported";
    }

    File modsDir() { return modsPath == null ? null : new File(dir, modsPath); }

    File installedMod() {
        if (modsPath != null) {
            File f = new File(modsDir(), "PokeRPGLink.rb");
            if (f.isFile()) return f;
        }
        for (String p : new String[] { "patch/Mods", "Data/Mods", "Data/Scripts/998_PokeRPGLink", "Plugins/PokeRPGLink" }) {
            File f = new File(dir, p + "/PokeRPGLink.rb");
            if (f.isFile()) return f;
        }
        return null;
    }

    /** Plugin games also need the loader inside Data/PluginScripts.rxdata (it disappears when the game updates). */
    boolean needsLoader() {
        return "plugins".equals(engine) && !PluginInjector.injected(dir);
    }

    private void scan() {
        File scripts = new File(dir, "Scripts");
        scriptsLoose = scripts.isDirectory();
        List<File> rbs = new ArrayList<>();
        collect(scripts, rbs, 0);
        // newer Rebornverse builds keep patched scripts in a "patch" folder
        File[] top = dir.listFiles();
        if (top != null) for (File k : top) if (k.isDirectory() && k.getName().equalsIgnoreCase("patch")) collect(k, rbs, 0);
        for (File f : rbs) {
            String text = read(f, 4_000_000);
            if (modsPath == null) {
                Matcher m = MODS.matcher(text);
                if (m.find()) modsPath = m.group(1).replaceAll("^\\./", "");
            }
            if (title == null) {
                Matcher t = TITLE.matcher(text);
                if (t.find()) title = t.group(1);
            }
            if (modsPath != null && title != null) break;
        }
        if (modsPath != null) engine = "rebornverse";
        // Pokémon Essentials v19+ games that ship their scripts as loose files load
        // every .rb under Data/Scripts in folder order: drop PokeRPGLink in just before 999_Main.
        if (modsPath == null) {
            File ds = new File(new File(dir, "Data"), "Scripts");
            List<File> ess = new ArrayList<>();
            collect(ds, ess, 0);
            if (ess.size() > 20) {
                modsPath = "Data/Scripts/998_PokeRPGLink";
                engine = "essentials";
                if (title == null) for (File f : ess) {
                    Matcher t = TITLE.matcher(read(f, 400_000));
                    if (t.find()) { title = t.group(1); break; }
                }
            }
        }
        // Essentials v19+ games with packed scripts still run plugins from Data/PluginScripts.rxdata
        if (modsPath == null && PluginInjector.present(dir)) {
            modsPath = "Plugins/PokeRPGLink";
            engine = "plugins";
            if (title == null && new File(dir, "Plugins/Tectonic Battle").isDirectory()) title = "Pokémon Tectonic";
        }
        if (title == null) title = iniTitle();
        if (title == null) title = dir.getName();
        // Known Rebornverse game but the loader line wasn't readable (e.g. packed scripts): use the usual folder
        if (modsPath == null && title.toLowerCase(Locale.US).matches(".*(reborn|rejuvenation|desolation).*")) {
            engine = "rebornverse";
            boolean hasPatch = false;
            if (top != null) for (File k : top) if (k.isDirectory() && k.getName().equalsIgnoreCase("patch")) hasPatch = true;
            modsPath = hasPatch ? "patch/Mods" : "Data/Mods";
        }
        // folder names on Android shared storage are case-insensitive, but prefer the real spelling
        if (modsPath != null) {
            String[] parts = modsPath.split("/");
            File cur = dir;
            StringBuilder fixed = new StringBuilder();
            for (String part : parts) {
                File match = new File(cur, part);
                File[] kids = cur.listFiles();
                if (kids != null) for (File k : kids) if (k.getName().equalsIgnoreCase(part)) match = k;
                if (fixed.length() > 0) fixed.append('/');
                fixed.append(match.getName());
                cur = match;
            }
            modsPath = fixed.toString();
        }
    }

    private String iniTitle() {
        File ini = new File(dir, "Game.ini");
        if (!ini.isFile()) return null;
        for (String line : read(ini, 100_000).split("\\r?\\n")) {
            if (line.toLowerCase(Locale.US).startsWith("title=")) return line.substring(6).trim();
        }
        return null;
    }

    private static void collect(File d, List<File> out, int depth) {
        if (depth > 3) return;
        File[] kids = d.listFiles();
        if (kids == null) return;
        // shallow files first: the loader and constants live near the top
        for (File k : kids) if (k.isFile() && k.getName().endsWith(".rb")) out.add(k);
        for (File k : kids) if (k.isDirectory()) collect(k, out, depth + 1);
    }

    private static String read(File f, int max) {
        try (InputStream in = new FileInputStream(f)) {
            byte[] buf = new byte[(int) Math.min(f.length(), max)];
            int off = 0, n;
            while (off < buf.length && (n = in.read(buf, off, buf.length - off)) > 0) off += n;
            return new String(buf, 0, off, StandardCharsets.UTF_8);
        } catch (Exception e) {
            return "";
        }
    }
}
