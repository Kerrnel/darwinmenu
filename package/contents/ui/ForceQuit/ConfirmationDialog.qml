import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.kirigami 2.20 as Kirigami
// Akua
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5S

Popup {
    property int selectedAppPid
    property string selectedAppName
    id: confirmationDialog

    SystemPalette {
        id: disabledPalette;
        colorGroup: SystemPalette.Disabled
    }

    focus: true
    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)

    implicitWidth: 400
    implicitHeight: 150
    anchors.centerIn: Overlay.overlay
    dim: true
    modal: true
    enter: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity";
                from: 0.0;
                to: 1.0;
                duration: 300
            }
            NumberAnimation {
                property: "scale";
                from: 0.4;
                to: 1.0;
                easing.type: Easing.OutBack
                duration: 300
            }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation {
                property: "opacity";
                from: 1.0
                to: 0.0;
                duration: 300
            }
            NumberAnimation {
                property: "scale";
                from: 1.0
                to: 0.8;
                duration: 300
            }
        }
    }
    contentItem: ColumnLayout {
        Layout.margins: 20
        RowLayout {
            id: textRow
            Kirigami.Icon {
                id: iconWarning
                width: 128
                source: "dialog-warning"
            }
            ColumnLayout {
                Label {
                    width: parent.width * 0.9
                    Layout.preferredWidth: width
                    Layout.fillWidth: true
                    fontSizeMode: Text.Fit
                    wrapMode: Text.Wrap
                    color: activePalette.text
                    text: i18n("Do you want to force %1 to quit?", confirmationDialog.selectedAppName)
                    font.bold: true
                }

                Label {
                    color: activePalette.text
                    text: i18n("You will lose any unsaved changes.")
                    font.weight: Font.Light
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignRight
            Button {
                focusPolicy: Qt.TabFocus
                id: cancelForceQuit
                text: i18n("Cancel");
                onClicked: {
                    confirmationDialog.close()
                }
            }
            Button {
                focusPolicy: Qt.TabFocus
                text: i18nc("force quit action", "Force Quit")
                onClicked: {
                    doCommand(`kill ${confirmationDialog.selectedAppPid}`)
                    confirmationDialog.close()
                    confirmationDialog.selectedAppPid = 0
                    confirmationDialog.selectedAppName = ""
                }
            }
        }
    }
    Overlay.modal: Rectangle {
        color: {
            const color = disabledPalette.window
            return Qt.hsla(color.hslHue, color.hslSaturation, color.hslLightness, 0.7)
        }
    }
    closePolicy: Popup.NoAutoClose

	// Function to replace the logic.openExec call
	// Kerr 25-11-12 - Happy Birthday CFK!
	//
	// function doCommand(commandString) {
	//	// Debug logging
	//	console.log("Darwin Exec: " + commandString);
	//	var proc = PlasmaCore.Process.findProcess("sh")
	//	if (proc) {
	//		proc.exec("sh", ["-c", cmdString])
	//		return true
	//	}
	//	console.log("Darwin: Failed to get PlasmaCore.Process.findProcess");
	//	return false
	// }

	 // --- Execution backend (Option A: Plasma5Support DataSource "executable")
	 P5S.DataSource {
	     id: execDS
	     engine: "executable"
	     onNewData: (sourceName, data) => {
	         // stdout/stderr/exit code
	         if (data["stdout"] && data["stdout"].length) console.log("exec stdout:", data["stdout"])
	         if (data["stderr"] && data["stderr"].length) console.warn("exec stderr:", data["stderr"])
	         // Important: disconnect to avoid multiplexing repeated runs
	         disconnectSource(sourceName)
	     }
	 }

	 // --- Execution backend (Option B: PlasmaCore.Process fallback if present)
	 function __execViaPlasmaCore(cmdString) {
	     try {
	         // This exists on many builds but is not guaranteed everywhere
	         var proc = PlasmaCore.Process.findProcess("sh")
	         if (proc) {
	             proc.exec("sh", ["-c", cmdString])
	             return true
	         }
	     } catch (e) {
	         console.warn("PlasmaCore.Process fallback failed:", e)
	     }
	     return false
	 }

	// Public runner: doCommand(cmdString, {runInTerminal: bool, cwd: string})
	function doCommand(cmdString, opts) {
		// Debug logging
		console.log("Darwin Exec: " + cmdString);

		opts = opts || {}
		if (opts.runInTerminal === true) {
			// Delegate to user's preferred terminal; keep it simple and portable
			const quoted = JSON.stringify(String(cmdString))
			const tryTerm = [
				"konsole -e bash -lc '" + quoted + "'",
				"xterm -e bash -lc '" + quoted + "'",
				"kitty bash -lc '" + quoted + "'"
			]
			for (let i = 0; i < tryTerm.length; ++i) {
				const s = tryTerm[i]
				if (__execViaPlasmaCore(s)) return
				execDS.connectSource(s)
				return
			}
			return
	     }
		// Use bash -lc to honor pipes/quotes/aliases
		const source = "bash -lc " + JSON.stringify(String(cmdString))
		// Prefer DataSource engine; if unavailable, fallback to PlasmaCore.Process
		try {
			execDS.connectSource(source)
		} catch (e) {
			if (!__execViaPlasmaCore(cmdString)) {
				console.warn("No available exec backend")
			}
		}
	}
}
