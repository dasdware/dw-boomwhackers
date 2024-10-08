import QtQuick 2.2
import MuseScore 3.0

MuseScore {
    id: boomwhacker_colors

    version: "1.0.0"
    description: "Color notes as per Boomwhacker color scheme. Allows to select which notes for which part should be colored to allow creating parts for individual players."
    title: "Boomwhacker Colors"
    categoryCode: "color-notes"
    pluginType: "dialog"
    thumbnailName: "resources/dw_Boomwhackers.png"

    requiresScore: true

    // configuration
    property int maxPitch: 79
    property int minPitch: 36
    property int maxNoteNumber: maxPitch - minPitch + 1

    property int margin: 16
    property int headerHeight: 32
    property int buttonWidth: 150
    property int buttonHeight: 34
    property int dividerWidth: 24
    property int dividerHeight: 16
    property int noteLabelHeight: 24
    property int octaveLabelWidth: 70
    property int noteButtonSize: 50
    property int gridSpacing: 6
    
    width: margin + buttonWidth + dividerWidth + octaveLabelWidth + 12 * (gridSpacing + noteButtonSize) + margin
    height: margin + headerHeight + dividerHeight + noteLabelHeight + 4 * (gridSpacing + noteButtonSize) + dividerHeight + buttonHeight + margin

    // colors
    property string buttonColor: "#333"
    property string buttonHoverColor: "#666"
    property string buttonPressedColor: "#555"
    property string buttonSelectedColor: "#777"
    property var    voiceColors: [ "#b91c1c", "#a16207", "#4d7c0f", "#0f766e", "#1d4ed8", "#86198f", "#334155", "#020617" ]
    property string emptyNoteColor: "#000000"
    property var    noteColors: [ "#e21c48", "#f26622", "#f99d1c", "#ffcc33", "#fff32b", "#bcd85f", "#62bc47", "#009c95", "#0071bb", "#5e50a1", "#8d5ba6", "#cf3e96" ]
    property var    noteTextColors: [ "#000000", "#000000", "#000000", "#000000", "#000000", "#000000", "#000000", "#ffffff", "#ffffff", "#000000", "#ffffff", "#ffffff" ]

    // labels
    property var noteNames : [ "C", "C#/Db", "D", "D#/Eb", "E", "F", "F#/Gb", "G", "G#/Ab", "A", "A#/Bb", "B" ]
    property var octaveNames: [ "↑", "-", "↓", "↓↓" ]

    // runtime data
    property var voiceSelectionButtons: []
    property var selectedVoice
    property var noteButtons: []
    property var voices: []
    property var voicesByName
    property var sections: []
    property var selectedSection
    property var existingLabels: []

    function existingLabelsIncludes(element) {
        for (let existingLabel of existingLabels) {
            if (existingLabel.is(element)) {
                return true;
            }
        }
        return false;
    }

    function displayMessageDlg(msg) {
        ctrlMessageDialog.text = qsTr(msg);
        ctrlMessageDialog.visible = true;
    }

    function collectChord(voice, chord, section) {
        for (let i = 0; i < chord.notes.length; i++) {
            const pitch = chord.notes[i].pitch;
            if (minPitch <= pitch && pitch <= maxPitch) {
                if (!voice.availableNotes.has(section)) {
                    voice.availableNotes.set(section, []);
                }
                const availableNotes = voice.availableNotes.get(section);

                if (!voice.usedNotes.has(section)) {
                    voice.usedNotes.set(section, []);
                }
                const usedNotes = voice.usedNotes.get(section);

                const noteNumber = pitch - minPitch;
                if (!availableNotes.includes(noteNumber)) {
                    availableNotes.push(noteNumber);
                } if (chord.notes[i].color != emptyNoteColor
                        && !usedNotes.includes(noteNumber)) {
                    usedNotes.push(noteNumber);
                }
            }
        }

        for (let i = 0; i < chord.graceNotes.length; i++) {
            collectChord(voice, chord.graceNotes[i], section);
        }
    }

    function buildSectionMap(staffIndex) {
        const sectionMap = [];
        for (let voiceIndex = 0; voiceIndex < 4; voiceIndex++) {
            const cursor = curScore.newCursor();
            cursor.rewind(Cursor.SCORE_START);
            cursor.staffIdx = staffIndex;
            cursor.voice = voiceIndex;

            while (cursor.segment) {
                for (let i = 0; i < cursor.segment.annotations.length; i++) {
                    const element = cursor.segment.annotations[i];
                    if (element.type === Element.STAFF_TEXT
                            && element.text.startsWith("#BW")
                            && element.staff.is(curScore.staves[staffIndex])) {
                        const section = element.text.substring(3).trim();
                        if (sectionMap.find((e) => e.tick === cursor.tick) === undefined) {
                            sectionMap.push({ tick: cursor.tick, section: section });
                        }
                    }
                }

                cursor.next();
            }
        }
        sectionMap.sort((a, b) => a.tick - b.tick);
        return sectionMap;
    }

    function findSectionByTick(sectionMap, tick) {
        for (let i = sectionMap.length - 1; i >= 0; i--) {
            if (sectionMap[i].tick <= tick) {
                return sectionMap[i].section;
            }
        }
        return '';
    }

    function collectVoices() {
        sections = [];
        voices = [];
        voicesByName = new Map();

        for (let staffIndex = 0; staffIndex < curScore.nstaves; staffIndex++) {
            const sectionMap = buildSectionMap(staffIndex);

            for (let voiceIndex = 0; voiceIndex < 4; voiceIndex++) {
                const cursor = curScore.newCursor();
                cursor.rewind(Cursor.SCORE_START);
                cursor.staffIdx = staffIndex;
                cursor.voice = voiceIndex;

                while (cursor.segment) {
                    for (let i = 0; i < cursor.segment.annotations.length; i++) {
                        const element = cursor.segment.annotations[i];
                        if (element.type === Element.STAFF_TEXT 
                                && !existingLabelsIncludes(element)
                                && noteColors.includes(element.frameBgColor.toString())
                                && noteTextColors.includes(element.color.toString())) {
                            existingLabels.push(element);
                        }
                    }

                    const currentSection = findSectionByTick(sectionMap, cursor.tick);
                    if (!sections.includes(currentSection)) {
                        sections.push(currentSection);
                    }

                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        const name = cursor.element.staff.part.longName;
                        if (!voicesByName.has(name)) {
                            const newVoice = {
                                name: name,
                                num: 0,
                                active: true,
                                availableNotes: new Map(),
                                usedNotes: new Map()
                            };
                            voices.push(newVoice);
                            voicesByName.set(name, newVoice);
                        }
                        const voice = voicesByName.get(name);
                        collectChord(voice, cursor.element, currentSection);
                    }

                    cursor.next();
                }
            }
        }

        sections.sort();

        //displayMessageDlg(JSON.stringify({voices: voices, available: Array.from(voices[0].availableNotes.entries()), sectionChanges: sectionChanges, segments: segments }));
        return voices;
    }

    function selectVoice(voice) {
        for (let button of voiceSelectionButtons) {
            button.selected = (button.voice == voice);
            if (button.selected) {
                selectedVoice = button.voice;
            }
        }
        updateNoteButtons();
    }
    
    function toggleVoiceActive(voice) {
        voice.data = { 
            name: voice.data.name, 
            active: !voice.data.active,
            num: voice.data.num
        };
    }
    
    function updateVoiceNumbers() {
        let num = 1;
        for (let i = 0; i < voices.length; ++i) {
            if (voices[i].active) {
                voices[i].num = num;
                ++num;
            } else {
                voices[i].num = 0
            }
        }
        updateVoiceButtons();
    }
    
    function updateVoiceButtons() {
        for (let voice of voices) {
            voice.selectionButton.name = voice.name;
            voice.selectionButton.active = voice.active;
            voice.selectionButton.num = voice.num;
        }
    }
    
    function updateNoteButtons() {
        const availableNotes = selectedVoice.availableNotes.get(selectedSection);
        for (let button of noteButtons) {
            if (selectedVoice.active) {
                button.available = (button.noteNumber > -1) &&
                    availableNotes.includes(button.noteNumber)
            } else {
                button.available = false
            }

            const buttonPlayingVoices = [];
            for (let voice of voices) {
                const usedNotes = voice.usedNotes.get(selectedSection);
                if (!usedNotes) {
                    continue;
                }

                if (usedNotes.includes(button.noteNumber)) {
                    buttonPlayingVoices.push(voice.num);
                }
            }
            
            if (buttonPlayingVoices.length > 0) {
                if (buttonPlayingVoices.includes(selectedVoice.num)) {
                    button.playingVoice = selectedVoice.num;
                } else {
                    button.playingVoice = buttonPlayingVoices[0];
                }
                button.multipleVoices = (buttonPlayingVoices.length > 1);
            } else {
                button.playingVoice = 0;
                button.multipleVoices = false;
            }
        }
    }
    
    function createButtons() {
        let initialVoice = undefined;
        for (let voice of voices) {
            voice.selectionButton = voiceButton.createObject(voiceButtons, { voice });
            voiceSelectionButtons.push(voice.selectionButton);
            
            if (!initialVoice && voice.active) {
                initialVoice = voice;
            }
        }
        
        octaveLabel.createObject(
            notesGrid, { text: "Octave", width: octaveLabelWidth, height: noteLabelHeight }
        );
        for (let i = 0; i < noteNames.length; ++i) {
            noteLabel.createObject(
                notesGrid, { noteNumber: i }
            );
        }
        for (let i = 0; i < octaveNames.length; ++i) {
            octaveLabel.createObject(
                notesGrid, { text: octaveNames[i], width: octaveLabelWidth, height: noteButtonSize }
            );
            
            for (let j = 0; j < noteNames.length; ++j) {
                noteButtons.push(noteButton.createObject(
                    notesGrid, { noteNumber: noteNumber(i, j) }
                ));
            }
        }

        updateVoiceNumbers();
        selectVoice((typeof initialVoice !== "undefined") ? initialVoice : voices[0]);
    }
    
    function noteNumber(octave, note) {
        const n = (octaveNames.length - octave - 1) * 12 + note;
        if (n > maxNoteNumber) {
            return -1;
        }
        return n;
    }

    function applyChordColors(voice, section, chord) {
        const usedNotes = voice.usedNotes.get(section);
        for (let i = 0; i < chord.notes.length; i++) {
            const pitch = chord.notes[i].pitch;
            if (minPitch <= pitch && pitch <= maxPitch) {
                const noteNumber = pitch - minPitch;
                let color = emptyNoteColor;
                if (usedNotes.includes(noteNumber)) {
                    color = noteColors[pitch % 12];
                }

                chord.notes[i].color = color;
                if (chord.notes[i].accidental) {
                    chord.notes[i].accidental.color = color;
                }

                for (let j = 0; j < chord.notes[i].dots.length; j++) {
                    chord.notes[i].dots[j].color = color;
                }
            }
        }

        for (let i = 0; i < chord.graceNotes.length; i++) {
            applyChordColors(voice, section, chord.graceNotes[i]);
        }

    }

    function applyColors() {
        for (let staffIndex = 0; staffIndex < curScore.nstaves; staffIndex++) {
            const sectionMap = buildSectionMap(staffIndex);

            for (let voiceIndex = 0; voiceIndex < 4; voiceIndex++) {
                const cursor = curScore.newCursor();
                cursor.rewind(Cursor.SCORE_START);
                cursor.staffIdx = staffIndex;
                cursor.voice = voiceIndex;

                while (cursor.segment) {
                    const currentSection = findSectionByTick(sectionMap, cursor.tick);

                    if (cursor.element && cursor.element.type == Element.CHORD) {
                        const name = cursor.element.staff.part.longName;
                        const voice = voicesByName.get(name);

                        applyChordColors(voice, currentSection, cursor.element);
                    }

                    cursor.next();
                }
            }
        }
    }

    function removeExistingLabels() {
        for (let existingLabel of existingLabels) {
            removeElement(existingLabel);
        }
        existingLabels = [];
    }

    function noteNameOf(noteNumber) {
        const octave = octaveNames.length - Math.floor(noteNumber / 12) - 1;
        let octaveName = octaveNames[octaveNames.length - Math.floor(noteNumber / 12) - 1];
        if (octaveName === "-") {
            octaveName = "";
        }
        return noteNames[noteNumber % 12] + octaveName;
    }

    function addLabels() {
        let lastPartName = "";
        for (let staffIndex = 0; staffIndex < curScore.nstaves; ++staffIndex) {
            const partName = curScore.staves[staffIndex].part.longName;
            if (lastPartName === partName) {
                continue;
            }
            lastPartName = partName;

            const voice = voices.find(v => v.name === partName);
            if (!voice) {
                continue;
            }

            const cursor = curScore.newCursor();
            cursor.rewind(Cursor.SCORE_START);
            cursor.staffIdx = staffIndex;
            cursor.voice = 0;

            const usedNotes = [];
            for (let section of sections) {
                for (let sectionUsedNote of voice.usedNotes.get(section)) {
                    if (!usedNotes.includes(sectionUsedNote)) {
                        usedNotes.push(sectionUsedNote);
                    }
                }
            }

            let offset = 0;
            for (let noteNumber of usedNotes.sort(function (a, b) {  return a - b;  })) {
                const text = newElement(Element.STAFF_TEXT);
                text.text = noteNameOf(noteNumber);
                text.placement = Placement.ABOVE;
                text.autoplace = false;
                text.offsetX = -14 + offset;
                text.offsetY = -3.5;

                text.fontFace =  "FreeSerif";
                text.fontSize =  10;
                text.fontStyle =  1;

                text.color = noteTextColors[noteNumber % 12];

                text.frameType = 1;
                text.frameWidth = 0;
                text.framePadding = 1;
                text.frameRound = 20;
                text.frameBgColor = noteColors[noteNumber % 12];

    		    cursor.add(text);
                offset += text.bbox.width + 2 + 1;
            }
        }
    }

    function applyChanges() {
        curScore.startCmd();

        removeExistingLabels();
        applyColors();
        addLabels();
               
        curScore.endCmd()
    }

    Keys.onEscapePressed: { // Keypress
        (typeof(quit) === 'undefined' ? Qt.quit : quit)()
    }

    onRun: {
        if (typeof curScore === 'undefined') {
            displayMessageDlg("Exiting without processing - no current score!");
            (typeof(quit) === 'undefined' ? Qt.quit : quit)()
        }

        selectedSection = '';
        collectVoices();
        createButtons();

        sectionSpinner.haveSections = sections.length > 1;
        buttonsSpacer.haveSections = sections.length > 1;
    }

    MessageDialog {
        id: ctrlMessageDialog
        title: "Message"
        visible: false
        onAccepted: {
            visible = false;
        }
    }

    Column {
        x: margin
        y: margin

        spacing: dividerHeight
        
        Row {
            spacing: headerHeight / 2
            
            Rectangle {
                width: 2 * headerHeight
                height: headerHeight
                
                color: "transparent"
                
                Rectangle {
                    x: headerHeight * 0.0
                    width: headerHeight
                    height: headerHeight
                    radius: headerHeight / 2
                    color: noteColors[0]
                }
                Rectangle {
                    x: headerHeight * 0.5
                    width: headerHeight
                    height: headerHeight
                    radius: headerHeight / 2
                    color: noteColors[4]
                }
                Rectangle {
                    x: headerHeight * 1.0
                    width: headerHeight
                    height: headerHeight
                    radius: headerHeight / 2
                    color: noteColors[7]
                }
            }
            
            Text {
                y: -2
                color: "#ccc"
                height: headerHeight
                text: "Boomwhacker Colors"
                font.pixelSize: headerHeight
            }
        }
        
        Row {
            spacing: dividerWidth
            
            Column {
                id: voiceButtons
                spacing: 8
                
                Component {
                    id: voiceButton
                    
                    MouseArea { 
                        width: buttonWidth
                        height: buttonHeight
                        
                        hoverEnabled: true
            
                        property var voice
                        
                        property string name
                        property bool active
                        property int num: 0
                        
                        property bool selected: false
    
                        Rectangle {
                            anchors.fill: parent
        
                            color: parent.pressed 
                                    ? buttonPressedColor
                                    : parent.containsMouse  
                                        ? buttonHoverColor 
                                        : selected 
                                            ? buttonSelectedColor 
                                            : buttonColor
                            opacity: enabled ? 1 : 0.3
                            radius: 4
                        }
            
                        onPressed: {
                            selectVoice(voice);
                        }
                        
                        Rectangle {
                            id: indicator
    
                            color: (parent.active && parent.num > 0)
                                ? voiceColors[(parent.num - 1) % voiceColors.length] 
                                : "#444"
                            
                            border.width: parent.active && parent.selected ? 2 : 1
                            border.color: parent.active ? parent.selected ? "#fff" : "#ccc" : "#555"
                            
                            
                            width: parent.active && parent.selected ? 22 : 20
                            height: width
                            radius: width / 2
                            
                            x: parent.width - width - (parent.height - height) / 2 - 4
                            y: (parent.height - height) / 2
                            
                            MouseArea {
                                anchors.fill: parent
                                
                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter 
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 10
                                    text: parent.parent.parent.active 
                                        ? parent.parent.parent.num : "-"
                                    color: "#fff"
                                }
                                
                                onClicked: {
                                    voice.active = !voice.active;
                                    updateVoiceNumbers();
                                    updateNoteButtons();
                                }
                            }
                        }
                        
                        Text {
                            x: (parent.height - font.pixelSize) / 2
                            y: (parent.height - font.pixelSize) / 2
                            font.pixelSize: 12
                            text: parent.name
                            opacity: parent.selected ? 1.0 : 0.75
                            color: "#fff"
                        }
                    }
                }
            }
            
            Grid {
                id: notesGrid
                
                columns: 13
                spacing: gridSpacing
                
                Component {
                    id: noteLabel
                    
                    Rectangle {
                        width: noteButtonSize
                        height: noteLabelHeight
            
                        color: noteColors[noteNumber]
                        opacity: enabled ? 1 : 0.3
                        radius: 4
                        
                        //border.width: 1
                        //border.color: "#333"
                        
                        property int noteNumber
                        
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter 
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            text: noteNames[noteNumber]
                            color: noteTextColors[noteNumber]
                        }
                    }
                }
                
                Component {
                    id: octaveLabel
    
                    Rectangle {
                        color: buttonColor
                        opacity: enabled ? 1 : 0.3
                        radius: 4
                        
                        property string text
                        
                        Text {
                            anchors.fill: parent
                            horizontalAlignment: Text.AlignHCenter 
                            verticalAlignment: Text.AlignVCenter
                            font.pixelSize: 12
                            text: parent.text
                            color: "#fff"
                        }
                    }
                }
                
                Component {
                    id: noteButton
    
                    MouseArea {
                        property int noteNumber
                        property bool available
                        property int playingVoice
                        property bool multipleVoices
                        property double multipleOffset: 1
                        
                        width: noteButtonSize
                        height: noteButtonSize
                        hoverEnabled: true
                        
                        onClicked: {
                            const usedNotes = selectedVoice.usedNotes.get(selectedSection);
                            const noteIndex = usedNotes.indexOf(noteNumber);
                            if (noteIndex > -1) {
                                usedNotes.splice(noteIndex, 1);
                            } else {
                                usedNotes.push(noteNumber);
                            }
                            updateNoteButtons();
                        }

                        Rectangle {
                            property int noteNumber: parent.noteNumber
                            property bool available: parent.available
                            property int playingVoice: parent.playingVoice
                            property bool multipleVoices: parent.multipleVoices
                            property double multipleOffset: parent.multipleOffset
                        
                            anchors.fill: parent
                
                            color: (noteNumber > -1 && available) 
                                ? parent.containsMouse ? buttonHoverColor : buttonColor 
                                : "#222"
                            opacity: enabled ? 1 : 0.3
                            radius: 4
                            
                            Rectangle {
                                width: 24
                                height: width
                                radius: width / 2
                                x: (parent.width - width) / 2 + (parent.multipleVoices ? parent.multipleOffset : 0)
                                y: (parent.height - height) / 2 + (parent.multipleVoices ? parent.multipleOffset : 0)
                                
                                border.width: parent.multipleVoices ? 1 : 0
                                border.color: "#ccc"

                                color: parent.multipleVoices ? "#666" : "transparent"
                            }
                            
                            Rectangle {
                                width: 24
                                height: width
                                radius: width / 2
                                x: (parent.width - width) / 2 - (parent.multipleVoices ? parent.multipleOffset : 0)
                                y: (parent.height - height) / 2 - (parent.multipleVoices ? parent.multipleOffset : 0)
                                
                                color: parent.playingVoice > 0 ? voiceColors[playingVoice - 1] : "transparent"
                                border.width: parent.playingVoice > 0 ? 1 : 0
                                border.color: "#fff"
                                
                                Text {
                                    anchors.fill: parent
                                    horizontalAlignment: Text.AlignHCenter 
                                    verticalAlignment: Text.AlignVCenter
                                    font.pixelSize: 12
                                    text: parent.parent.playingVoice > 0 ? parent.parent.playingVoice : ""
                                    color: "#fff"
                                }
                            }
                            
                            // Text {
                            //     x: 2
                            //     y: 2
                            //     horizontalAlignment: Text.AlignHCenter 
                            //     verticalAlignment: Text.AlignVCenter
                            //     font.pixelSize: 8
                            //     text: parent.noteNumber > -1 ? parent.noteNumber : ""
                            //     color: "#fff"
                            // }
                        }
                    }
                }
            }
        }

        Row {
            property int buttonGap: 8
            x: buttonWidth + dividerWidth 
            spacing: buttonGap

            Row {
                id: sectionSpinner

                property bool haveSections: false
                property int spinWidth: 30
                property int spinGap: 3
                spacing: spinGap
                visible: haveSections
                
                MouseArea {
                    width: parent.spinWidth
                    height: buttonHeight

                    hoverEnabled: true
                    
                    onClicked: {
                        let i = sections.indexOf(selectedSection);
                        if (i - 1 < 0) {
                            i = sections.length - 1;
                        } else {
                            i--;
                        }
                        selectedSection = sections[i];
                        updateNoteButtons();
                      
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: parent.containsMouse ? buttonHoverColor : buttonColor
                        radius: 4
                        
                        Text {
                            anchors.fill: parent
                            height: buttonHeight
                            font.pixelSize: 12
                            text: "←"
                            color: "#fff"
                            horizontalAlignment: Text.AlignHCenter 
                            verticalAlignment: Text.AlignVCenter
                        }
                    }
                }

                Rectangle {
                    width: buttonWidth - 2*parent.spinWidth - 2*parent.spinGap
                    height: buttonHeight
        
                    color: "#222"
                    radius: 4
                    

                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter 
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        text: (!selectedSection) ? 'Standard' : selectedSection
                        color: "#fff"
                    }
                }
                
                MouseArea {
                    width: parent.spinWidth
                    height: buttonHeight

                    hoverEnabled: true
                    
                    onClicked: {
                        let i = sections.indexOf(selectedSection);
                        if (i + 1 >= sections.length) {
                            i = 0;
                        } else {
                            i++;
                        }
                        selectedSection = sections[i];
                        updateNoteButtons();
                    }
                    
                    Rectangle {
                        anchors.fill: parent
                        color: parent.containsMouse ? buttonHoverColor : buttonColor
                        radius: 4
                        
                        Text {
                            anchors.fill: parent
                            height: buttonHeight
                            text: "→"
                            color: "#fff"
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter 
                            verticalAlignment: Text.AlignVCenter
                        }
                        
                    }
                }
            }
            
            Rectangle {
                id: buttonsSpacer

                property bool haveSections: false

                width: octaveLabelWidth + 12 * (gridSpacing + noteButtonSize) - (haveSections ? 3 : 2) * (buttonWidth + parent.buttonGap)
                height: buttonHeight
                color: "transparent"
            }
            
            MouseArea {
                width: buttonWidth
                height: buttonHeight
                
                hoverEnabled: true
                
                onClicked: {
                   applyChanges();
                   (typeof(quit) === 'undefined' ? Qt.quit : quit)();
                }
    
                Rectangle {
                    anchors.fill: parent
        
                    color: parent.containsMouse ? buttonHoverColor : buttonColor
                    radius: 4
                    
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter 
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        text: "OK"
                        color: "#fff"
                    }
                }
            }
            
            MouseArea {
                width: buttonWidth
                height: buttonHeight
                
                hoverEnabled: true
                
                onClicked: {
                   (typeof(quit) === 'undefined' ? Qt.quit : quit)();
                }
    
                Rectangle {
                    anchors.fill: parent
        
                    color: parent.containsMouse ? buttonHoverColor : buttonColor
                    radius: 4
                    
                    Text {
                        anchors.fill: parent
                        horizontalAlignment: Text.AlignHCenter 
                        verticalAlignment: Text.AlignVCenter
                        font.pixelSize: 12
                        text: "Cancel"
                        color: "#fff"
                    }
                }
            }
        }
    }
}
