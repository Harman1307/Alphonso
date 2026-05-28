pragma Singleton
import Quickshell
import Quickshell.Io
import QtQuick

Singleton {
    id: ui

    property string activeDropdown: ""
    property bool transparencyEnabled: true
    property real barOpacity: transparencyEnabled ? 0.72 : 1
    property string barMode: "fixed"
    property bool dndEnabled: false
    property bool darkMode: true
    property bool darkModeLocked: false
    property int pfpIndex: 0
    property int borderRadius: 16
    property bool locked: false

    property int volume: 50
    property bool muted: false
    property int brightness: 100

    property var notifications: []
    property int _nid: 0

    signal notificationReceived(int nid, string app, string title, string body)

    property var appUsage: ({})

    property string currentPlayer: ""
    property string lastActivePlayer: ""
    property string mediaTitle: ""
    property string mediaArtist: ""
    property string mediaDisplay: ""
    property string mediaState: "stopped"
    property real mediaPos: 0
    property real mediaLen: 0
    property string mediaArtUrl: ""
    property bool hasMedia: mediaState === "playing" || mediaState === "paused"
    property bool blockMediaPosUpdate: false
    property var cava: [0,0,0,0,0,0,0,0,0,0,0,0]
    property bool cavaDecaying: false
    property int gifIndex: 0
    property int mediaDisplayMode: 0
    property bool mediaVinylWithArt: true
    property string animationProfile: "bubbly"
    property string blurProfile: "balanced"

    property string _settingsPath:    Quickshell.env("HOME") + "/.config/quickshell/state/settings.json"
    property string _appUsagePath:    Quickshell.env("HOME") + "/.config/quickshell/state/app_usage.json"
    property string _kittyColorsPath: Quickshell.env("HOME") + "/.cache/qs/kitty-colors.conf"
    property string _mangoConfigPath: Quickshell.env("HOME") + "/.config/mango/config.conf"
    property string _gifPath:         Quickshell.env("HOME") + "/.config/quickshell/assets/gifs"

    property int _pendingVolume: -1
    property string _savedLayout: ""

    function toHex(c) {
        var r = Math.round(c.r * 255).toString(16).padStart(2, "0")
        var g = Math.round(c.g * 255).toString(16).padStart(2, "0")
        var b = Math.round(c.b * 255).toString(16).padStart(2, "0")
        return "#" + r + g + b
    }

    Component.onCompleted: {
        loadSettings()
        loadAppUsage()
        ensureCacheDir.running = true
        _mediaCmd = _buildMediaCmd()
    }

    Process {
        id: ensureCacheDir
        command: ["bash", "-c", "mkdir -p ~/.cache/qs"]
    }

    Connections {
        target: Colors
        function onRevisionChanged() {
            if (!darkModeLocked) {
                darkMode = Colors.darkMode
            }
            applyDelay.restart()
        }
    }

    Timer {
        id: applyDelay
        interval: 600
        onTriggered: {
            applyKittyColors()
            applyKittyOpacity()
            writeKittyConf()
            updateMangoBorderColors()
        }
    }

    function lock() {
        locked = true
    }

    function toggleDropdown(name) {
        activeDropdown = activeDropdown === name ? "" : name
    }

    function closeDropdowns() {
        activeDropdown = ""
    }

    function addNotification(app, title, body) {
        if (title === "" && body === "") return
        var id = _nid++
        var list = notifications.slice()
        list.unshift({ id: id, app: app, title: title, body: body, time: Date.now() })
        if (list.length > 50) list = list.slice(0, 50)
        notifications = list
        notificationReceived(id, app, title, body)
    }

    function dismissNotif(id) {
        notifications = notifications.filter(n => n.id !== id)
    }

    function clearNotifs() {
        notifications = []
    }

    function dismissGroup(app) {
        notifications = notifications.filter(n => n.app !== app)
    }

    function toggleTransparency() {
        transparencyEnabled = !transparencyEnabled
        applyKittyOpacity()
        writeKittyConf()
        updateMangoOpacity()
        saveSettings()
    }

    function toggleDarkMode() {
        darkMode = !darkMode
        Colors.autoMode = false
        Colors.applyCurrentMode(darkMode)
        saveSettings()
    }

    function toggleDarkModeLock() {
        darkModeLocked = !darkModeLocked
        saveSettings()
    }

    function toggleDnd() {
        dndEnabled = !dndEnabled
        saveSettings()
    }

    function setPfpIndex(idx) {
        pfpIndex = idx
        saveSettings()
    }

    function setVolume(v) {
        volume = v
        _pendingVolume = v
        _volSetDebounce.restart()
    }

    Timer {
        id: _volSetDebounce
        interval: 50
        onTriggered: {
            volSetProc.command = ["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", (_pendingVolume / 100).toFixed(2)]
            volSetProc.running = true
        }
    }

    function setBrightness(v) {
        brightness = v
        brightSetProc.command = ["brightnessctl", "set", v + "%"]
        brightSetProc.running = true
    }

    function doMedia(action) {
        if (!currentPlayer) return
        mediaActionProc.command = ["playerctl", "-p", currentPlayer, action]
        mediaActionProc.running = true
    }

    function seekMedia(pos) {
        if (!currentPlayer || mediaLen <= 0) return
        if (currentPlayer === "mpd" || currentPlayer.indexOf("mpd") !== -1) {
            mediaSeekProc.command = ["mpc", "seek", pos.toString()]
        } else {
            mediaSeekProc.command = ["playerctl", "-p", currentPlayer, "position", pos.toString()]
        }
        mediaSeekProc.running = true
    }

    function setGifIndex(idx) {
        gifIndex = idx
        saveSettings()
    }

    function setMediaDisplayMode(mode) {
        mediaDisplayMode = mode
        saveSettings()
    }

    function setMediaVinylWithArt(val) {
        mediaVinylWithArt = val
        saveSettings()
    }

    function setAnimationProfile(p) {
        animationProfile = p
        applyMangoAnimations()
        saveSettings()
    }

    function setBlurProfile(p) {
        blurProfile = p
        applyMangoBlur()
        saveSettings()
    }

    function setBarMode(mode) {
        barMode = mode
        saveSettings()
    }

    function setBorderRadius(r) {
        borderRadius = r
        borderRadiusProc.command = ["bash", "-c",
            "sed -i 's/^border_radius=.*/border_radius=" + r + "/' " + _mangoConfigPath +
            " && mmsg -d reload_config 2>/dev/null"]
        borderRadiusProc.running = true
        saveSettings()
    }

    function applyMangoAnimations() {
        var configs = {
            "bubbly": {
                type_open:   "zoom",
                type_close:  "zoom",
                layer_open:  "slide",
                layer_close: "slide",
                fade_in:     "1",
                fade_out:    "1",
                zoom_initial: "0.96",
                open: "350", close: "220", move: "320", tag: "340", focus: "180",
                curve_open:    "0.10,1.12,0.18,1.0",
                curve_close:   "0.0,0.0,0.15,1.0",
                curve_move:    "0.12,1.10,0.20,1.02",
                curve_tag:     "0.10,1.12,0.18,1.02",
                curve_focus:   "0.0,0.0,0.15,1.0",
                curve_fadein:  "0.10,1.12,0.18,1.0",
                curve_fadeout: "0.0,0.0,0.15,1.0",
                enabled: "1"
            },
            "calm": {
                type_open:   "zoom",
                type_close:  "zoom",
                layer_open:  "slide",
                layer_close: "slide",
                fade_in:     "1",
                fade_out:    "1",
                zoom_initial: "0.97",
                open: "480", close: "300", move: "420", tag: "720", focus: "240",
                curve_open:    "0.16,1.0,0.3,1.0",
                curve_close:   "0.4,0.0,0.2,1.0",
                curve_move:    "0.2,1.0,0.3,1.0",
                curve_tag:     "0.18,1.0,0.3,1.0",
                curve_focus:   "0.4,0.0,0.2,1.0",
                curve_fadein:  "0.16,1.0,0.3,1.0",
                curve_fadeout: "0.4,0.0,0.6,1.0",
                enabled: "1"
            },
            "none": {
                type_open:   "zoom",
                type_close:  "zoom",
                layer_open:  "slide",
                layer_close: "slide",
                fade_in:     "0",
                fade_out:    "0",
                zoom_initial: "1.0",
                open: "0", close: "0", move: "0", tag: "0", focus: "0",
                curve_open:    "0.0,0.0,1.0,1.0",
                curve_close:   "0.0,0.0,1.0,1.0",
                curve_move:    "0.0,0.0,1.0,1.0",
                curve_tag:     "0.0,0.0,1.0,1.0",
                curve_focus:   "0.0,0.0,1.0,1.0",
                curve_fadein:  "0.0,0.0,1.0,1.0",
                curve_fadeout: "0.0,0.0,1.0,1.0",
                enabled: "0"
            }
        }

        var cfg = configs[animationProfile] || configs["bubbly"]

        var sedCmd = [
            "sed -i",
            "-e 's/^animations=.*/animations=" + cfg.enabled + "/'",
            "-e 's/^layer_animations=.*/layer_animations=" + cfg.enabled + "/'",
            "-e 's/^animation_fade_in=.*/animation_fade_in=" + cfg.fade_in + "/'",
            "-e 's/^animation_fade_out=.*/animation_fade_out=" + cfg.fade_out + "/'",
            "-e 's/^animation_type_open=.*/animation_type_open=" + cfg.type_open + "/'",
            "-e 's/^animation_type_close=.*/animation_type_close=" + cfg.type_close + "/'",
            "-e 's/^layer_animation_type_open=.*/layer_animation_type_open=" + cfg.layer_open + "/'",
            "-e 's/^layer_animation_type_close=.*/layer_animation_type_close=" + cfg.layer_close + "/'",
            "-e 's/^zoom_initial_ratio=.*/zoom_initial_ratio=" + cfg.zoom_initial + "/'",
            "-e 's/^animation_duration_open=.*/animation_duration_open=" + cfg.open + "/'",
            "-e 's/^animation_duration_close=.*/animation_duration_close=" + cfg.close + "/'",
            "-e 's/^animation_duration_move=.*/animation_duration_move=" + cfg.move + "/'",
            "-e 's/^animation_duration_tag=.*/animation_duration_tag=" + cfg.tag + "/'",
            "-e 's/^animation_duration_focus=.*/animation_duration_focus=" + cfg.focus + "/'",
            "-e 's|^animation_curve_open=.*|animation_curve_open=" + cfg.curve_open + "|'",
            "-e 's|^animation_curve_close=.*|animation_curve_close=" + cfg.curve_close + "|'",
            "-e 's|^animation_curve_move=.*|animation_curve_move=" + cfg.curve_move + "|'",
            "-e 's|^animation_curve_tag=.*|animation_curve_tag=" + cfg.curve_tag + "|'",
            "-e 's|^animation_curve_focus=.*|animation_curve_focus=" + cfg.curve_focus + "|'",
            "-e 's|^animation_curve_opafadein=.*|animation_curve_opafadein=" + cfg.curve_fadein + "|'",
            "-e 's|^animation_curve_opafadeout=.*|animation_curve_opafadeout=" + cfg.curve_fadeout + "|'",
            _mangoConfigPath,
            "&& mmsg -d reload_config 2>/dev/null"
        ].join(" ")

        mangoAnimProc.command = ["bash", "-c", sedCmd]
        mangoAnimProc.running = true
    }

    function applyMangoBlur() {
        var configs = {
            "frosted": {
                enabled: "1", layer: "1", optimized: "0",
                passes: "4", radius: "14",
                noise: "0.02", brightness: "0.9", contrast: "0.9", saturation: "1.2"
            },
            "balanced": {
                enabled: "1", layer: "1", optimized: "0",
                passes: "3", radius: "10",
                noise: "0.02", brightness: "0.9", contrast: "0.9", saturation: "1.2"
            },
            "subtle": {
                enabled: "1", layer: "1", optimized: "0",
                passes: "2", radius: "8",
                noise: "0.02", brightness: "0.9", contrast: "0.9", saturation: "1.2"
            },
            "none": {
                enabled: "1", layer: "1", optimized: "0",
                passes: "0", radius: "0",
                noise: "0.02", brightness: "0.9", contrast: "0.9", saturation: "1.2"
            }
        }

        var cfg = configs[blurProfile] || configs["balanced"]

        var sedCmd = [
            "sed -i",
            "-e 's/^blur=.*/blur=" + cfg.enabled + "/'",
            "-e 's/^blur_layer=.*/blur_layer=" + cfg.layer + "/'",
            "-e 's/^blur_optimized=.*/blur_optimized=" + cfg.optimized + "/'",
            "-e 's/^blur_params_num_passes=.*/blur_params_num_passes=" + cfg.passes + "/'",
            "-e 's/^blur_params_radius=.*/blur_params_radius=" + cfg.radius + "/'",
            "-e 's/^blur_params_noise=.*/blur_params_noise=" + cfg.noise + "/'",
            "-e 's/^blur_params_brightness=.*/blur_params_brightness=" + cfg.brightness + "/'",
            "-e 's/^blur_params_contrast=.*/blur_params_contrast=" + cfg.contrast + "/'",
            "-e 's/^blur_params_saturation=.*/blur_params_saturation=" + cfg.saturation + "/'",
            _mangoConfigPath,
            "&& mmsg -d reload_config 2>/dev/null"
        ].join(" ")

        mangoBlurProc.command = ["bash", "-c", sedCmd]
        mangoBlurProc.running = true
    }

    property string _mediaCmd: ""
    onLastActivePlayerChanged: _mediaCmd = _buildMediaCmd()

    function _buildMediaCmd() {
        var last = lastActivePlayer
        return [
            "last='" + last + "'",
            "player=''",
            "for p in $(playerctl -l 2>/dev/null); do",
            "  st=$(playerctl -p \"$p\" status 2>/dev/null)",
            "  [ \"$st\" = \"Playing\" ] && player=\"$p\" && break",
            "done",
            "if [ -z \"$player\" ] && [ -n \"$last\" ]; then",
            "  st=$(playerctl -p \"$last\" status 2>/dev/null)",
            "  [ \"$st\" = \"Paused\" ] && player=\"$last\"",
            "fi",
            "if [ -z \"$player\" ]; then",
            "  for p in $(playerctl -l 2>/dev/null); do",
            "    st=$(playerctl -p \"$p\" status 2>/dev/null)",
            "    [ \"$st\" = \"Paused\" ] && player=\"$p\" && break",
            "  done",
            "fi",
            "[ -z \"$player\" ] && echo 'stopped|||0|0|' && exit 0",
            "s=$(playerctl -p \"$player\" status 2>/dev/null)",
            "art=$(playerctl -p \"$player\" metadata artist 2>/dev/null)",
            "ttl=$(playerctl -p \"$player\" metadata title 2>/dev/null)",
            "pos=$(playerctl -p \"$player\" position 2>/dev/null | cut -d. -f1)",
            "len=$(playerctl -p \"$player\" metadata mpris:length 2>/dev/null)",
            "len=$((len / 1000000))",
            "arturl=$(playerctl -p \"$player\" metadata mpris:artUrl 2>/dev/null)",
            "echo \"$player|$s|$art|$ttl|$pos|$len|$arturl\""
        ].join("\n")
    }

    onMediaStateChanged: {
        if (mediaState !== "playing") cavaDecaying = true
    }

    Process {
        id: mpProc
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.startsWith("stopped|")) {
                    mediaState   = "stopped"
                    mediaTitle   = ""
                    mediaArtist  = ""
                    mediaDisplay = ""
                    mediaPos     = 0
                    mediaLen     = 0
                    mediaArtUrl  = ""
                    return
                }
                var p = line.split("|")
                if (p.length >= 7) {
                    var newPlayer = p[0]
                    var newState  = p[1].toLowerCase()
                    currentPlayer = newPlayer
                    mediaState    = newState
                    mediaArtist   = p[2]
                    mediaTitle    = p[3]
                    if (!blockMediaPosUpdate) mediaPos = parseInt(p[4]) || 0
                    mediaLen      = parseInt(p[5]) || 0
                    mediaArtUrl   = p[6] || ""
                    if (newState === "playing" && newPlayer !== lastActivePlayer)
                        lastActivePlayer = newPlayer
                    var x = mediaTitle
                    if (mediaArtist) x = mediaArtist + " - " + mediaTitle
                    mediaDisplay = x
                }
            }
        }
    }

    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: { mpProc.command = ["bash", "-c", _mediaCmd]; mpProc.running = true }
    }

    Timer {
        interval: 1000; running: mediaState === "playing"; repeat: true
        onTriggered: { if (!blockMediaPosUpdate && mediaPos < mediaLen) mediaPos += 1 }
    }

    Process {
        id: cavaProc
        running: mediaState === "playing"
        command: ["cava", "-p", Quickshell.env("HOME") + "/.config/cava/config_raw"]
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split(";")
                var v = []
                for (var i = 0; i < 12 && i < p.length; i++) v.push(parseInt(p[i]) / 255)
                while (v.length < 12) v.push(0)
                cava = v
            }
        }
        onExited: { if (mediaState === "playing") cavaRestart.start() }
    }

    Timer { id: cavaRestart; interval: 1500; onTriggered: { if (mediaState === "playing") cavaProc.running = true } }

    Timer {
        interval: 60; running: cavaDecaying; repeat: true
        onTriggered: {
            var v = [], done = true
            for (var i = 0; i < 12; i++) {
                var val = cava[i] * 0.72
                if (val > 0.008) { v.push(val); done = false }
                else v.push(0)
            }
            cava = v
            if (done) cavaDecaying = false
        }
    }

    Process { id: mediaActionProc; onExited: { mpProc.command = ["bash", "-c", _mediaCmd]; mpProc.running = true } }
    Process { id: mediaSeekProc }

    function loadAppUsage() {
        appUsageLoadProc.running = true
    }

    function saveAppUsage() {
        var data = JSON.stringify(appUsage)
        appUsageSaveProc.command = ["bash", "-c", "echo '" + data + "' > " + _appUsagePath]
        appUsageSaveProc.running = true
    }

    function recordAppLaunch(appId) {
        var usage = Object.assign({}, appUsage)
        if (!usage[appId]) usage[appId] = { launches: 0, lastUsed: 0 }
        usage[appId].launches += 1
        usage[appId].lastUsed = Date.now()
        appUsage = usage
        saveAppUsage()
    }

    function getAppScore(appId) {
        var u = appUsage[appId]
        if (!u) return 0
        var launches     = u.launches || 0
        var daysSince    = (Date.now() - (u.lastUsed || 0)) / (1000 * 60 * 60 * 24)
        var recencyBonus = Math.max(0, 100 - daysSince * 10)
        return launches * 4 + recencyBonus
    }

    function colorToMango(c) {
        var hex = toHex(c)
        return "0x" + hex.substring(1) + "ff"
    }

    function applyKittyOpacity() {
        kittyOpacityProc.command = ["bash", "-c",
            "for s in /tmp/kitty-socket-*; do " +
            "kitty @ --to unix:$s set-background-opacity " +
            (transparencyEnabled ? "0.8" : "1.0") +
            " 2>/dev/null; done"]
        kittyOpacityProc.running = true
    }

    function applyKittyColors() {
        var bg      = toHex(Colors.bg)
        var fg      = toHex(Colors.fg)
        var accent  = toHex(Colors.accent)
        var surface = toHex(Colors.surface)
        var dim     = toHex(Colors.dim)
        var red     = toHex(Colors.red)
        var green   = toHex(Colors.green)
        var yellow  = toHex(Colors.yellow)

        kittyColorsProc.command = ["bash", "-c",
            "for s in /tmp/kitty-socket-*; do " +
            "kitty @ --to unix:$s set-colors --all --configured " +
            "foreground=" + fg + " " +
            "background=" + bg + " " +
            "cursor=" + accent + " " +
            "selection_foreground=" + bg + " " +
            "selection_background=" + accent + " " +
            "color0=" + surface + " " +
            "color8=" + dim + " " +
            "color1=" + red + " " +
            "color9=" + red + " " +
            "color2=" + green + " " +
            "color10=" + green + " " +
            "color3=" + yellow + " " +
            "color11=" + yellow + " " +
            "color4=" + accent + " " +
            "color12=" + accent + " " +
            "color5=" + accent + " " +
            "color13=" + accent + " " +
            "color6=" + accent + " " +
            "color14=" + accent + " " +
            "color7=" + fg + " " +
            "color15=" + fg +
            " 2>/dev/null; done"]
        kittyColorsProc.running = true
    }

    function writeKittyConf() {
        var bg      = toHex(Colors.bg)
        var fg      = toHex(Colors.fg)
        var accent  = toHex(Colors.accent)
        var surface = toHex(Colors.surface)
        var dim     = toHex(Colors.dim)
        var red     = toHex(Colors.red)
        var green   = toHex(Colors.green)
        var yellow  = toHex(Colors.yellow)
        var opacity = transparencyEnabled ? "0.8" : "1.0"

        kittyConfProc.command = ["bash", "-c", [
            "cat > " + _kittyColorsPath + " << 'KITTYEOF'",
            "background_opacity " + opacity,
            "foreground "               + fg,
            "background "               + bg,
            "cursor "                   + accent,
            "cursor_text_color "        + bg,
            "selection_foreground "     + bg,
            "selection_background "     + accent,
            "url_color "                + accent,
            "active_tab_foreground "    + bg,
            "active_tab_background "    + accent,
            "inactive_tab_foreground "  + dim,
            "inactive_tab_background "  + surface,
            "active_border_color "      + accent,
            "inactive_border_color "    + surface,
            "color0 "  + surface,
            "color8 "  + dim,
            "color1 "  + red,
            "color9 "  + red,
            "color2 "  + green,
            "color10 " + green,
            "color3 "  + yellow,
            "color11 " + yellow,
            "color4 "  + accent,
            "color12 " + accent,
            "color5 "  + accent,
            "color13 " + accent,
            "color6 "  + accent,
            "color14 " + accent,
            "color7 "  + fg,
            "color15 " + fg,
            "KITTYEOF"
        ].join("\n")]
        kittyConfProc.running = true
    }

    function updateMangoOpacity() {
        var unfocused = transparencyEnabled ? "0.85" : "1.0"
        mangoOpacityProc.command = ["bash", "-c",
            "mmsg -d setoption,focused_opacity,1.0 2>/dev/null; " +
            "mmsg -d setoption,unfocused_opacity," + unfocused + " 2>/dev/null; " +
            "sed -i " +
            "'s/^focused_opacity=.*/focused_opacity=1.0/; " +
            "s/^unfocused_opacity=.*/unfocused_opacity=" + unfocused + "/' " +
            _mangoConfigPath]
        mangoOpacityProc.running = true
    }

    function updateMangoBorderColors() {
        var focus     = colorToMango(Colors.accent)
        var urgent    = colorToMango(Colors.red)
        var scratch   = colorToMango(Colors.accent)
        var global    = colorToMango(Colors.accent)
        var overlay   = colorToMango(Colors.green)
        var maxscreen = colorToMango(Colors.yellow)
        var border    = colorToMango(Colors.dim)

        mangoBorderProc.command = ["bash", "-c",
            "sed -i " +
            "'s/^focuscolor=.*/focuscolor=" + focus + "/; " +
            "s/^urgentcolor=.*/urgentcolor=" + urgent + "/; " +
            "s/^scratchpadcolor=.*/scratchpadcolor=" + scratch + "/; " +
            "s/^globalcolor=.*/globalcolor=" + global + "/; " +
            "s/^overlaycolor=.*/overlaycolor=" + overlay + "/; " +
            "s/^maximizescreencolor=.*/maximizescreencolor=" + maxscreen + "/; " +
            "s/^bordercolor=.*/bordercolor=" + border + "/' " +
            _mangoConfigPath + " && mmsg -d reload_config 2>/dev/null"]
        mangoBorderProc.running = true
    }

    function saveSettings() {
        var data = JSON.stringify({
            darkMode:            darkMode,
            darkModeLocked:      darkModeLocked,
            transparencyEnabled: transparencyEnabled,
            dndEnabled:          dndEnabled,
            pfpIndex:            pfpIndex,
            gifIndex:            gifIndex,
            mediaDisplayMode:    mediaDisplayMode,
            mediaVinylWithArt:   mediaVinylWithArt,
            animationProfile:    animationProfile,
            blurProfile:         blurProfile,
            barMode:             barMode,
            borderRadius:        borderRadius
        })
        saveProc.command = ["bash", "-c", "echo '" + data + "' > " + _settingsPath]
        saveProc.running = true
    }

    function loadSettings() {
        loadProc.running = true
    }

    Process { id: saveProc }
    Process { id: kittyOpacityProc }
    Process { id: kittyColorsProc }
    Process { id: kittyConfProc }
    Process { id: mangoOpacityProc }
    Process { id: mangoBorderProc }
    Process { id: appUsageSaveProc }
    Process { id: borderRadiusProc }
    Process { id: mangoAnimProc }
    Process { id: mangoBlurProc }

    Process {
        id: appUsageLoadProc
        command: ["cat", _appUsagePath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try { appUsage = JSON.parse(data.trim()) }
                catch(e) { appUsage = {} }
            }
        }
    }

    Process {
        id: loadProc
        command: ["cat", _settingsPath]
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    var s = JSON.parse(data.trim())
                    if (s.darkMode !== undefined) {
                        darkMode = s.darkMode
                        Colors.autoMode = false
                        Colors.applyCurrentMode(darkMode)
                    }
                    if (s.darkModeLocked      !== undefined) darkModeLocked      = s.darkModeLocked
                    if (s.transparencyEnabled !== undefined) transparencyEnabled = s.transparencyEnabled
                    if (s.dndEnabled          !== undefined) dndEnabled          = s.dndEnabled
                    if (s.pfpIndex            !== undefined) pfpIndex            = s.pfpIndex
                    if (s.gifIndex            !== undefined) gifIndex            = s.gifIndex
                    if (s.mediaDisplayMode    !== undefined) mediaDisplayMode    = s.mediaDisplayMode
                    if (s.mediaVinylWithArt   !== undefined) mediaVinylWithArt   = s.mediaVinylWithArt
                    if (s.animationProfile    !== undefined) {
                        animationProfile = s.animationProfile
                        Animations.profile = s.animationProfile
                    }
                    if (s.blurProfile    !== undefined) blurProfile    = s.blurProfile
                    if (s.barMode        !== undefined) barMode        = s.barMode
                    if (s.borderRadius   !== undefined) borderRadius   = s.borderRadius
                    initDelay.start()
                } catch(e) {}
            }
        }
    }

    Timer {
        id: initDelay
        interval: 800
        onTriggered: {
            applyKittyColors()
            applyKittyOpacity()
            writeKittyConf()
        }
    }

    Process { id: volSetProc }
    Process { id: brightSetProc }

    Process {
        id: volWatch
        command: ["pactl", "subscribe"]
        running: true
        stdout: SplitParser { onRead: data => { if (data.includes("sink")) volDebounce.restart() } }
        onExited: volWatchRestart.start()
    }

    Timer { id: volWatchRestart; interval: 1000; onTriggered: volWatch.running = true }
    Timer { id: volDebounce; interval: 30; onTriggered: volReadProc.running = true }

    Process {
        id: volReadProc
        command: ["bash", "-c",
            "v=$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null); " +
            "m=$(echo \"$v\" | grep -q MUTED && echo 1 || echo 0); " +
            "p=$(echo \"$v\" | awk '{printf \"%.0f\", $2 * 100}'); " +
            "echo \"$p|$m\""]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var p = data.trim().split("|")
                ui.volume = parseInt(p[0]) || 0
                ui.muted  = p[1] === "1"
            }
        }
    }

    Process {
        id: brightReadProc
        command: ["bash", "-c", "brightnessctl -m 2>/dev/null | awk -F, '{gsub(/%/,\"\"); print $4}'"]
        running: true
        stdout: SplitParser { onRead: data => ui.brightness = parseInt(data) || 100 }
    }

    Process {
        id: brightWatch
        command: ["inotifywait", "-m", "-e", "modify", "/sys/class/backlight/intel_backlight/brightness"]
        running: true
        stdout: SplitParser { onRead: data => brightDebounce.restart() }
        onExited: brightWatchRestart.start()
    }

    Timer { id: brightWatchRestart; interval: 1000; onTriggered: brightWatch.running = true }
    Timer { id: brightDebounce; interval: 50; onTriggered: brightReadProc.running = true }

    Behavior on barOpacity { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
}