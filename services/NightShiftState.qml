pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Night Shift pro prostředí desk: stav a plán. Barvy mění hyprsunset, spouští ho ~/.config/desk/nightshift.sh.
// Caelestia ho nepoužívá, singleton se vytvoří až při prvním použití.
Singleton {
    id: root

    readonly property int warmest: 1000
    readonly property int coolest: 6000

    property bool active: false
    property int temperature: 4000
    property bool scheduleEnabled: false
    property string scheduleFrom: "21:00"
    property string scheduleTo: "07:00"
    property string scheduleMode: "sun" // "sun" = od západu do východu slunce, "custom" = vlastní čas

    // Souřadnice pásma z databáze časových zón a dnešní časy slunce v minutách od půlnoci; -1 = neznámé
    property string timezone: ""
    property var coordinates: null
    property int sunrise: -1
    property int sunset: -1
    readonly property bool sunKnown: sunrise >= 0 && sunset >= 0

    // Stav plánu při poslední kontrole: ruční přepnutí platí do další hranice plánu, jako v macOS
    property var lastInSchedule: null

    function apply(): void {
        Quickshell.execDetached(active ? ["hyprctl", "hyprsunset", "temperature", String(temperature)] : ["hyprctl", "hyprsunset", "identity"]);
        save();
    }

    function save(): void {
        store.setText(JSON.stringify({ enabled: active, temperature, scheduleEnabled, scheduleMode, scheduleFrom, scheduleTo }));
    }

    function setActive(value: bool): void {
        active = value;
        apply();
    }

    function setTemperature(value: int): void {
        temperature = Math.round(value / 50) * 50;
        applyLater.restart();
    }

    function setScheduleEnabled(value: bool): void {
        scheduleEnabled = value;
        lastInSchedule = null;
        save();
        checkSchedule();
    }

    function setScheduleTime(from: string, to: string): void {
        scheduleFrom = from;
        scheduleTo = to;
        lastInSchedule = null;
        save();
        checkSchedule();
    }

    function setScheduleMode(mode: string): void {
        scheduleMode = mode;
        lastInSchedule = null;
        save();
        checkSchedule();
    }

    function formatMinutes(value: int): string {
        return value < 0 ? "--:--" : `${String(Math.floor(value / 60)).padStart(2, "0")}:${String(value % 60).padStart(2, "0")}`;
    }

    // Řádek z zone.tab obsahuje souřadnice ve tvaru +5005+01426 (stupně a minuty, případně i vteřiny)
    function parseCoordinates(text: string): var {
        const match = text.match(/^([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?$/);
        const degrees = (sign, deg, min, sec) => (sign === "-" ? -1 : 1) * (Number(deg) + Number(min) / 60 + Number(sec ?? 0) / 3600);
        return match ? { latitude: degrees(match[1], match[2], match[3], match[4]), longitude: degrees(match[5], match[6], match[7], match[8]) } : null;
    }

    function loadCoordinates(zoneTab: string): void {
        const row = zoneTab.split("\n").map(line => line.split("\t")).find(columns => columns[2] === timezone);
        coordinates = row ? parseCoordinates(row[1]) : null;
        updateSun();
        checkSchedule();
    }

    // Čas východu nebo západu slunce v minutách místního času (algoritmus z Almanac for Computers, zenit 90,833°)
    function sunMinutes(date: var, latitude: real, longitude: real, rising: bool): int {
        const rad = Math.PI / 180;
        const normalize = (value, range) => ((value % range) + range) % range;
        const dayOfYear = Math.floor((new Date(date.getFullYear(), date.getMonth(), date.getDate()) - new Date(date.getFullYear(), 0, 0)) / 86400000);
        const lngHour = longitude / 15;
        const t = dayOfYear + ((rising ? 6 : 18) - lngHour) / 24;
        const anomaly = 0.9856 * t - 3.289;
        const trueLong = normalize(anomaly + 1.916 * Math.sin(anomaly * rad) + 0.020 * Math.sin(2 * anomaly * rad) + 282.634, 360);
        const rawAscension = normalize(Math.atan(0.91764 * Math.tan(trueLong * rad)) / rad, 360);
        const ascension = (rawAscension + Math.floor(trueLong / 90) * 90 - Math.floor(rawAscension / 90) * 90) / 15;
        const sinDec = 0.39782 * Math.sin(trueLong * rad);
        const cosDec = Math.cos(Math.asin(sinDec));
        const cosHour = (Math.cos(90.833 * rad) - sinDec * Math.sin(latitude * rad)) / (cosDec * Math.cos(latitude * rad));
        if (cosHour > 1 || cosHour < -1)
            return -1; // Polární den nebo noc: slunce ten den nevychází nebo nezapadá
        const hourAngle = (rising ? 360 - Math.acos(cosHour) / rad : Math.acos(cosHour) / rad) / 15;
        const utc = normalize(hourAngle + ascension - 0.06571 * t - 6.622 - lngHour, 24);
        return Math.round(normalize(utc * 60 - date.getTimezoneOffset(), 1440));
    }

    function updateSun(): void {
        const now = new Date();
        sunrise = coordinates ? sunMinutes(now, coordinates.latitude, coordinates.longitude, true) : -1;
        sunset = coordinates ? sunMinutes(now, coordinates.latitude, coordinates.longitude, false) : -1;
    }

    function isValidTime(text: string): bool {
        return /^([01]?\d|2[0-3]):[0-5]\d$/.test(text);
    }

    function minutes(text: string): int {
        const parts = text.split(":").map(Number);
        return parts[0] * 60 + parts[1];
    }

    // Plán může přecházet přes půlnoc, třeba 21:00–07:00
    function inSchedule(): bool {
        const now = new Date();
        const current = now.getHours() * 60 + now.getMinutes();
        const useSun = scheduleMode === "sun" && sunKnown;
        const from = useSun ? sunset : minutes(scheduleFrom);
        const to = useSun ? sunrise : minutes(scheduleTo);
        return from <= to ? current >= from && current < to : current >= from || current < to;
    }

    function checkSchedule(): void {
        updateSun();
        if (!scheduleEnabled)
            return;
        const inside = inSchedule();
        if (inside !== lastInSchedule) {
            lastInSchedule = inside;
            if (active !== inside)
                setActive(inside);
        }
    }

    function load(content: string): void {
        try {
            const saved = JSON.parse(content);
            active = saved.enabled === true;
            temperature = Math.max(warmest, Math.min(coolest, saved.temperature ?? temperature));
            scheduleEnabled = saved.scheduleEnabled === true;
            scheduleFrom = isValidTime(saved.scheduleFrom ?? "") ? saved.scheduleFrom : scheduleFrom;
            scheduleTo = isValidTime(saved.scheduleTo ?? "") ? saved.scheduleTo : scheduleTo;
            // Starší soubor bez režimu a se zapnutým plánem znamená vlastní čas, ten se nesmí přepsat
            scheduleMode = saved.scheduleMode ?? (scheduleEnabled ? "custom" : "sun");
        } catch (error) {
            console.warn("desk: invalid night shift file:", error);
        }
    }

    FileView {
        id: store

        path: `${ShellEnv.deskDir}/nightshift.json`
        printErrors: false
        onLoaded: root.load(text())
    }

    Process {
        running: true
        command: ["timedatectl", "show", "-p", "Timezone", "--value"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.timezone = text.trim();
                zoneTab.reload();
            }
        }
    }

    FileView {
        id: zoneTab

        path: root.timezone ? "/usr/share/zoneinfo/zone.tab" : ""
        printErrors: false
        onLoaded: root.loadCoordinates(text())
    }

    // Tažení posuvníku posílá hodně změn, hyprsunset dostane jen tu poslední
    Timer {
        id: applyLater

        interval: 80
        onTriggered: root.apply()
    }

    // Plán se kontroluje průběžně; první kontrola až po chvíli, až po načtení souboru a startu hyprsunset
    Timer {
        interval: 20000
        running: true
        repeat: true
        onTriggered: root.checkSchedule()
    }
}
