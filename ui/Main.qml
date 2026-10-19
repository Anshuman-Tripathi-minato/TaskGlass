import QtQuick 6.7
import QtQuick.Controls 6.7
import QtQuick.Layouts 6.7
import QtQuick.Window 6.7

ApplicationWindow {
    id: win
    width: 1440
    height: 900
    minimumWidth: 1120
    minimumHeight: 720
    visible: true
    title: "TaskGlass — System Intelligence"
    color: "#070b13"

    property int page: 0
    property int selectedPid: 0
    property var selected: ({})
    property var stats: ({})
    property real cpu: 0
    property real mem: 0
    property real disk: 0
    property real down: 0
    property real up: 0
    property var cpuHist: []
    property var memHist: []
    property var diskHist: []
    property var netHist: []
    property string clockText: ""
    property string toastText: ""
    property string toastTone: "good"

    function sync() {
        cpu = backend.val("cpu"); mem = backend.val("mem"); disk = backend.val("disk")
        down = backend.val("down"); up = backend.val("up")
        cpuHist = backend.val("cpuHist"); memHist = backend.val("memHist"); diskHist = backend.val("diskHist"); netHist = backend.val("netHist")
        stats = JSON.parse(backend.statsJson())
    }

    Component.onCompleted: sync()

    Connections {
        target: backend
        function onMetricsChanged() { win.sync() }
        function onClockChanged(v) { win.clockText = v }
        function onSelectedChanged() { win.selected = JSON.parse(backend.selectedJson()) }
        function onToast(text, tone) {
            win.toastText = text; win.toastTone = tone; toastTimer.restart()
        }
    }

    Timer { id: toastTimer; interval: 2700; onTriggered: win.toastText = "" }

    Rectangle { anchors.fill: parent; color: "#070b13" }
    Rectangle { width: parent.width*0.38; height: parent.height*0.72; x: -100; y: -150; radius: 300; opacity: 0.16; color: "#7c5cff" }
    Rectangle { width: parent.width*0.34; height: parent.height*0.55; x: parent.width*0.68; y: parent.height*0.34; radius: 300; opacity: 0.11; color: "#29d9b6" }
    Rectangle { width: parent.width*0.22; height: parent.height*0.28; x: parent.width*0.36; y: parent.height*0.72; radius: 220; opacity: 0.08; color: "#59a6ff" }

    Rectangle {
        id: shell
        anchors.fill: parent
        anchors.margins: 22
        radius: 30
        color: "#0b111d"
        border.color: "#26334a"
        border.width: 1

        Rectangle { anchors.fill: parent; anchors.margins: 1; radius: 29; color: "transparent"; border.color: "#ffffff10"; border.width: 1 }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 16

            Rectangle {
                id: side
                Layout.preferredWidth: 220
                Layout.fillHeight: true
                radius: 24
                color: "#0c1422dd"
                border.color: "#ffffff0c"

                ColumnLayout {
                    anchors.fill: parent; anchors.margins: 18; spacing: 18
                    RowLayout { Layout.fillWidth: true; spacing: 10
                        Rectangle { width: 42; height: 42; radius: 14; color: "#8e6bff"; opacity: .98
                            Text { anchors.centerIn: parent; text: "TG"; color: "white"; font.pixelSize: 16; font.bold: true }
                        }
                        ColumnLayout { spacing: 0; Layout.fillWidth: true
                            Text { text: "TASKGLASS"; color: "#eff3ff"; font.pixelSize: 16; font.bold: true; letterSpacing: 2 }
                            Text { text: "system intelligence"; color: "#71809b"; font.pixelSize: 10; letterSpacing: 1 }
                        }
                    }

                    Rectangle { Layout.fillWidth: true; height: 1; color: "#ffffff0b" }

                    Text { text: "WORKSPACE"; color: "#53627a"; font.pixelSize: 10; font.bold: true; letterSpacing: 1.4; Layout.leftMargin: 6 }
                    NavButton { label: "Overview"; icon: "dashboard.svg"; index: 0 }
                    NavButton { label: "Processes"; icon: "process.svg"; index: 1 }
                    NavButton { label: "Network"; icon: "network.svg"; index: 2 }
                    NavButton { label: "Storage"; icon: "storage.svg"; index: 3 }
                    NavButton { label: "System"; icon: "system.svg"; index: 4 }

                    Item { Layout.fillHeight: true }

                    Rectangle {
                        Layout.fillWidth: true; height: 116; radius: 18; color: "#111b2ad8"; border.color: "#ffffff0a"
                        ColumnLayout { anchors.fill: parent; anchors.margins: 14; spacing: 9
                            RowLayout { Layout.fillWidth: true
                                Text { text: "LIVE"; color: "#70f2d4"; font.pixelSize: 9; font.bold: true; letterSpacing: 1.4 }
                                Item { Layout.fillWidth: true }
                                Rectangle { width: 7; height: 7; radius: 4; color: "#70f2d4" }
                            }
                            Text { text: backend.val("hostname"); color: "#d8def0"; font.pixelSize: 13; elide: Text.ElideRight; Layout.fillWidth: true }
                            Text { text: backend.val("os"); color: "#63728d"; font.pixelSize: 9; wrapMode: Text.WordWrap; Layout.fillWidth: true; maximumLineCount: 2 }
                            Text { text: clockText; color: "#8796af"; font.pixelSize: 10 }
                        }
                    }
                }
            }

            Item { Layout.fillWidth: true; Layout.fillHeight: true
                ColumnLayout { anchors.fill: parent; spacing: 16
                    RowLayout { Layout.fillWidth: true; height: 52
                        ColumnLayout { spacing: 2
                            Text { text: ["Overview","Processes","Network","Storage","System"][page]; color: "#eef2ff"; font.pixelSize: 27; font.bold: true }
                            Text { text: page === 0 ? "A calm, real-time view of your machine." : page === 1 ? "Inspect and control every running process." : page === 2 ? "Interfaces, sockets and live traffic." : page === 3 ? "Volumes, capacity and I/O surfaces." : "Hardware, kernel and session telemetry."; color: "#6f7e98"; font.pixelSize: 11 }
                        }
                        Item { Layout.fillWidth: true }
                        Rectangle { width: 220; height: 42; radius: 15; color: "#0d1625dd"; border.color: "#ffffff0b"
                            RowLayout { anchors.fill: parent; anchors.margins: 11; spacing: 9
                                Image { source: "../assets/search.svg"; width: 16; height: 16; opacity: .6 }
                                TextField { id: search; Layout.fillWidth: true; background: null; placeholderText: "Find processes…"; color: "#dfe7fb"; placeholderTextColor: "#526078"; font.pixelSize: 11; onTextChanged: backend.setFilter(text) }
                            }
                        }
                        GlassButton { label: "Refresh"; width: 86; accent: true; onClicked: backend.refresh() }
                    }

                    Loader { Layout.fillWidth: true; Layout.fillHeight: true; sourceComponent: page === 0 ? overviewPage : page === 1 ? processPage : page === 2 ? networkPage : page === 3 ? storagePage : systemPage }
                }
            }
        }
    }

    Component {
        id: overviewPage
        Item {
            ColumnLayout { anchors.fill: parent; spacing: 14
                RowLayout { Layout.fillWidth: true; height: 134; spacing: 12
                    MetricCard { title: "CPU"; value: Math.round(cpu)+"%"; sub: backend.val("cores")+" cores  ·  "+backend.val("threads")+" threads"; data: cpuHist; accent: "#7b6cff"; Layout.fillWidth: true }
                    MetricCard { title: "MEMORY"; value: Math.round(mem)+"%"; sub: backend.val("memUsed") !== undefined ? backend.val("memUsed") : "Live memory pressure"; data: memHist; accent: "#44d2bf"; Layout.fillWidth: true }
                    MetricCard { title: "DISK"; value: Math.round(disk)+"%"; sub: backend.val("rootFree")+" free"; data: diskHist; accent: "#61a9ff"; Layout.fillWidth: true }
                    MetricCard { title: "NETWORK"; value: backend.val("downFmt"); sub: "↑ "+backend.val("upFmt"); data: netHist; accent: "#ffbf69"; Layout.fillWidth: true }
                }
                RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 14
                    GlassPanel { Layout.fillWidth: true; Layout.fillHeight: true
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 10
                            RowLayout { Layout.fillWidth: true
                                ColumnLayout { spacing: 1
                                    Text { text: "CPU landscape"; color: "#e9eefb"; font.pixelSize: 16; font.bold: true }
                                    Text { text: "60 second utilization"; color: "#64738e"; font.pixelSize: 10 }
                                }
                                Item { Layout.fillWidth: true }
                                ValuePill { text: Math.round(cpu)+"% now"; color: "#19162d"; fg: "#aaa0ff" }
                            }
                            Chart { Layout.fillWidth: true; Layout.fillHeight: true; values: cpuHist; stroke: "#8d7eff"; fill: "#8d7eff" }
                            RowLayout { Layout.fillWidth: true; spacing: 18
                                StatMini { label:"LOAD"; value:backend.val("load") }
                                StatMini { label:"UPTIME"; value:backend.val("uptime") }
                                StatMini { label:"SWAP"; value:Math.round(backend.val("swap"))+"%" }
                            }
                        }
                    }
                    GlassPanel { Layout.preferredWidth: 350; Layout.fillHeight: true
                        ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                            Text { text: "Selected process"; color: "#e9eefb"; font.pixelSize: 16; font.bold: true }
                            Text { text: selected.name || "Click a process below"; color: "#7e8eaa"; font.pixelSize: 11 }
                            Rectangle { Layout.fillWidth: true; height: 1; color: "#ffffff0b" }
                            DetailStat { label:"PID"; value:(selected.pid || "—").toString() }
                            DetailStat { label:"CPU"; value:selected.cpu !== undefined ? Number(selected.cpu).toFixed(1)+"%" : "—" }
                            DetailStat { label:"MEMORY"; value:selected.mem !== undefined ? Number(selected.mem).toFixed(1)+"%" : "—" }
                            DetailStat { label:"THREADS"; value:(selected.threads || "—").toString() }
                            DetailStat { label:"STATUS"; value:selected.status || "—" }
                            DetailStat { label:"USER"; value:selected.user || "—" }
                            Item { Layout.fillHeight: true }
                            RowLayout { Layout.fillWidth: true; spacing: 8
                                GlassButton { label:"Terminate"; onClicked: if(selected.pid) backend.terminate(selected.pid); Layout.fillWidth:true }
                                GlassButton { label:"Kill"; danger:true; onClicked: if(selected.pid) backend.kill(selected.pid); Layout.fillWidth:true }
                            }
                        }
                    }
                }
                GlassPanel { Layout.fillWidth: true; height: 250
                    ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
                        RowLayout { Layout.fillWidth: true
                            ColumnLayout { spacing: 1
                                Text { text: "Live processes"; color: "#e9eefb"; font.pixelSize: 16; font.bold: true }
                                Text { text: backend.val("processCount")+" processes in view"; color: "#64738e"; font.pixelSize: 10 }
                            }
                            Item{Layout.fillWidth:true}
                            GlassButton { label:"Open full process view"; onClicked: win.page=1 }
                        }
                        ProcessHeader {}
                        ListView { id: overviewList; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: processModel; boundsBehavior: Flickable.StopAtBounds; delegate: ProcessRow{} }
                    }
                }
            }
        }
    }

    Component {
        id: processPage
        Item {
            RowLayout { anchors.fill: parent; spacing: 14
                GlassPanel { Layout.fillWidth: true; Layout.fillHeight: true
                    ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 10
                        RowLayout { Layout.fillWidth: true
                            Text { text: backend.val("processCount")+" running processes"; color: "#e9eefb"; font.pixelSize: 16; font.bold: true }
                            Item{Layout.fillWidth:true}
                            GlassButton { label:"Launch command"; onClicked: launchDialog.open() }
                        }
                        RowLayout { Layout.fillWidth: true; spacing: 7
                            SortPill { text:"CPU"; key:"cpu" }
                            SortPill { text:"Memory"; key:"mem" }
                            SortPill { text:"PID"; key:"pid" }
                            SortPill { text:"Name"; key:"name" }
                        }
                        ProcessHeader {}
                        ListView { id: processList; Layout.fillWidth: true; Layout.fillHeight: true; clip: true; model: processModel; delegate: ProcessRow{} }
                    }
                }
                GlassPanel { Layout.preferredWidth: 360; Layout.fillHeight: true
                    ColumnLayout { anchors.fill: parent; anchors.margins: 18; spacing: 12
                        Text { text: "Process intelligence"; color: "#e9eefb"; font.pixelSize: 17; font.bold: true }
                        Text { text: selected.name || "Select a process"; color: "#717f98"; font.pixelSize: 11; elide: Text.ElideRight; Layout.fillWidth:true }
                        Rectangle { Layout.fillWidth:true; height:92; radius:20; color:"#111a2a"; border.color:"#ffffff0a"
                            RowLayout { anchors.fill:parent; anchors.margins:16; spacing:12
                                Rectangle { width:58;height:58;radius:18;color:"#1b1734"; Text {anchors.centerIn:parent;text:"PID";color:"#8f83ff";font.bold:true;font.pixelSize:13} }
                                ColumnLayout { spacing:3
                                    Text { text:(selected.pid || "—").toString(); color:"#f0f3ff";font.pixelSize:22;font.bold:true }
                                    Text { text:selected.exe || "Executable unavailable"; color:"#65738d";font.pixelSize:9;elide:Text.ElideMiddle;Layout.fillWidth:true }
                                }
                            }
                        }
                        DetailStat { label:"CPU"; value:selected.cpu !== undefined ? Number(selected.cpu).toFixed(1)+"%" : "—" }
                        DetailStat { label:"MEMORY"; value:selected.mem !== undefined ? Number(selected.mem).toFixed(1)+"%" : "—" }
                        DetailStat { label:"RSS"; value:selected.rss ? bytes(selected.rss) : "—" }
                        DetailStat { label:"THREADS"; value:(selected.threads||"—").toString() }
                        DetailStat { label:"OPEN FILES"; value:(selected.open_files||"—").toString() }
                        DetailStat { label:"CONNECTIONS"; value:(selected.connections||"—").toString() }
                        Text { text:"COMMAND";color:"#4f607a";font.pixelSize:9;font.bold:true;letterSpacing:1 }
                        Text { text:selected.cmd || "—";color:"#c8d0e2";font.pixelSize:10;wrapMode:Text.Wrap;Layout.fillWidth:true;maximumLineCount:4;elide:Text.ElideRight }
                        Item{Layout.fillHeight:true}
                        RowLayout{Layout.fillWidth:true;spacing:8
                            GlassButton{label:"Suspend";onClicked:if(selected.pid)backend.suspend(selected.pid);Layout.fillWidth:true}
                            GlassButton{label:"Resume";onClicked:if(selected.pid)backend.resume(selected.pid);Layout.fillWidth:true}
                            GlassButton{label:"Kill";danger:true;onClicked:if(selected.pid)backend.kill(selected.pid);Layout.fillWidth:true}
                        }
                    }
                }
            }
        }
    }

    Component { id: networkPage
        Item { ColumnLayout { anchors.fill:parent;spacing:14
            RowLayout{Layout.fillWidth:true;spacing:14
                GlassPanel{Layout.fillWidth:true;height:170
                    ColumnLayout{anchors.fill:parent;anchors.margins:18;spacing:10
                        Text{text:"Traffic";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                        RowLayout{Layout.fillWidth:true;spacing:12
                            BigValue{label:"DOWNLOAD";value:backend.val("downFmt");accent:"#69d7ff";Layout.fillWidth:true}
                            BigValue{label:"UPLOAD";value:backend.val("upFmt");accent:"#ffbf69";Layout.fillWidth:true}
                        }
                    }
                }
                GlassPanel{Layout.preferredWidth:340;height:170
                    ColumnLayout{anchors.fill:parent;anchors.margins:18;spacing:9
                        Text{text:"Interfaces";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                        Repeater{model:stats.interfaces || [];delegate:Text{text:modelData;color:"#8b99b2";font.pixelSize:11}}
                    }
                }
            }
            GlassPanel{Layout.fillWidth:true;Layout.fillHeight:true
                ColumnLayout{anchors.fill:parent;anchors.margins:16;spacing:10
                    Text{text:"Active connections";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                    ProcessHeader{network:true}
                    ListView{Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:stats.connections || [];delegate:NetworkRow{}}
                }
            }
        }} }

    Component { id: storagePage
        Item { ColumnLayout { anchors.fill:parent;spacing:14
            RowLayout{Layout.fillWidth:true;spacing:14
                MetricCard{title:"ROOT USED";value:Math.round(disk)+"%";sub:backend.val("rootFree")+" free";data:diskHist;accent:"#61a9ff";Layout.fillWidth:true}
                GlassPanel{Layout.fillWidth:true;height:134
                    ColumnLayout{anchors.fill:parent;anchors.margins:18;spacing:8
                        Text{text:"Storage signal";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                        Chart{Layout.fillWidth:true;Layout.fillHeight:true;values:diskHist;stroke:"#65b2ff";fill:"#65b2ff"}
                    }
                }
            }
            GlassPanel{Layout.fillWidth:true;Layout.fillHeight:true
                ColumnLayout{anchors.fill:parent;anchors.margins:16;spacing:10
                    Text{text:"Mounted volumes";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                    RowLayout{Layout.fillWidth:true;height:32
                        Text{text:"MOUNT";Layout.fillWidth:true;color:"#53627a";font.pixelSize:9;font.bold:true;letterSpacing:1}
                        Text{text:"USED";width:90;color:"#53627a";font.pixelSize:9;font.bold:true;letterSpacing:1}
                        Text{text:"FREE";width:110;color:"#53627a";font.pixelSize:9;font.bold:true;letterSpacing:1}
                        Text{text:"TOTAL";width:110;color:"#53627a";font.pixelSize:9;font.bold:true;letterSpacing:1}
                    }
                    ListView{Layout.fillWidth:true;Layout.fillHeight:true;clip:true;model:stats.disks || [];delegate:DiskRow{}}
                }
            }
        }} }

    Component { id: systemPage
        Item { ColumnLayout { anchors.fill:parent;spacing:14
            RowLayout{Layout.fillWidth:true;spacing:14
                GlassPanel{Layout.fillWidth:true;height:180
                    ColumnLayout{anchors.fill:parent;anchors.margins:18;spacing:10
                        Text{text:"System telemetry";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                        DetailStat{label:"HOST";value:backend.val("hostname")}
                        DetailStat{label:"OS";value:backend.val("os")}
                        DetailStat{label:"UPTIME";value:backend.val("uptime")}
                        DetailStat{label:"LOAD";value:backend.val("load")}
                    }
                }
                GlassPanel{Layout.fillWidth:true;height:180
                    ColumnLayout{anchors.fill:parent;anchors.margins:18;spacing:10
                        Text{text:"CPU topology";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                        BigValue{label:"PHYSICAL CORES";value:backend.val("cores");accent:"#8c7cff"}
                        BigValue{label:"LOGICAL THREADS";value:backend.val("threads");accent:"#55dbc5"}
                        BigValue{label:"SWAP";value:Math.round(backend.val("swap"))+"%";accent:"#ffbf69"}
                    }
                }
            }
            GlassPanel{Layout.fillWidth:true;Layout.fillHeight:true
                ColumnLayout{anchors.fill:parent;anchors.margins:20;spacing:16
                    Text{text:"Realtime system signals";color:"#e9eefb";font.pixelSize:16;font.bold:true}
                    SignalLine{title:"CPU utilization";value:cpu;accent:"#8c7cff";data:cpuHist}
                    SignalLine{title:"Memory pressure";value:mem;accent:"#48d5c0";data:memHist}
                    SignalLine{title:"Disk usage";value:disk;accent:"#61a9ff";data:diskHist}
                }
            }
        }} }

    Dialog { id: launchDialog; modal:true; width:480; height:190; title:"Launch command"; standardButtons:Dialog.Ok|Dialog.Cancel
        contentItem: ColumnLayout { spacing:12
            Text{text:"Run a command as your user.";color:"#71809b";font.pixelSize:11}
            TextField{id:cmdField;placeholderText:"e.g. xdg-open https://example.com";Layout.fillWidth:true}
        }
        onAccepted:{ backend.launch(cmdField.text);cmdField.text="" }
    }

    Rectangle { visible:toastText.length>0; anchors.right:parent.right;anchors.bottom:parent.bottom;anchors.margins:36; width:340;height:58;radius:18;color: toastTone === "bad" ? "#321723e8" : toastTone === "warn" ? "#322719e8" : "#142a26e8";border.color:"#ffffff16"
        Text{anchors.centerIn:parent;text:toastText;color:"#e8eef9";font.pixelSize:11}
    }

    function bytes(v) { var n=Number(v); var u=["B","KB","MB","GB","TB"];var i=0;while(n>=1024&&i<u.length-1){n/=1024;i++}return n.toFixed(1)+" "+u[i] }

    component NavButton: Rectangle {
        property string label: ""; property string icon: ""; property int index: 0
        Layout.fillWidth: true; height: 46; radius: 14; color: win.page===index ? "#181a35" : "transparent"; border.color: win.page===index ? "#6f63ff44" : "transparent"
        RowLayout{anchors.fill:parent;anchors.margins:12;spacing:12
            Image{source:"../assets/"+icon;width:18;height:18;opacity:win.page===index?0.95:0.46}
            Text{text:label;color:win.page===index?"#eef0ff":"#7b8aa6";font.pixelSize:11;font.bold:win.page===index;Layout.fillWidth:true}
            Rectangle{visible:win.page===index;width:5;height:5;radius:3;color:"#8d7cff"}
        }
        MouseArea{anchors.fill:parent;onClicked:win.page=index}
    }

    component GlassPanel: Rectangle { radius: 22; color:"#0e1625d9"; border.color:"#ffffff0d"; border.width:1; clip:true }
    component GlassButton: Rectangle {
        property string label:""; property bool danger:false; property bool accent:false
        height:38; radius:13; color: danger?"#2a1723": accent?"#705fff":"#121b2ad8"; border.color: danger?"#a53c60":accent?"#8b7dff55":"#ffffff0c"
        Text{anchors.centerIn:parent;text:label;color:danger?"#ff9bb7":"#e6eaff";font.pixelSize:10;font.bold:true}
        MouseArea{anchors.fill:parent;hoverEnabled:true;onPressed:parent.opacity=.7;onReleased:parent.opacity=1;onCanceled:parent.opacity=1}
    }
    component ValuePill: Rectangle { property string text:""; property color color:"#17152d"; property color fg:"#aaa0ff"; height:28;width:Math.max(80,txt.implicitWidth+22);radius:10;color:color;Text{id:txt;anchors.centerIn:parent;text:parent.text;color:fg;font.pixelSize:9;font.bold:true} }
    component StatMini: ColumnLayout { property string label:"";property string value:"";spacing:2;Text{text:label;color:"#516079";font.pixelSize:8;font.bold:true;letterSpacing:1};Text{text:value;color:"#cbd4e8";font.pixelSize:11} }
    component DetailStat: RowLayout { property string label:"";property string value:"";Layout.fillWidth:true;spacing:12;Text{text:label;color:"#4f607a";font.pixelSize:9;font.bold:true;letterSpacing:1;Layout.preferredWidth:90};Text{text:value;color:"#cbd4e8";font.pixelSize:10;elide:Text.ElideMiddle;Layout.fillWidth:true;horizontalAlignment:Text.AlignRight} }
    component BigValue: ColumnLayout { property string label:"";property string value:"";property color accent:"#8c7cff";spacing:2;Text{text:label;color:"#55647d";font.pixelSize:8;font.bold:true;letterSpacing:1};Text{text:value;color:accent;font.pixelSize:22;font.bold:true} }

    component MetricCard: GlassPanel {
        property string title:"";property string value:"";property string sub:"";property var data:[];property color accent:"#8c7cff"
        ColumnLayout{anchors.fill:parent;anchors.margins:16;spacing:7
            RowLayout{Layout.fillWidth:true
                Text{text:title;color:"#596a85";font.pixelSize:9;font.bold:true;letterSpacing:1.5}
                Item{Layout.fillWidth:true}
                Rectangle{width:6;height:6;radius:3;color:accent}
            }
            Text{text:value;color:"#edf2ff";font.pixelSize:27;font.bold:true}
            Text{text:sub;color:"#667590";font.pixelSize:9;elide:Text.ElideRight;Layout.fillWidth:true}
            Chart{Layout.fillWidth:true;Layout.fillHeight:true;values:data;stroke:accent;fill:accent}
        }
    }

    component Chart: Canvas {
        property var values:[]; property color stroke:"#8c7cff"; property color fill:"#8c7cff"
        onPaint:{ var c=getContext("2d");c.clearRect(0,0,width,height);if(!values||values.length<2)return;var min=0,max=100;if(stroke=="#ffbf69"){max=Math.max(100,Math.max.apply(null,values)*1.2)}var pts=[];for(var i=0;i<values.length;i++){var x=i*(width-2)/(values.length-1)+1;var y=height-2-(Math.max(0,Math.min(max,Number(values[i])))/max)*(height-4);pts.push([x,y])};c.beginPath();c.moveTo(pts[0][0],height);for(var j=0;j<pts.length;j++)c.lineTo(pts[j][0],pts[j][1]);c.lineTo(pts[pts.length-1][0],height);c.closePath();c.fillStyle=Qt.rgba(fill.r,fill.g,fill.b,0.08);c.fill();c.beginPath();c.moveTo(pts[0][0],pts[0][1]);for(var k=1;k<pts.length;k++)c.lineTo(pts[k][0],pts[k][1]);c.strokeStyle=stroke;c.lineWidth=2;c.stroke() }
        onValuesChanged:requestPaint()
        Component.onCompleted: requestPaint()
    }

    component ProcessHeader: Rectangle { property bool network:false; Layout.fillWidth:true;height:30;color:"#111a2be8";radius:10
        RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8
            Text{text:network?"LOCAL":"PROCESS";color:"#55657f";font.pixelSize:8;font.bold:true;letterSpacing:1;Layout.fillWidth:true}
            Text{text:network?"REMOTE":"USER";color:"#55657f";font.pixelSize:8;font.bold:true;letterSpacing:1;width:130}
            Text{text:network?"STATUS":"CPU";color:"#55657f";font.pixelSize:8;font.bold:true;letterSpacing:1;width:70}
            Text{text:network?"PID":"MEM";color:"#55657f";font.pixelSize:8;font.bold:true;letterSpacing:1;width:70}
            Text{text:network?"TYPE":"";color:"#55657f";font.pixelSize:8;font.bold:true;letterSpacing:1;width:60}
        }
    }
    component ProcessRow: Rectangle { required property int pid;required property string name;required property string user;required property real cpu;required property real mem;required property string state;required property int threads;property bool hot: cpu>30;Layout.fillWidth:true;width: ListView.view ? ListView.view.width : 400;height:47;color:index%2===0?"#0f1828aa":"#0d1524aa";radius:10;border.color:pid===win.selectedPid?"#786eff44":"transparent"
        RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8
            Text{text:name;color:hot?"#fff0ea":"#e7ecf7";font.pixelSize:10;font.bold:hot;elide:Text.ElideRight;Layout.fillWidth:true}
            Text{text:user;color:"#73829c";font.pixelSize:9;width:130;elide:Text.ElideRight}
            Text{text:cpu.toFixed(1)+"%";color:cpu>20?"#ffb777":"#9ba9c1";font.pixelSize:9;width:70}
            Text{text:mem.toFixed(1)+"%";color:"#8ecac0";font.pixelSize:9;width:70}
            Text{text:state;color:"#71819c";font.pixelSize:9;width:70}
            Text{text:threads.toString();color:"#71819c";font.pixelSize:9;width:60}
        }
        MouseArea{anchors.fill:parent;onClicked:{win.selectedPid=pid;backend.selectProcess(pid);win.page=1}}
    }
    component SortPill: Rectangle { property string text:"";property string key:"";height:30;width:70;radius:10;color:"#101927";border.color:"#ffffff0b";Text{anchors.centerIn:parent;text:parent.text;color:"#96a4ba";font.pixelSize:9;font.bold:true};MouseArea{anchors.fill:parent;onClicked:backend.sortBy(key)}}
    component NetworkRow: Rectangle { required property string local;required property string remote;required property string status;required property int pid;property string type:"";width: ListView.view ? ListView.view.width : 500;height:42;Layout.fillWidth:true;color:index%2===0?"#0f1828aa":"#0d1524aa";RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8;Text{text:local;color:"#d7deed";font.pixelSize:9;elide:Text.ElideRight;Layout.fillWidth:true};Text{text:remote;color:"#7888a2";font.pixelSize:9;width:130;elide:Text.ElideRight};Text{text:status;color:status==="ESTABLISHED"?"#6fe0c5":"#71819c";font.pixelSize:9;width:70};Text{text:(pid||"—").toString();color:"#8c97ab";font.pixelSize:9;width:70};Text{text:type.replace("SocketType.","");color:"#71819c";font.pixelSize:9;width:60}}}
    component DiskRow: Rectangle { required property string mount;required property string device;required property string fstype;required property real used;required property string free;required property string total;width: ListView.view ? ListView.view.width : 500;height:52;Layout.fillWidth:true;color:index%2===0?"#0f1828aa":"#0d1524aa";RowLayout{anchors.fill:parent;anchors.margins:10;spacing:8;ColumnLayout{Layout.fillWidth:true;spacing:2;Text{text:mount;color:"#dce3f3";font.pixelSize:10};Text{text:device+"  ·  "+fstype;color:"#5f6f89";font.pixelSize:8}};Text{text:used.toFixed(0)+"%";color:used>85?"#ff9f86":"#8da0bc";width:90;font.pixelSize:10};Text{text:free;color:"#8da0bc";width:110;font.pixelSize:9};Text{text:total;color:"#8da0bc";width:110;font.pixelSize:9}}}
    component SignalLine: ColumnLayout { property string title:"";property real value:0;property color accent:"#8c7cff";property var data:[];spacing:7
        RowLayout{Layout.fillWidth:true;Text{text:title;color:"#73819a";font.pixelSize:10};Item{Layout.fillWidth:true};Text{text:Math.round(value)+"%";color:accent;font.pixelSize:12;font.bold:true}}
        Rectangle{Layout.fillWidth:true;height:8;radius:4;color:"#131e30";border.color:"#ffffff0a";Rectangle{width:Math.max(2,parent.width*value/100);height:parent.height;radius:4;color:accent;opacity:.85}}
        Chart{Layout.fillWidth:true;height:42;values:data;stroke:accent;fill:accent}
    }
}
