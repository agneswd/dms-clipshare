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
    property string compressionStage: ""
    property int compressionProgress: 0
    property string compressionResult: ""
    property string compressionError: ""
    property var compressionCallback: null

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
        recordProcess.command = ["bash", pluginDir + "scripts/clipshare-record", "toggle"]
        recordProcess.running = true
    }

    function handleRecordLine(line) {
        const fields = line.split("\t")
        const event = fields[0]

        if (event === "started") {
            toastInfo("Recording started. Press Shift+Print to finish.")
        } else if (event === "ready" && fields[1]) {
            completionPanel.openFor(fields[1])
        } else if (event === "cancelled") {
            toastInfo("Recording cancelled")
        } else if (event === "error") {
            recordErrorReported = true
            toastError(fields.slice(1).join(" ") || "Screen recording failed")
        }
    }

    function copyLocalFile(path, callback) {
        if (!path) {
            callback(false)
            return
        }

        DMSService.sendRequest("clipboard.copyFile", { "filePath": path }, response => {
            if (response && response.error) {
                toastError("Could not copy the recording to the clipboard")
                callback(false)
                return
            }
            toastInfo("Recording copied to clipboard")
            callback(true)
        })
    }

    function discardLocalFile(path, callback) {
        if (!path || discardProcess.running) {
            callback(false)
            return
        }

        discardError = ""
        discardCallback = callback
        discardProcess.command = ["bash", pluginDir + "scripts/clipshare-record", "discard", path]
        discardProcess.running = true
    }

    function startLocalCompression(path, callback) {
        if (!path || compressionProcess.running) {
            callback(false, "")
            return
        }

        compressionStage = "checking"
        compressionProgress = 0
        compressionResult = ""
        compressionError = ""
        compressionCallback = callback
        compressionProcess.command = ["bash", pluginDir + "scripts/clipshare-process", "local-compress", path]
        compressionProcess.running = true
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
        } else if (event === "error") {
            compressionError = fields.slice(1).join(" ")
        }
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
                callback(true)
                return
            }
            root.toastError(root.discardError || "Could not discard recording")
            callback(false)
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
            const callback = root.compressionCallback
            root.compressionCallback = null
            if (!callback)
                return

            if (exitCode !== 0 || !root.compressionResult) {
                root.toastError(root.compressionError || "Could not compress recording")
                callback(false, "")
                return
            }

            root.compressionStage = "copying-file"
            const result = root.compressionResult
            root.copyLocalFile(result, success => {
                if (!success)
                    root.compressionError = "The compressed recording is safe, but clipboard copy failed"
                callback(success, result)
            })
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
}
