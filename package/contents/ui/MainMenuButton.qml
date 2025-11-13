import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt.labs.platform as QtLabs
import org.kde.kcmutils
import org.kde.plasma.plasmoid
import org.kde.ksvg 1.0 as KSvg
import org.kde.kirigami 2 as Kirigami
import org.kde.coreaddons as KCoreAddons
import org.kde.plasma.private.sessions 2.0 as Sessions
import org.kde.taskmanager 0.1 as TaskManager
// Akua
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5S


AbstractButton {
    id: menuButton

    readonly property string appStoreCommand: Plasmoid.configuration.appStoreCommand
        ?? Plasmoid.configuration.appStoreCommandDefault
    readonly property string aboutThisPCCommand: Plasmoid.configuration.aboutThisPCCommand
        ?? Plasmoid.configuration.aboutThisPCCommandDefault
    readonly property bool aboutThisPCUseCommand: Plasmoid.configuration.aboutThisPCUseCommand
        ?? Plasmoid.configuration.aboutThisPCUseCommandDefault

    readonly property var customCommandsConfig: Plasmoid.configuration.commands
    readonly property bool customCommandsInSeparateMenu: Plasmoid.configuration.customCommandsInSeparateMenu
        ?? Plasmoid.configuration.customCommandsInSeparateMenuDefault
    readonly property string customCommandsMenuTitle: Plasmoid.configuration.customCommandsMenuTitle ?? ""

    property var customCommands: []

    enum State {
        Rest,
        Hover,
        Down
    }
    property int menuState: {
        if (down) {
            return MainMenuButton.State.Down;
        } else if (hovered && !menu.isOpened) {
            return MainMenuButton.State.Hover;
        }
        return MainMenuButton.State.Rest;
    }

    Connections {
        target: Plasmoid
        function onActivated() {
            Plasmoid.configuration.shortcutOpensPlasmoid
                ? menuButton.clicked()
                : forceQuit.show()
        }
    }

    Sessions.SessionManagement {
        id: sm
    }

    TaskManager.TasksModel {
        id: tasksModel
    }

    KCoreAddons.KUser {
        id: kUser
    }


    onCustomCommandsConfigChanged: {
        let commands = [];
        for (const command of Plasmoid.configuration.commands ?? []) {
            const data = JSON.parse(command)
            commands.push(data)
        }
        customCommands = commands
    }

	onCustomCommandsChanged: {
		// remove one-by-one so Instantiator.onObjectRemoved fires,
		// allowing customCommandsSubMenu.removeItem()/menu.removeItem() to run
		for (let i = customMenuEntries.count - 1; i >= 0; --i) {
			customMenuEntries.remove(i)
		}
		for (const command of customCommands) {
			customMenuEntries.append(command)
		}
	}

    onClicked: {
        menu.isOpened ? menu.close() : menu.open(root)
    }

    Layout.preferredHeight: root.height
    Layout.preferredWidth: Plasmoid.configuration.useRectangleButtonShape
        ? Layout.preferredHeight * 1.5
        : Layout.preferredHeight

    contentItem: Item {
        width: parent.width
        height: parent.height
        Kirigami.Icon {
            id: menuIcon
            anchors.centerIn: parent
            source: root.icon
            height: {
                if (Plasmoid.configuration.useFixedIconSize) {
                    if (Plasmoid.configuration.resizeIconToRoot) {
                        return Plasmoid.configuration.fixedIconSize > root.height
                            ? root.height
                            : Plasmoid.configuration.fixedIconSize
                    }
                    return Plasmoid.configuration.fixedIconSize
                }
                return parent.height * (Plasmoid.configuration.iconSizePercent / 100)
            }
            width: height
        }
    }

    down: menu.isOpened

    background: KSvg.FrameSvgItem {
        id: rest
        height: parent.height
        width: parent.width
        imagePath: "widgets/menubaritem"
        prefix: switch (menuButton.menuState) {
            case MainMenuButton.State.Down: return "pressed";
            case MainMenuButton.State.Hover: return "hover";
            case MainMenuButton.State.Rest: return "normal";
        }
    }

    QtLabs.Menu {
        id: menu
        property bool isOpened: false
        readonly property int customCommandsEntryStartIndex: 2
        QtLabs.MenuItem {
            id: aboutThisPCMenuItem
            text: i18n("About This PC")
            onTriggered: menuButton.aboutThisPCUseCommand
                ? doCommand(menuButton.aboutThisPCCommand)
                : KCMLauncher.openInfoCenter("")
        }

        QtLabs.MenuSeparator {}

		ListModel { id: customMenuEntries }

        QtLabs.Menu {
            id: customCommandsSubMenu
            enabled: menuButton.customCommandsInSeparateMenu && customMenuEntries.length > 0
            visible: menuButton.customCommandsInSeparateMenu
            title: menuButton.customCommandsMenuTitle?.length > 0 ? menuButton.customCommandsMenuTitle : i18n("Commands")
            Instantiator {
                model: menuButton.customCommandsInSeparateMenu ? customMenuEntries : []
                active: menuButton.customCommandsInSeparateMenu
                delegate: QtLabs.MenuItem {
                    text: model.text
                    onTriggered: {
                        doCommand(model.command)
                    }
                }

                onObjectAdded: (index, object) => customCommandsSubMenu.insertItem(
                    customCommandsSubMenu.customCommandsEntryStartIndex,
                    object
                )
                onObjectRemoved: (index, object) => customCommandsSubMenu.removeItem(object)
            }
        }
        Instantiator {
            model: menuButton.customCommandsInSeparateMenu ? [] : customMenuEntries
            active: !menuButton.customCommandsInSeparateMenu
            delegate: QtLabs.MenuItem {
                text: model.text
                onTriggered: {
                    doCommand(model.command)
                }
            }

            onObjectAdded: (index, object) => menu.insertItem(menu.customCommandsEntryStartIndex, object)
            onObjectRemoved: (index, object) => menu.removeItem(object)
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            id: systemSettingsMenuItem
            text: i18n("System Settings...")
            onTriggered: {
                KCMLauncher.openSystemSettings("");
            }
        }

        QtLabs.MenuItem {
            id: appStoreMenuItem
            text: i18n("App Store...")
            onTriggered: {
                doCommand(menuButton.appStoreCommand)
            }
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            text: i18n("Force Quit...")
            onTriggered: {
                root.forceQuit.show()
            }
            shortcut: Plasmoid.configuration.shortcutOpensPlasmoid ? null : plasmoid.globalShortcut
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            visible: sm.canSuspend
            text: i18n("Sleep")
            onTriggered: sm.suspend()
        }
        QtLabs.MenuItem {
            text: i18n("Restart...")
            onTriggered: sm.requestReboot();
        }
        QtLabs.MenuItem {
            text: i18n("Shut Down...")
            onTriggered: sm.requestShutdown();
        }

        QtLabs.MenuSeparator {}

        QtLabs.MenuItem {
            text: i18n("Lock Screen")
            shortcut: "Meta+L"
            onTriggered: sm.lock()
        }
        QtLabs.MenuItem {
            text: {
                i18n("Log Out %1...", kUser.fullName)
            }
            shortcut: "Ctrl+Alt+Delete"
            onTriggered: sm.requestLogout()
        }
        onAboutToHide: menu.isOpened = false
        onAboutToShow: menu.isOpened = true
    }

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
		console.warn("Darwin Exec: " + cmdString);

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
