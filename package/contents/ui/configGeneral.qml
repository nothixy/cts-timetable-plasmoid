import QtQuick 2.0
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_stops: stops.text
    property alias cfg_token: token.text
    property string cfg_tokenDefault: ''
    property string cfg_stopsDefault: ''
    Kirigami.FormLayout {
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Token")
        }
        TextField {
            id: stops
            visible: false
            onTextChanged: {
                let values = text.split(',');
                repeater.model = values.length;
                for (let index in values) {
                    if (repeater.itemAt(index) == null) {
                        continue;
                    }
                    repeater.itemAt(index).children[1].text = values[index];
                }
            }
        }
        TextField {
            id: token
            placeholderText: i18n("Token")
        }
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Stops to monitor")
        }
        ColumnLayout {
            Kirigami.ContextualHelpButton {
                toolTipText: i18n("You can find stop IDs by making a request to https://api.cts-strasbourg.eu/v1/siri/2.0/stoppoints-discovery")
            }
            Repeater {
                id: repeater
                model: 0
                property bool just_added: false
                Component.onCompleted: {
                    let values = stops.text.split(',');
                    if (just_added) {
                        values.push('');
                    }
                    repeater.model = values.length;
                    for (let index in values) {
                        repeater.itemAt(index).children[1].text = values[index];
                    }
                }
                delegate: RowLayout {
                    Label {
                        text: i18n("Stop ID")
                    }
                    TextField {
                        id: stop_id
                        Kirigami.FormData.label: i18n("Stop ID")
                        placeholderText: i18n("Stop ID")
                        onTextChanged: {
                            stops.text = new Array(repeater.model).fill(0).map((x, i) => repeater.itemAt(i).children[1].text).join(',');
                        }
                    }
                    Button {
                        id: del
                        icon.name: 'list-remove'
                        onClicked: {
                            let found = false;
                            let arr = [];
                            let delta = 0;
                            for (let i = 0; i < repeater.model; ++i) {
                                if (delta != 0) {
                                    repeater[i - delta] = repeater.itemAt(i);
                                }
                                if (repeater.itemAt(i) == parent || repeater.itemAt(i).children[1].text == '') {
                                    delta += 1;
                                    continue;
                                }
                                arr.push(repeater.itemAt(i).children[1].text);
                            }
                            stops.text = arr.join(',');
                        }
                    }
                }
            }
            Button {
                id: add
                icon.name: 'list-add'
                onClicked: {
                    let old_text = stops.text;
                    repeater.just_added = true;
                    repeater.model++;
                    stops.text = old_text;
                    let values = stops.text.split(',');
                    for (let index in values) {
                        repeater.itemAt(index).children[1].text = values[index];
                    }
                }
            }
        }
    }
}
