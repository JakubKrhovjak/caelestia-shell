import QtQuick
import Quickshell.Io

// JSON soubor se stavem panelu, sledovaný kvůli změnám zvenčí. Chybějící soubor není chyba, poškozený se ohlásí.
FileView {
    id: root

    // Poškozený soubor: vlastník ho nemá přepisovat, jinak by zmizelo, co se ještě dá opravit ručně
    property bool invalid: false

    signal valueLoaded(value: var)

    function save(value: var): void {
        setText(JSON.stringify(value));
    }

    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
        try {
            const value = JSON.parse(text());
            root.invalid = false;
            root.valueLoaded(value);
        } catch (error) {
            root.invalid = true;
            console.warn(`desk: invalid file ${root.path}:`, error);
        }
    }
}
