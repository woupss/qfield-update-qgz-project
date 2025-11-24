import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Theme
import org.qfield
import org.qgis
import QtCore

Item {
    id: updatePlugin
    property var mainWindow: iface.mainWindow()

    // =========================================================================
    // 1. CONFIGURATION
    // =========================================================================
    
    property string fullDestinationPath: ""
    property bool isSuccess: false

    // =========================================================================
    // 2. LOGIQUE
    // =========================================================================

    // Fonction pour nettoyer et valider le nom du fichier
    function getCorrectedFileName() {
        var rawName = filenameInput.text.trim();
        if (rawName === "") return "";

        var lower = rawName.toLowerCase();
        // Vérifie si ça finit par .qgz ou .qgs
        if (!lower.endsWith(".qgz") && !lower.endsWith(".qgs")) {
            return rawName + ".qgz";
        }
        return rawName;
    }

    function calculatePath() {
        platformUtilities.requestStoragePermission();
        
        var folder = qgisProject.homePath;
        if (!folder) {
            folder = "/storage/emulated/0/Android/data/ch.opengis.qfield/files/imported_projects";
        }

        // On récupère le nom avec l'extension corrigée automatiquement
        var fileName = getCorrectedFileName();
        
        // Si le champ est vide, on ne met pas de slash pour l'affichage
        var displayFile = fileName === "" ? "[filename]" : fileName;
        
        fullDestinationPath = folder + "/" + fileName;
        pathDisplay.text = folder + "/\n" + displayFile; 
    }

    function startDownload() {
        // On applique la correction du nom dans le champ de texte visible pour l'utilisateur
        var finalName = getCorrectedFileName();
        if (filenameInput.text.trim() !== "" && filenameInput.text !== finalName) {
            filenameInput.text = finalName;
        }

        calculatePath();

        var currentUrl = urlInput.text.trim();
        
        if (currentUrl === "") {
            mainWindow.displayToast(qsTr("URL is empty!"))
            return;
        }
        if (finalName === "") {
            mainWindow.displayToast(qsTr("Filename is empty!"))
            return;
        }

        //mainWindow.displayToast(qsTr("Connecting to server..."))
        pBar.visible = true
        pBar.indeterminate = true
        statusText.text = qsTr("Downloading...")
        statusText.color = Theme.mainColor
        downloadBtn.enabled = false
        
        infoBox.visible = false
        infoText.visible = false

        var xhr = new XMLHttpRequest()
        xhr.open("GET", currentUrl)
        xhr.responseType = "arraybuffer"

        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                pBar.visible = false
                downloadBtn.enabled = true
                
                if (xhr.status === 200 || xhr.status === 0) {
                    saveToDisk(xhr.response)
                } else {
                    var err = "HTTP Error: " + xhr.status
                    statusText.text = err
                    statusText.color = "red"
                    mainWindow.displayToast(err)
                }
            }
        }
        xhr.send()
    }

    function saveToDisk(data) {
        try {
            statusText.text = qsTr("Writing to disk...")
            
            var success = FileUtils.writeFileContent(fullDestinationPath, data)

            if (success) {
                isSuccess = true 
                
                statusText.text = "SUCCESS"
                statusText.color = "#80cc28"
                
                // Texte avec instruction de reload
                infoText.text = "⚠️ ACTION REQUIRED:\nTo apply changes, please return to the main menu and reload the project."
                
                infoText.visible = true
                infoBox.visible = true

            } else {
                statusText.text = qsTr("Write error.")
                statusText.color = "red"
                mainWindow.displayToast(qsTr("Write failed"))
            }
        } catch (e) {
            statusText.text = "Exception: " + e
            statusText.color = "red"
        }
    }

    // =========================================================================
    // 3. INTERFACE
    // =========================================================================

    Component.onCompleted: {
        iface.addItemToPluginsToolbar(toolbarButton)
    }

    QfToolButton {
        id: toolbarButton
        iconSource: "icon.svg" 
        iconColor: Theme.mainColor
        bgcolor: Theme.darkGray
        round: true

        onClicked: {
            calculatePath(); 
            isSuccess = false
            statusText.text = qsTr("Ready to update.")
            statusText.color = "black"
            infoBox.visible = false
            infoText.visible = false
            pBar.visible = false
            downloadBtn.enabled = true
            downloadDialog.open()
        }
    }

    Dialog {
        id: downloadDialog
        parent: mainWindow.contentItem
        modal: true
        width: Math.min(450, mainWindow.width * 0.95)
        x: (mainWindow.width - width) / 2
        y: (mainWindow.height - height) / 2
        standardButtons: Dialog.NoButton
        
        background: Rectangle { 
            color: "white"
            border.color: Theme.mainColor
            border.width: 2
            radius: 8 
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 16
            anchors.bottomMargin: 16
            anchors.topMargin: 2
            spacing: 10

            Label {
                text: qsTr("UPDATE")
                font.bold: true
                font.pointSize: 16
                Layout.alignment: Qt.AlignHCenter
            }

            // --- URL INPUT ---
            Text { text: "Source URL:"; color: "#666"; font.pixelSize: 12 }
            TextField {
                id: urlInput
                text: "https://"
                placeholderText: "https://example.com/file.qgz"
                selectByMouse: true
                Layout.fillWidth: true
            }

            // --- FILENAME INPUT ---
            Text { text: "Target filename:"; color: "#666"; font.pixelSize: 12 }
            TextField {
                id: filenameInput
                text: "" 
                placeholderText: "project_name.qgz"
                selectByMouse: true
                Layout.fillWidth: true
                
                // Recalcule le chemin à chaque frappe
                onTextChanged: calculatePath()
                
                // Correction automatique à la fin de l'édition
                onEditingFinished: {
                    var corrected = getCorrectedFileName();
                    if (text !== "" && text !== corrected) {
                        text = corrected;
                    }
                }
            }
            
            // --- MESSAGE ROUGE ---
            Text { 
                text: "The current project will be replaced if names match."
                color: "red"
                font.italic: true
                font.pixelSize: 12 
                Layout.fillWidth: true
                Layout.topMargin: -5 
                Layout.bottomMargin: 5
            }
            
            // --- PATH DISPLAY ---
            Text { text: "Full destination path:"; color: "#666"; font.pixelSize: 12 }
            Text { 
                id: pathDisplay
                text: "..." 
                font.bold: true
                font.pixelSize: 12
                color: "#000000"//Theme.mainColor
                wrapMode: Text.WrapAnywhere
                Layout.fillWidth: true 
            }

            ProgressBar { 
                id: pBar
                Layout.fillWidth: true
                visible: false
                indeterminate: true 
            }
            
            Text { 
                id: statusText
                text: qsTr("Ready.")
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.bold: true 
            }
            
            // --- INFO BOX (MODIFIÉ: GRIS) ---
            Rectangle {
                id: infoBox
                visible: false
                
                // Fond gris clair
                color: "#f0f0f0" 
                radius: 4
                // Bordure un peu plus foncée
                border.color: "#dcdcdc"
                
                Layout.fillWidth: true
                Layout.preferredHeight: infoText.contentHeight + 30 
                Layout.topMargin: 10

                Text { 
                    id: infoText
                    visible: parent.visible
                    text: ""
                    // Couleur du texte changée en noir/gris foncé pour être lisible sur le gris
                    color: "#333333" 
                    font.pixelSize: 13 
                    font.bold: true 
                    wrapMode: Text.WordWrap 
                    width: parent.width - 20
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter 
                    verticalAlignment: Text.AlignVCenter
                }
            }

            // --- BOUTON D'ACTION ---
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 15
                spacing: 20
                Layout.alignment: Qt.AlignHCenter
                
                Button {
                    id: downloadBtn
                    text: isSuccess ? "Close" : "Update"
                    Layout.preferredWidth: 220
                    
                    background: Rectangle { 
                        color: enabled ? (isSuccess ? "#28a745" : Theme.mainColor) : "#ccc"
                        radius: 4 
                    }
                    
                    contentItem: Text { 
                        text: parent.text
                        color: "white"
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter 
                    }
                    
                    onClicked: {
                        if (isSuccess) {
                            downloadDialog.close()
                        } else {
                            startDownload()
                        }
                    }
                }
            }
        }
    }
}