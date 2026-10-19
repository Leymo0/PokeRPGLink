package com.leymo.pokerpglink;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.nio.charset.StandardCharsets;
import java.util.zip.Deflater;

/**
 * Pokémon Essentials v19+ games (Pokémon Tectonic and many others) run their plugins
 * from Data/PluginScripts.rxdata — a Ruby Marshal array of
 *   [name, meta-hash, [[file name, zlib-compressed code], …]]
 * The Plugins/ folder is only re-read when the game is started in debug mode, which
 * players (and Android runtimes) don't do. So PokeRPGLink appends one tiny plugin to that
 * array: a loader that runs Plugins/PokeRPGLink/PokeRPGLink.rb. The loader never changes, so
 * updating PokeRPGLink later only means replacing the .rb file.
 *
 * Appending is safe without understanding the rest of the file: the array's length is
 * at the start, the elements follow one after another, and our element only uses
 * objects of its own (no back-references into the game's data).
 */
final class PluginInjector {
    static final String PLUGIN_NAME = "PokeRPGLink Loader";
    static final String REL = "Data/PluginScripts.rxdata";
    static final String BACKUP = "Data/PluginScripts.rxdata.pokerpglink-backup";

    private static final String LOADER =
            "# Added by the PokeRPGLink app: runs Plugins/PokeRPGLink/PokeRPGLink.rb\n" +
            "begin\n" +
            "  pokerpglink_file = \"Plugins/PokeRPGLink/PokeRPGLink.rb\"\n" +
            "  if File.file?(pokerpglink_file) && !(defined?(PokeRPGLink) && PokeRPGLink.const_defined?(:VERSION))\n" +
            "    eval(File.open(pokerpglink_file, \"rb\") { |f| f.read }.force_encoding(\"UTF-8\"), TOPLEVEL_BINDING, pokerpglink_file)\n" +
            "  end\n" +
            "rescue Exception => e\n" +
            "  begin\n" +
            "    Dir.mkdir(\"PokeRPGLink\") unless File.directory?(\"PokeRPGLink\")\n" +
            "    File.open(\"PokeRPGLink/log.txt\", \"ab\") { |f| f.write(\"[loader] #{e.class}: #{e.message}\\n#{(e.backtrace || [])[0, 6].join(\"\\n\")}\\n\") }\n" +
            "  rescue Exception\n" +
            "  end\n" +
            "end\n";

    private PluginInjector() { }

    static boolean present(File game) {
        return new File(game, REL).isFile();
    }

    static boolean injected(File game) {
        byte[] b = read(new File(game, REL));
        return b != null && indexOf(b, PLUGIN_NAME.getBytes(StandardCharsets.UTF_8)) >= 0;
    }

    /** Adds the loader if it isn't there yet. Returns true when the file is ready. */
    static boolean inject(File game) throws Exception {
        File f = new File(game, REL);
        byte[] b = read(f);
        if (b == null) throw new Exception("can't read " + REL);
        if (indexOf(b, PLUGIN_NAME.getBytes(StandardCharsets.UTF_8)) >= 0) return true;
        if (b.length < 4 || b[0] != 4 || b[1] != 8 || b[2] != '[') throw new Exception(REL + " isn't in the expected format");
        int[] pos = { 3 };
        long count = readLong(b, pos);
        if (count < 0) throw new Exception(REL + " isn't in the expected format");

        ByteArrayOutputStream out = new ByteArrayOutputStream(b.length + 2048);
        out.write(4); out.write(8); out.write('[');
        writeLong(out, count + 1);
        out.write(b, pos[0], b.length - pos[0]);
        writeElement(out);

        File bak = new File(game, BACKUP);
        if (!bak.exists()) write(bak, b);
        File tmp = new File(f.getPath() + ".tmp");
        write(tmp, out.toByteArray());
        if (!tmp.renameTo(f)) { write(f, out.toByteArray()); tmp.delete(); }
        return true;
    }

    // [name, {:name => name, :version => "1"}, [["PokeRPGLinkLoader.rb", deflate(code)]]]
    private static void writeElement(ByteArrayOutputStream o) {
        o.write('[');
        writeLong(o, 3);
        writeUtf8(o, PLUGIN_NAME);
        o.write('{');
        writeLong(o, 2);
        writeSymbol(o, "name");
        writeUtf8(o, PLUGIN_NAME);
        writeSymbol(o, "version");
        writeUtf8(o, "1");
        o.write('[');
        writeLong(o, 1);
        o.write('[');
        writeLong(o, 2);
        writeUtf8(o, "PokeRPGLinkLoader.rb");
        byte[] z = deflate(LOADER.getBytes(StandardCharsets.UTF_8));
        o.write('"');                     // binary string (ASCII-8BIT): no encoding ivar
        writeLong(o, z.length);
        o.write(z, 0, z.length);
    }

    private static void writeUtf8(ByteArrayOutputStream o, String s) {
        byte[] b = s.getBytes(StandardCharsets.UTF_8);
        o.write('I');
        o.write('"');
        writeLong(o, b.length);
        o.write(b, 0, b.length);
        writeLong(o, 1);                  // one instance variable: the encoding
        writeSymbol(o, "E");
        o.write('T');                     // E = true → UTF-8
    }

    private static void writeSymbol(ByteArrayOutputStream o, String s) {
        byte[] b = s.getBytes(StandardCharsets.UTF_8);
        o.write(':');
        writeLong(o, b.length);
        o.write(b, 0, b.length);
    }

    /** Ruby Marshal's compact integer format. */
    static void writeLong(ByteArrayOutputStream o, long v) {
        if (v == 0) { o.write(0); return; }
        if (v > 0 && v < 123) { o.write((int) v + 5); return; }
        if (v < 0 && v > -124) { o.write((int) (v - 5) & 0xff); return; }
        byte[] tmp = new byte[4];
        int n = 0;
        long x = v;
        for (; n < 4; n++) {
            tmp[n] = (byte) (x & 0xff);
            x >>= 8;
            if (x == 0 && v > 0) { n++; break; }
            if (x == -1 && v < 0) { n++; break; }
        }
        o.write(v > 0 ? n : -n & 0xff);
        o.write(tmp, 0, n);
    }

    static long readLong(byte[] b, int[] pos) {
        int c = b[pos[0]++];
        if (c == 0) return 0;
        if (c > 4) return c - 5;
        if (c < -4) return c + 5;
        long x = 0;
        if (c > 0) {
            for (int i = 0; i < c; i++) x |= (long) (b[pos[0]++] & 0xff) << (8 * i);
            return x;
        }
        x = -1;
        for (int i = 0; i < -c; i++) {
            x &= ~(0xffL << (8 * i));
            x |= (long) (b[pos[0]++] & 0xff) << (8 * i);
        }
        return x;
    }

    private static byte[] deflate(byte[] in) {
        Deflater d = new Deflater();
        d.setInput(in);
        d.finish();
        ByteArrayOutputStream o = new ByteArrayOutputStream();
        byte[] buf = new byte[4096];
        while (!d.finished()) { int n = d.deflate(buf); o.write(buf, 0, n); }
        d.end();
        return o.toByteArray();
    }

    private static int indexOf(byte[] hay, byte[] needle) {
        outer:
        for (int i = 0; i + needle.length <= hay.length; i++) {
            for (int j = 0; j < needle.length; j++) if (hay[i + j] != needle[j]) continue outer;
            return i;
        }
        return -1;
    }

    static byte[] read(File f) {
        if (!f.isFile()) return null;
        try (InputStream in = new FileInputStream(f)) {
            ByteArrayOutputStream b = new ByteArrayOutputStream((int) Math.max(f.length(), 16));
            byte[] buf = new byte[65536];
            int n;
            while ((n = in.read(buf)) > 0) b.write(buf, 0, n);
            return b.toByteArray();
        } catch (Exception e) {
            return null;
        }
    }

    private static void write(File f, byte[] data) throws Exception {
        try (FileOutputStream out = new FileOutputStream(f)) { out.write(data); }
    }
}
