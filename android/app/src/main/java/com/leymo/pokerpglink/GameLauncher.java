package com.leymo.pokerpglink;

import android.app.ActivityOptions;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.view.Display;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;

/**
 * Finds the game runtimes on the device (Kirin, JoiPlay, other mkxp ports) and opens
 * them on the top (main) screen. The runtime then shows its own game list — runtimes
 * don't offer a public way for other apps to start one specific game.
 */
final class GameLauncher {
    private GameLauncher() { }

    static final class Runtime {
        final String pkg, label;
        Runtime(String pkg, String label) { this.pkg = pkg; this.label = label; }
    }

    /** Installed runtimes, the player's choice first, then Kirin, then the rest. */
    static List<Runtime> runtimes(Context c) {
        PackageManager pm = c.getPackageManager();
        Intent q = new Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER);
        List<Runtime> kirin = new ArrayList<>(), other = new ArrayList<>();
        for (ResolveInfo ri : pm.queryIntentActivities(q, 0)) {
            String pkg = ri.activityInfo.packageName;
            String label = String.valueOf(ri.loadLabel(pm));
            String s = (label + " " + pkg).toLowerCase(Locale.US);
            if (pkg.equals(c.getPackageName())) continue;
            if (s.contains("kirin")) kirin.add(new Runtime(pkg, label));
            else if (s.matches(".*(joiplay|mkxp).*") && !s.contains("plugin")) other.add(new Runtime(pkg, label));
        }
        List<Runtime> all = new ArrayList<>(kirin);
        for (Runtime r : other) if (all.stream().noneMatch(x -> x.pkg.equals(r.pkg))) all.add(r);
        String pref = Prefs.runtime(c);
        for (int i = 0; i < all.size(); i++) {
            if (all.get(i).pkg.equals(pref)) { all.add(0, all.remove(i)); break; }
        }
        return all;
    }

    static Runtime preferred(Context c) {
        List<Runtime> r = runtimes(c);
        return r.isEmpty() ? null : r.get(0);
    }

    /** Opens the runtime on the main screen (or brings it back if it's already running). */
    static boolean open(Context c, String pkg) {
        if (pkg == null) {
            Runtime r = preferred(c);
            if (r == null) return false;
            pkg = r.pkg;
        }
        Intent li = c.getPackageManager().getLaunchIntentForPackage(pkg);
        if (li == null) return false;
        Prefs.setRuntime(c, pkg);
        li.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        ActivityOptions o = ActivityOptions.makeBasic();
        o.setLaunchDisplayId(Display.DEFAULT_DISPLAY);
        try {
            c.startActivity(li, o.toBundle());
            return true;
        } catch (Exception e) {
            try { c.startActivity(li); return true; } catch (Exception ignored) { return false; }
        }
    }
}
