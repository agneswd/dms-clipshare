import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Modals.Common
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    pluginId: "clipShare"
    pluginService: PluginService

    property string pluginDir: {
        const url = Qt.resolvedUrl(".").toString()
        return url.startsWith("file://") ? url.substring(7) : url
    }
    property string recordError: ""
    property bool recordErrorReported: false
    property string discardError: ""
    property var discardCallback: null
    property var copyCallback: null
    property string copyKind: ""
    property string copyError: ""
    property bool copyActive: false
    property bool copyTimedOut: false
    property string pendingShareUrl: ""
    property string compressionStage: ""
    property int compressionProgress: 0
    property string compressionResult: ""
    property real compressionResultSize: 0
    property string compressionError: ""
    property string operationState: "idle"
    property string operationKind: ""
    property string operationFilePath: ""
    property real operationFileSize: 0
    readonly property string operationFileName: operationFilePath ? operationFilePath.split("/").pop() : ""
    readonly property string progressPosition: {
        const value = pluginData.progressPosition || "top-right"
        return ["top-right", "top-left", "bottom-right", "bottom-left"].includes(value) ? value : "top-right"
    }
    readonly property string compressionMode: {
        const value = pluginData.compressionMode || "balanced"
        return ["best", "balanced", "gpu"].includes(value) ? value : "balanced"
    }
    readonly property int compressionLimitMb: {
        const value = Number(pluginData.compressionLimitMb)
        return Number.isInteger(value) && value >= 1 && value <= 100 ? value : 10
    }
    readonly property int compressionLimitBytes: compressionLimitMb * 1000000
    readonly property string uploadMode: pluginData.uploadMode === "catbox" ? "catbox" : "embed"

    function validShortcutKey(value) {
        const key = String(value || "").trim()
        return key.length === 1 || ["Enter", "Space", "Escape", "Esc", "Tab", "Backspace", "Delete", "Home", "End", "PageUp", "PageDown", "Up", "Down", "Left", "Right"].includes(key)
    }

    function singleShortcut(value, fallback) {
        const key = String(value || "").trim()
        return validShortcutKey(key) ? key : fallback
    }

    function chordShortcut(value) {
        const parts = String(value || "").split("+")
        return parts.length === 2 && validShortcutKey(parts[0]) && validShortcutKey(parts[1]) && parts[0] !== parts[1]
            ? parts[0].trim() + "+" + parts[1].trim() : "Space+Enter"
    }

    readonly property string copyShortcut: singleShortcut(pluginData.copyShortcut, "Enter")
    readonly property string compressShortcut: singleShortcut(pluginData.compressShortcut, "Space")
    readonly property string shareShortcut: chordShortcut(pluginData.shareShortcut)
    readonly property string discardShortcut: singleShortcut(pluginData.discardShortcut, "Escape")
    readonly property string recordShortcut: pluginData.recordShortcut || "Shift+Print"
    readonly property string recordingDirectory: pluginData.recordingDirectory || "~/Videos/ClipShare"

    function toastInfo(message) {
        if (typeof ToastService !== "undefined" && ToastService)
            ToastService.showInfo(message)
    }

    function toastError(message) {
        if (typeof ToastService !== "undefined" && ToastService)
            ToastService.showError(message)
    }

    function toggle() {
        if (recordProcess.running)
            return

        recordError = ""
        recordErrorReported = false
        recordProcess.command = ["bash", pluginDir + "scripts/clipshare-record", "toggle", recordingDirectory]
        recordProcess.running = true
    }

    function handleRecordLine(line) {
        const fields = line.split("\t")
        const event = fields[0]

        if (event === "started") {
            toastInfo("Recording started. Press " + recordShortcut + " to finish.")
        } else if (event === "ready" && fields[1]) {
            completionPanel.openFor(fields[1], Number(fields[2]) || 0)
        } else if (event === "cancelled") {
            toastInfo("Recording cancelled")
        } else if (event === "error") {
            recordErrorReported = true
            toastError(fields.slice(1).join(" ") || "Screen recording failed")
        }
    }

    function finishCopy(success) {
        if (!copyActive)
            return

        const callback = copyCallback
        const kind = copyKind
        const errorText = copyTimedOut ? "Clipboard copy timed out" : copyError
        copyActive = false
        copyTimedOut = false
        copyCallback = null
        copyKind = ""
        copyTimeout.stop()
        if (success) {
            pendingShareUrl = ""
            toastInfo(kind === "text" ? "Share link copied to clipboard" : "Recording copied to clipboard")
        } else {
            toastError(errorText || (kind === "text" ? "Could not copy the share link" : "Could not copy the recording to the clipboard"))
        }
        if (typeof callback === "function")
            callback(success)
    }

    function startCopy(kind, args, callback) {
        if (copyProcess.running || copyActive) {
            if (typeof callback === "function")
                callback(false)
            return
        }

        copyError = ""
        copyTimedOut = false
        copyKind = kind
        copyCallback = callback
        copyActive = true
        copyProcess.command = ["bash", pluginDir + "scripts/clipshare-copy"].concat(args)
        copyProcess.running = true
        copyTimeout.restart()
    }

    function copyLocalFile(path, callback) {
        if (!path) {
            if (typeof callback === "function")
                callback(false)
            return
        }

        startCopy("file", ["copy-file", path], callback)
    }

    function copyText(text, callback) {
        if (!text) {
            if (typeof callback === "function")
                callback(false)
            return
        }

        startCopy("text", ["copy-text", text], callback)
    }

    function discardLocalFile(path, callback) {
        if (!path || discardProcess.running) {
            if (typeof callback === "function")
                callback(false)
            return
        }

        discardError = ""
        discardCallback = callback
        discardProcess.command = ["bash", pluginDir + "scripts/clipshare-record", "discard", path, recordingDirectory]
        discardProcess.running = true
    }

    function startLocalCompression(path, sizeBytes) {
        if (!path || compressionProcess.running)
            return false

        if (sizeBytes > 0 && sizeBytes < compressionLimitBytes) {
            copyLocalFile(path, () => {})
            return true
        }

        compressionStage = "checking"
        compressionProgress = 0
        compressionResult = ""
        compressionResultSize = 0
        compressionError = ""
        operationState = "working"
        operationKind = "compression"
        operationFilePath = path
        operationFileSize = sizeBytes
        progressHud.targetScreen = CompositorService.getFocusedScreen()
        compressionProcess.command = ["bash", pluginDir + "scripts/clipshare-process", "local-compress", path, compressionMode, String(compressionLimitMb)]
        compressionProcess.running = true
        return true
    }

    function startShare(path, sizeBytes) {
        if (!path || shareProcess.running || compressionProcess.running)
            return false

        compressionStage = "checking"
        compressionProgress = 0
        compressionError = ""
        operationState = "working"
        operationKind = "sharing"
        operationFilePath = path
        operationFileSize = sizeBytes
        progressHud.targetScreen = CompositorService.getFocusedScreen()
        shareProcess.command = ["bash", pluginDir + "scripts/clipshare-process", "share", path, uploadMode]
        shareProcess.running = true
        return true
    }

    function handleCompressionLine(line) {
        const fields = line.split("\t")
        const event = fields[0]

        if (event === "stage") {
            compressionStage = fields[1] || ""
        } else if (event === "progress") {
            compressionProgress = Math.max(0, Math.min(100, Number(fields[1]) || 0))
        } else if (event === "compressed") {
            compressionResult = fields[1] || ""
            compressionResultSize = Number(fields[2]) || 0
        } else if (event === "error") {
            compressionError = fields.slice(1).join(" ")
        }
    }

    function reopenFailedOperation() {
        if (operationState !== "error")
            return

        if (pendingShareUrl) {
            operationState = "working"
            compressionStage = "copying-link"
            copyText(pendingShareUrl, success => {
                if (!success) {
                    compressionError = "The upload succeeded, but clipboard copy failed. Link: " + pendingShareUrl
                    operationState = "error"
                    return
                }
                operationState = "success"
                successHideTimer.restart()
            })
            return
        }

        if (operationKind === "compression" && operationFilePath) {
            operationState = "working"
            compressionStage = "copying-file"
            copyLocalFile(operationFilePath, success => {
                if (!success) {
                    compressionError = copyError
                        ? "The compressed recording is safe, but clipboard copy failed: " + copyError
                        : "The compressed recording is safe, but clipboard copy failed"
                    operationState = "error"
                    return
                }
                operationState = "success"
                successHideTimer.restart()
            })
            return
        }

        if (!operationFilePath)
            return
        const message = compressionError
        operationState = "idle"
        completionPanel.openFor(operationFilePath, operationFileSize, message)
    }

    Process {
        id: recordProcess
        running: false

        stdout: SplitParser {
            onRead: line => root.handleRecordLine(line)
        }

        stderr: StdioCollector {
            onStreamFinished: root.recordError = text.trim()
        }

        onExited: exitCode => {
            if (exitCode !== 0 && !root.recordErrorReported)
                root.toastError(root.recordError || "Screen recording failed")
        }
    }

    Process {
        id: discardProcess
        running: false

        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split("\t")
                if (fields[0] === "error")
                    root.discardError = fields.slice(1).join(" ")
            }
        }

        stderr: StdioCollector {
            onStreamFinished: root.discardError = text.trim()
        }

        onExited: exitCode => {
            const callback = root.discardCallback
            root.discardCallback = null
            if (exitCode === 0) {
                root.toastInfo("Recording discarded")
                if (typeof callback === "function")
                    callback(true)
                return
            }
            root.toastError(root.discardError || "Could not discard recording")
            if (typeof callback === "function")
                callback(false)
        }
    }

    Process {
        id: copyProcess
        running: false

        stderr: StdioCollector {
            id: copyStderr
            onStreamFinished: root.copyError = text.trim()
        }

        onExited: exitCode => {
            if (!root.copyError)
                root.copyError = copyStderr.text.trim()
            root.finishCopy(exitCode === 0 && !root.copyTimedOut)
        }
    }

    Timer {
        id: copyTimeout
        interval: 8000
        repeat: false
        onTriggered: {
            if (!copyProcess.running)
                return
            root.copyTimedOut = true
            copyProcess.running = false
            root.finishCopy(false)
        }
    }

    Process {
        id: compressionProcess
        running: false

        stdout: SplitParser {
            onRead: line => root.handleCompressionLine(line)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() && !root.compressionError)
                    root.compressionError = text.trim()
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 || !root.compressionResult) {
                root.toastError(root.compressionError || "Could not compress recording")
                root.operationState = "error"
                return
            }

            root.compressionStage = "copying-file"
            const result = root.compressionResult
            root.operationFilePath = result
            root.operationFileSize = root.compressionResultSize
            root.copyLocalFile(result, success => {
                if (!success) {
                    root.compressionError = root.copyError
                        ? "The compressed recording is safe, but clipboard copy failed: " + root.copyError
                        : "The compressed recording is safe, but clipboard copy failed"
                    root.operationState = "error"
                    return
                }
                root.operationState = "success"
                successHideTimer.restart()
            })
        }
    }

    Process {
        id: shareProcess
        running: false
        property string resultUrl: ""

        stdout: SplitParser {
            onRead: line => {
                const fields = line.split("\t")
                if (fields[0] === "stage") {
                    root.compressionStage = fields[1] || ""
                } else if (fields[0] === "progress") {
                    root.compressionProgress = Math.max(0, Math.min(100, Number(fields[1]) || 0))
                } else if (fields[0] === "result" && fields.length >= 2) {
                    shareProcess.resultUrl = fields[1]
                } else if (fields[0] === "error") {
                    root.compressionError = fields.slice(1).join(" ")
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim() && !root.compressionError)
                    root.compressionError = text.trim()
            }
        }

        onRunningChanged: {
            if (running) {
                resultUrl = ""
                root.pendingShareUrl = ""
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0 || !resultUrl) {
                root.toastError(root.compressionError || "Could not share recording")
                root.operationState = "error"
                return
            }
            root.pendingShareUrl = resultUrl
            root.compressionStage = "copying-link"
            root.copyText(resultUrl, success => {
                if (!success) {
                    root.compressionError = "The upload succeeded, but clipboard copy failed. Link: " + resultUrl
                    root.operationState = "error"
                    return
                }
                root.operationState = "success"
                successHideTimer.restart()
            })
        }
    }

    Timer {
        id: successHideTimer
        interval: 2500
        repeat: false
        onTriggered: {
            if (root.operationState === "success")
                root.operationState = "idle"
        }
    }

    IpcHandler {
        target: "clipShare"
        enabled: true

        function toggle(): string {
            root.toggle()
            return "SUCCESS"
        }
    }

    ClipShareModal {
        id: completionPanel
        daemon: root
    }

    ClipShareProgress {
        id: progressHud
        daemon: root
    }
}
