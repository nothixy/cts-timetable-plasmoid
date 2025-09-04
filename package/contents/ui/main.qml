import QtQuick 2.0
import QtQuick.Layouts 1.0
import QtQuick.Controls 2.15
import org.kde.plasma.plasmoid 2.0
import org.kde.plasma.components 3.0 as PlasmaComponents3
import org.kde.kirigami as Kirigami
import org.kde.plasma.extras 2.0 as PlasmaExtras

PlasmoidItem {
    id: root
    width: 400
    height: 300
    property string old_token: ''
    property bool old_token_invalid: false
    property int time_remaining: 0
    property var line_colors: ({})
    property var globalobj: ({})
    preferredRepresentation: Plasmoid.compactRepresentation
    fullRepresentation: ColumnLayout {
        id: mainview
        height: root.height
        width: root.width
        Timer {
            interval: 1000
            repeat: true
            running: true
            onTriggered: {
                let token = plasmoid.configuration.token;
                if (!token || token.length == 0) {
                    return;
                }
                if (old_token_invalid && old_token == token) {
                    return;
                }
                const xhr = new XMLHttpRequest();
                xhr.onload = () => {
                    if (xhr.status != 200) {
                        if (xhr.status == 401) {
                            old_token = token;
                            old_token_invalid = true;
                        }
                        return;
                    }
                    let parsed = JSON.parse(xhr.response);
                    let alf = parsed['LinesDelivery']['AnnotatedLineRef'];
                    for (let line of alf) {
                        let color = line['Extension']['RouteColor'];
                        let r = parseInt(color.substring(0, 2), 16);
                        let g = parseInt(color.substring(2, 4), 16);
                        let b = parseInt(color.substring(4, 6), 16);
                        line_colors[line['LineRef']] = {'r': r / 255, 'g': g / 255, 'b': b / 255};
                    }
                    fetchLines.running = true;
                    this.repeat = false;
                    this.interval = 0;
                }
                xhr.open('GET', "https://api.cts-strasbourg.eu/v1/siri/2.0/lines-discovery", true, token, '');
                xhr.send();
            }
        }
        Timer {
            id: fetchLines
            interval: 1000
            running: false
            repeat: true
            onTriggered: {
                let values = plasmoid.configuration.stops;
                if (typeof(values) == 'string') {
                    values = values.split(',');
                } else {
                    values = values.join(',').split(',');
                }
                if (values.length == 0 || (values.length == 1 && values[0] == '')) {
                    return;
                }
                let token = plasmoid.configuration.token;
                if (!token || token.length == 0) {
                    return;
                }
                if (old_token_invalid && old_token == token) {
                    return;
                }
                time_remaining = time_remaining - 1;
                function update() {
                    let keys = Object.keys(globalobj).sort();
                    start_point.model = keys.length;

                    for (let index in keys) {
                        start_point.itemAt(index).children[0].text = keys[index];
                        let from_start = globalobj[keys[index]];
                        let from_start_keys = Object.keys(from_start).sort();
                        let len = start_point.itemAt(index).children.length;
                        let next_repeat = start_point.itemAt(index).children[len - 1];
                        next_repeat.model = from_start_keys.length;
                        for (let from_start_index in from_start_keys) {
                            let by_line = from_start[from_start_keys[from_start_index]];
                            let by_line_keys = Object.keys(by_line).sort();
                            let following_repeat = next_repeat.itemAt(from_start_index);
                            following_repeat.model = by_line_keys.length;
                            for (let by_line_index in by_line_keys) {
                                let to_dest = by_line[by_line_keys[by_line_index]];
                                let another_repeat = following_repeat.itemAt(by_line_index);
                                another_repeat.children[0].text = `${from_start_keys[from_start_index]} => ${by_line_keys[by_line_index]}`;
                                let len2 = another_repeat.children[1].children.length;
                                let last_repeat = another_repeat.children[1].children[len2 - 1];
                                let times = [];
                                for (let time in to_dest) {
                                    let delta_t = (Number(new Date(to_dest[time])) - Number(Date.now())) / (15 * 60 * 1000);
                                    let value = delta_t >= 1 ? 1 : delta_t;
                                    if (value <= 0) {
                                        delete to_dest[time];
                                    }
                                    times.push(value);
                                }
                                let percentage_opacity = 0;
                                let target_opacity = 0;
                                let old_target_opacity = 0;
                                let element_opacity = 0;
                                let sorted = times.sort().reverse();
                                last_repeat.model = sorted.length;
                                for (let time in sorted) {
                                    percentage_opacity = 100.0 * ((parseInt(time, 10) + 1) / sorted.length);
                                    target_opacity = (Math.exp(percentage_opacity / 100) - 1) * 100 / (Math.exp(1) - Math.exp(0));
                                    element_opacity = (target_opacity - old_target_opacity) / (100 - old_target_opacity);
                                    old_target_opacity = target_opacity;
                                    let color = line_colors[from_start_keys[from_start_index]];
                                    if (time != 0) {
                                        last_repeat.itemAt(time).backgroundColor = Qt.rgba(0, 0, 0, 0);
                                    }
                                    last_repeat.itemAt(time).color = Qt.rgba(color['r'], color['g'], color['b'], element_opacity);
                                    last_repeat.itemAt(time).value = sorted[time];
                                }
                            }
                        }
                    }
                }
                if (time_remaining > 0) {
                    update();
                    return;
                }
                const xhr = new XMLHttpRequest();
                xhr.onload = () => {
                    if (xhr.status != 200) {
                        if (xhr.status == 401) {
                            old_token = token;
                            old_token_invalid = true;
                        }
                        return;
                    }
                    let parsed = JSON.parse(xhr.response);
                    let smd = parsed['ServiceDelivery']['StopMonitoringDelivery'][0];
                    if (smd['MonitoringRef'] == null) {
                        time_remaining = 30;
                        return;
                    }
                    globalobj = {};
                    let response_timestamp = new Date(smd['ResponseTimestamp']);
                    let valid_until = new Date(smd['ValidUntil']);
                    time_remaining = (Number(valid_until) - Number(response_timestamp)) / 1000;
                    let visits = smd['MonitoredStopVisit'];
                    for (let visit of visits) {
                        let stop_name = visit['MonitoredVehicleJourney']['MonitoredCall']['StopPointName'];
                        let line = visit['MonitoredVehicleJourney']['LineRef'];
                        let destination = visit['MonitoredVehicleJourney']['DestinationName'];
                        if (!globalobj[stop_name]) {
                            globalobj[stop_name] = {};
                        }
                        if (!globalobj[stop_name][line]) {
                            globalobj[stop_name][line] = {};
                        }
                        if (!globalobj[stop_name][line][destination]) {
                            globalobj[stop_name][line][destination] = []
                        }
                        globalobj[stop_name][line][destination].push(visit['MonitoredVehicleJourney']['MonitoredCall']['ExpectedDepartureTime']);
                    }
                    update();
                }
                let base_url = "https://api.cts-strasbourg.eu/v1/siri/2.0/stop-monitoring?MonitoringRef=";
                let full_url = base_url + values.join("&MonitoringRef=");
                xhr.open('GET', full_url, true, token, '');
                xhr.send();
            }
        }
        Row {
            Layout.fillWidth: true
            PlasmaComponents3.Label {
                width: parent.width / 3
                horizontalAlignment: Text.AlignLeft
                text: '0\''
            }
            PlasmaComponents3.Label {
                width: parent.width / 3
                horizontalAlignment: Text.AlignHCenter
                text: '7\'30'
            }
            PlasmaComponents3.Label {
                width: parent.width / 3
                horizontalAlignment: Text.AlignRight
                text: '15\''
            }
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            ColumnLayout {
                id: column
                width: scroll.width
                Repeater {
                    Layout.fillWidth: true
                    id: start_point
                    model: 0
                    delegate: ColumnLayout {
                        width: parent.width
                        PlasmaExtras.Heading {
                            id: start_point_text
                            Layout.fillWidth: true
                            text: start_point.model.toString()
                            horizontalAlignment: Text.AlignHCenter
                        }
                        Repeater {
                            id: line
                            model: 0
                            width: start_point.width
                            delegate: Repeater {
                                id: end_point
                                model: 0
                                width: line.width
                                delegate: ColumnLayout {
                                    width: parent.width
                                    PlasmaComponents3.Label {
                                        id: text
                                        Layout.fillWidth: true
                                        text: end_point.model.toString()
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 20
                                        color: "#00000000"
                                        Repeater {
                                            id: times
                                            model: 0
                                            width: parent.width
                                            delegate: ProgressBar {
                                                property color color
                                                property color backgroundColor: Kirigami.ColorUtils.linearInterpolation(Kirigami.Theme.backgroundColor, Kirigami.Theme.textColor, 0.1)
                                                id: bar
                                                width: parent.width
                                                height: 10
                                                value: 0.5
                                                contentItem: Item {
                                                    Rectangle {
                                                        width: bar.visualPosition * parent.width
                                                        height: parent.height
                                                        color: bar.color
                                                        radius: height / 2
                                                    }
                                                }
                                                background: Rectangle {
                                                    width: parent.width
                                                    implicitWidth: 100
                                                    implicitHeight: Kirigami.Units.largeSpacing
                                                    color: backgroundColor
                                                    radius: height / 2
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
