import QtQuick
import Quickshell.Io

// JSON soubor se stavem panelu, sledovaný kvůli změnám zvenčí. Chybějící soubor není chyba, poškozený se ohlásí.
FileView {
    id: root

    // Poškozený soubor: vlastník ho nemá přepisovat, jinak by zmizelo, co se ještě dá opravit ručně
    property bool invalid: false

    // Hodnota je ve vlastnosti, ne v parametru signálu: ten by z pole udělal typ, na kterém Array.isArray vrací false
    property var value

    signal valueLoaded

    function save(newValue: var): void {
        if (!invalid)
            setText(JSON.stringify(newValue));
    }

    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
        try {
            root.value = JSON.parse(text());
            root.invalid = false;
            root.valueLoaded();
        } catch (error) {
            root.invalid = true;
            console.warn(`desk: invalid file ${root.path}:`, error);
        }
    }
}
