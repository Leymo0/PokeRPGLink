package com.leymo.pokerpglink;

import android.content.Context;
import android.content.SharedPreferences;

final class Prefs {
    private Prefs() { }

    private static SharedPreferences p(Context c) {
        return c.getSharedPreferences("pokerpglink", Context.MODE_PRIVATE);
    }

    /** All game folders the panel watches. The panel follows whichever one is running. */
    static java.util.List<String> games(Context c) {
        java.util.List<String> out = new java.util.ArrayList<>();
        for (String s : p(c).getString("games", "").split("\n")) if (!s.trim().isEmpty() && !out.contains(s.trim())) out.add(s.trim());
        String legacy = p(c).getString("gameDir", "");
        if (!legacy.isEmpty() && !out.contains(legacy)) out.add(legacy);
        return out;
    }

    static void setGames(Context c, java.util.List<String> games) {
        p(c).edit().putString("games", String.join("\n", games)).remove("gameDir").apply();
    }

    static void addGame(Context c, String dir) {
        java.util.List<String> g = games(c);
        if (!g.contains(dir)) g.add(dir);
        setGames(c, g);
    }

    static void removeGame(Context c, String dir) {
        java.util.List<String> g = games(c);
        g.remove(dir);
        setGames(c, g);
    }

    /** Package of the runtime last used to play (Kirin, JoiPlay, …); "" = pick automatically. */
    static String runtime(Context c) { return p(c).getString("runtime", ""); }
    static void setRuntime(Context c, String pkg) { p(c).edit().putString("runtime", pkg).apply(); }

    /** Tapping the PokeRPGLink icon starts the panel and the game app instead of the setup screen. */
    static boolean quickStart(Context c) { return p(c).getBoolean("quickStart", true); }
    static void setQuickStart(Context c, boolean v) { p(c).edit().putBoolean("quickStart", v).apply(); }

    /** Show the panel on the bottom screen right after the Thor starts. */
    static boolean startOnBoot(Context c) { return p(c).getBoolean("startOnBoot", false); }
    static void setStartOnBoot(Context c, boolean v) { p(c).edit().putBoolean("startOnBoot", v).apply(); }
}
