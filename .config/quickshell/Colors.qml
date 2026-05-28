pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: colors

    property color bg:      "#11111b"
    property color fg:      "#cdd6f4"
    property color accent:  "#89b4fa"
    property color green:   "#a6e3a1"
    property color red:     "#f38ba8"
    property color yellow:  "#f9e2af"
    property color surface: "#1e1e2e"
    property color dim:     "#6c7086"

    Behavior on bg      { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on fg      { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on accent  { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on green   { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on red     { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on yellow  { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on surface { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }
    Behavior on dim     { ColorAnimation { duration: 500; easing.type: Easing.OutCubic } }

    property bool darkMode: true
    property bool autoMode: true
    property int  revision: 0

    property string wallpaperPath:  Quickshell.env("HOME") + "/wallpapers/current"
    property string irisPath:       Quickshell.env("HOME") + "/.config/quickshell/iris/iris.py"
    property string nvimColorsPath: Quickshell.env("HOME") + "/.config/nvim/lua/colors.lua"
    property string gtkCssPath:     Quickshell.env("HOME") + "/.config/gtk-4.0/gtk.css"
    property string gtk3CssPath:    Quickshell.env("HOME") + "/.config/gtk-3.0/gtk.css"

    function a(c, o) { return Qt.rgba(c.r, c.g, c.b, o) }

    function toHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    function applyFromJson(data) {
        try {
            var p = JSON.parse(data)

            if (autoMode && !UIState.darkModeLocked) {
                var shouldBeDark
                if      (p.tone_l < 0.45) shouldBeDark = true
                else if (p.tone_l > 0.55) shouldBeDark = false
                else                      shouldBeDark = darkMode

                if (shouldBeDark !== darkMode) {
                    darkMode = shouldBeDark
                    irisProc.running = false
                    irisProc.running = true
                    return
                }
            }

            bg      = p.bg
            fg      = p.fg
            accent  = p.accent
            green   = p.green
            red     = p.red
            yellow  = p.yellow
            surface = p.surface
            dim     = p.dim
            revision++
            writeNvimColors(p)
            writeGtkColors(p)
        } catch(e) {
            console.log("iris: failed to parse output:", e)
        }
    }

    function applyCurrentMode(dark) {
        darkMode = dark
        autoMode = false
        irisProc.running = false
        irisProc.running = true
    }

    function runIris() {
        irisProc.running = false
        irisProc.running = true
    }

    function writeNvimColors(p) {
        var lines = [
            'return {',
            '    bg             = "' + p.bg                             + '",',
            '    surface        = "' + p.surface                        + '",',
            '    fg             = "' + p.fg                             + '",',
            '    dim            = "' + p.dim                            + '",',
            '    accent         = "' + p.accent                         + '",',
            '    red            = "' + p.red                            + '",',
            '    green          = "' + p.green                          + '",',
            '    yellow         = "' + p.yellow                         + '",',
            '    syntax_keyword  = "' + (p.syntax_keyword  || p.accent) + '",',
            '    syntax_string   = "' + (p.syntax_string   || p.yellow) + '",',
            '    syntax_func     = "' + (p.syntax_func     || p.green)  + '",',
            '    syntax_type     = "' + (p.syntax_type     || p.accent) + '",',
            '    syntax_const    = "' + (p.syntax_const    || p.red)    + '",',
            '    syntax_comment  = "' + (p.syntax_comment  || p.dim)    + '",',
            '    syntax_param    = "' + (p.syntax_param    || p.fg)     + '",',
            '    syntax_operator = "' + (p.syntax_operator || p.accent) + '",',
            '    dark           = ' + (p.dark ? 'true' : 'false')       + ',',
            '}',
            ''
        ]

        var script = lines.map(function(line) {
            return "echo " + JSON.stringify(line)
        }).join("; ")

        nvimWriteProc.command = ["bash", "-c",
            "(" + script + ") > " + JSON.stringify(nvimColorsPath)]
        nvimWriteProc.running = true
    }

    function writeGtkColors(p) {
        var css = [
            "@define-color accent_color "           + p.accent  + ";",
            "@define-color accent_bg_color "        + p.accent  + ";",
            "@define-color accent_fg_color "        + p.bg      + ";",
            "@define-color destructive_color "      + p.red     + ";",
            "@define-color destructive_bg_color "   + p.red     + ";",
            "@define-color destructive_fg_color "   + p.bg      + ";",
            "@define-color success_color "          + p.green   + ";",
            "@define-color success_bg_color "       + p.green   + ";",
            "@define-color success_fg_color "       + p.bg      + ";",
            "@define-color warning_color "          + p.yellow  + ";",
            "@define-color warning_bg_color "       + p.yellow  + ";",
            "@define-color warning_fg_color "       + p.bg      + ";",
            "@define-color window_bg_color "        + p.bg      + ";",
            "@define-color window_fg_color "        + p.fg      + ";",
            "@define-color view_bg_color "          + p.surface + ";",
            "@define-color view_fg_color "          + p.fg      + ";",
            "@define-color headerbar_bg_color "     + p.surface + ";",
            "@define-color headerbar_fg_color "     + p.fg      + ";",
            "@define-color headerbar_border_color " + p.dim     + ";",
            "@define-color popover_bg_color "       + p.surface + ";",
            "@define-color popover_fg_color "       + p.fg      + ";",
            "@define-color dialog_bg_color "        + p.bg      + ";",
            "@define-color dialog_fg_color "        + p.fg      + ";",
            "@define-color sidebar_bg_color "       + p.surface + ";",
            "@define-color sidebar_fg_color "       + p.fg      + ";",
            "@define-color card_bg_color "          + p.surface + ";",
            "@define-color card_fg_color "          + p.fg      + ";",
            ""
        ].join("\n")

        var escaped = css.replace(/'/g, "'\\''")
        var scheme  = darkMode ? "'prefer-dark'" : "'prefer-light'"

        gtkWriteProc.command = ["bash", "-c",
            "mkdir -p ~/.config/gtk-4.0 ~/.config/gtk-3.0 && " +
            "printf '%s' '" + escaped + "' > " + gtkCssPath + " && " +
            "printf '%s' '" + escaped + "' > " + gtk3CssPath + " && " +
            "gsettings set org.gnome.desktop.interface color-scheme " + scheme + " 2>/dev/null || true"]
        gtkWriteProc.running = true
    }

    Process {
        id: irisProc
        command: [
            "python3", colors.irisPath,
            "--wallpaper", colors.wallpaperPath,
            "--dark",      colors.darkMode ? "1" : "0",
            "--glass",     UIState.transparencyEnabled ? "1" : "0"
        ]
        running: true
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => colors.applyFromJson(data)
        }
    }

    Process { id: nvimWriteProc }
    Process { id: gtkWriteProc }

    Process {
        id: wallWatch
        command: ["bash", "-c",
            "prev=''; while true; do " +
            "cur=$(readlink -f '" + wallpaperPath + "' 2>/dev/null); " +
            "if [ \"$cur\" != \"$prev\" ] && [ -n \"$cur\" ]; then " +
            "prev=$cur; echo changed; fi; sleep 1; done"]
        running: true
        stdout: SplitParser {
            onRead: data => reloadDelay.restart()
        }
        onExited: wallWatchRestart.start()
    }

    Timer { id: wallWatchRestart; interval: 2000; onTriggered: wallWatch.running = true }

    Timer {
        id: reloadDelay
        interval: 2000
        onTriggered: {
            autoMode = true
            runIris()
        }
    }
}