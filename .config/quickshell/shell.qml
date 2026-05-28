import Quickshell
import Quickshell.Io
import QtQuick

ShellRoot {
    Bar {}

    Variants {
        model: Quickshell.screens
        Dashboard { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        Launcher { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        Wallpaper { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        Music { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        Calendar { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        NotificationPopup { property var modelData; screen: modelData }
    }

    Variants {
        model: Quickshell.screens
        Lockscreen { property var modelData; screen: modelData }
    }

    Process {
        id: launcherToggleWatch
        command: ["bash", "-c", "touch /tmp/qs-launcher-toggle; inotifywait -m -e close_write /tmp/qs-launcher-toggle 2>/dev/null"]
        running: true
        stdout: SplitParser { onRead: data => UIState.toggleDropdown("launcher") }
        onExited: launcherToggleRestart.start()
    }

    Timer { id: launcherToggleRestart; interval: 1000; onTriggered: launcherToggleWatch.running = true }

    Process {
        id: lockWatch
        command: ["bash", "-c", "touch ~/.cache/qs/lock; inotifywait -m -e close_write ~/.cache/qs/lock 2>/dev/null"]
        running: true
        stdout: SplitParser { onRead: data => UIState.lock() }
        onExited: lockWatchRestart.start()
    }

    Timer { id: lockWatchRestart; interval: 1000; onTriggered: lockWatch.running = true }

    Process {
        id: wallpaperToggleWatch
        command: ["bash", "-c", "touch /tmp/qs-wallpaper-toggle; inotifywait -m -e close_write /tmp/qs-wallpaper-toggle 2>/dev/null"]
        running: true
        stdout: SplitParser { onRead: data => UIState.toggleDropdown("wallpaper") }
        onExited: wallpaperToggleRestart.start()
    }

    Timer { id: wallpaperToggleRestart; interval: 1000; onTriggered: wallpaperToggleWatch.running = true }

    Process {
        id: mediaToggleWatch
        command: ["bash", "-c", "touch /tmp/qs-media-toggle; inotifywait -m -e close_write /tmp/qs-media-toggle 2>/dev/null"]
        running: true
        stdout: SplitParser { onRead: data => UIState.toggleDropdown("media") }
        onExited: mediaToggleRestart.start()
    }

    Timer { id: mediaToggleRestart; interval: 1000; onTriggered: mediaToggleWatch.running = true }

    Process {
        id: tiramisu
        command: ["bash", "-c", "tiramisu -o $'#source\\t#summary\\t#body'"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                var line = data.trim()
                if (line.length === 0) return

                var parts = line.split("\t")
                if (parts.length < 3) return

                var app = parts[0] || "Unknown"
                var title = parts[1] || ""
                var body = parts.slice(2).join(" ")

                UIState.addNotification(app, title, body)
            }
        }
        onExited: tiramisuRestart.start()
    }

    Timer { id: tiramisuRestart; interval: 2000; onTriggered: tiramisu.running = true }

    Timer {
        id: wallPregenDelay
        interval: 5000
        running: true
        onTriggered: wallPregenProc.running = true
    }

    Process {
        id: wallPregenProc
        command: ["bash", "-c", [
            "shopt -s nullglob",
            "CACHE=\"$HOME/.cache/wallpaper-thumbs\"",
            "mkdir -p \"$CACHE\"",
            "touch \"$CACHE/colors.tsv\"",
            "",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp}; do",
            "  [ -L \"$f\" ] && continue",
            "  name=$(basename \"$f\")",
            "  thumb=\"$CACHE/${name}.thumb.jpg\"",
            "  [ -f \"$thumb\" ] && continue",
            "  magick \"${f}[0]\" -resize 600x -quality 85 \"$thumb\" 2>/dev/null",
            "done",
            "",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp}; do",
            "  [ -L \"$f\" ] && continue",
            "  name=$(basename \"$f\")",
            "  grep -qF \"$name\" \"$CACHE/colors.tsv\" 2>/dev/null && continue",
            "  best='' best_c=0",
            "  while IFS= read -r line; do",
            "    hex=$(echo \"$line\" | grep -oP '#[0-9A-Fa-f]{6}' | head -1)",
            "    [ -z \"$hex\" ] && continue",
            "    h=\"${hex#\\#}\"",
            "    r=$((16#${h:0:2})) g=$((16#${h:2:2})) b=$((16#${h:4:2}))",
            "    mx=$r; [ $g -gt $mx ] && mx=$g; [ $b -gt $mx ] && mx=$b",
            "    mn=$r; [ $g -lt $mn ] && mn=$g; [ $b -lt $mn ] && mn=$b",
            "    c=$((mx-mn))",
            "    if [ $c -gt $best_c ]; then best_c=$c; best=\"$hex\"; fi",
            "  done < <(magick \"${f}[0]\" -resize 50x50! -colors 5 -depth 8 -format '%c' histogram:info: 2>/dev/null)",
            "  [ -z \"$best\" ] && best=$(magick \"${f}[0]\" -resize 1x1! -format '#%[hex:u.p{0,0}]' info: 2>/dev/null)",
            "  [ -z \"$best\" ] && continue",
            "  printf '%s\\t%s\\n' \"$name\" \"$best\" >> \"$CACHE/colors.tsv\"",
            "done",
            "",
            "json='['",
            "first=1",
            "for f in \"$HOME\"/wallpapers/*.{jpg,jpeg,png,gif,webp}; do",
            "  [ -L \"$f\" ] && continue",
            "  name=$(basename \"$f\")",
            "  color=$(grep -F \"$name\" \"$CACHE/colors.tsv\" 2>/dev/null | head -1 | cut -f2)",
            "  [ $first -eq 0 ] && json=\"${json},\"",
            "  first=0",
            "  json=\"${json}{\\\"name\\\":\\\"${name}\\\",\\\"color\\\":\\\"${color}\\\"}\"",
            "done",
            "json=\"${json}]\"",
            "echo \"$json\" > \"$CACHE/walls.json\""
        ].join("\n")]
    }
}