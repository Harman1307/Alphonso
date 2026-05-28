pragma Singleton
import QtQuick

QtObject {
    id: anims

    property string profile: "bubbly"

    property int instant: 0
    property int snap:   profile === "none" ? 0 : profile === "calm" ? 200 : 140
    property int fast:   profile === "none" ? 0 : profile === "calm" ? 320 : 220
    property int medium: profile === "none" ? 0 : profile === "calm" ? 420 : 320
    property int slow:   profile === "none" ? 0 : profile === "calm" ? 560 : 380
    property int xslow:  profile === "none" ? 0 : profile === "calm" ? 740 : 540

    property real springPower: profile === "none" ? 0 : profile === "calm" ? 0.5 : 1.5

    property int enterDuration: profile === "none" ? 0 : profile === "calm" ? 480 : 350
    property int exitDuration:  profile === "none" ? 0 : profile === "calm" ? 300 : 220

    property real enterScale: profile === "none" ? 1.0 : profile === "calm" ? 0.97 : 0.96
    property real hoverScale: profile === "none" ? 1.0 : profile === "calm" ? 1.02 : 1.03

    function setProfile(p) {
        profile = p
        UIState.setAnimationProfile(p)
    }

    function getLabel() {
        if (profile === "bubbly") return "Bubbly"
        if (profile === "calm")   return "Calm"
        return "None"
    }

    function getIcon() {
        if (profile === "bubbly") return "󰗣"
        if (profile === "calm")   return ""
        return "󱐋"
    }
}