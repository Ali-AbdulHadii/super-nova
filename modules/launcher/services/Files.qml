pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Caelestia.Config
import qs.utils

// The launcher's ">file" mode: searches file and folder names under the home folder
// with fd. One fd process runs at a time; a newer query kills the older one, and
// results from a superseded query are dropped.
Singleton {
    id: root

    // Set by AppList while the launcher is in file mode
    property string queryText
    property list<var> results: []
    property bool busy

    property int generation
    property Process current: null

    readonly property int maxResults: Math.max(5, Math.min(200, GlobalConfig.launcher.fileSearch.maxResults))

    // Words match in order with anything between, so "tax 2025" finds tax_return_2025.pdf.
    // Regex characters in the query are escaped; fd gets the pattern after "--", so a
    // query can never become an fd option.
    function patternFor(query: string): string {
        return query.trim().split(/\s+/).map(w => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*");
    }

    function search(): void {
        const query = queryText.trim();
        generation++;

        // Stopping and destroying the previous fd kills it; its late output is ignored
        if (current) {
            current.running = false;
            current.destroy();
            current = null;
        }

        if (query.length < 2) {
            results = [];
            busy = false;
            return;
        }

        const args = ["fd", "--color", "never", "--absolute-path", "--one-file-system", "--type", "f", "--type", "d", "--max-results", String(maxResults * 3), "--exclude", "node_modules", "--exclude", "steamapps", "--exclude", "__pycache__"];
        if (GlobalConfig.launcher.fileSearch.showHidden)
            args.push("--hidden", "--exclude", ".git", "--exclude", ".cache");
        args.push("--", patternFor(query), Paths.home);

        busy = true;
        current = fdComp.createObject(root, {
            command: args,
            gen: generation,
            query: query
        });
        current.running = true;
    }

    // Best matches first: exact name, then name prefix, then name substring, then
    // anything that only matched across the path; shallower and shorter names win ties
    function rank(lines: list<string>, query: string): list<var> {
        const q = query.toLowerCase();
        const items = [];
        for (const line of lines) {
            if (!line)
                continue;
            const isDir = line.endsWith("/");
            const path = isDir ? line.slice(0, -1) : line;
            const slash = path.lastIndexOf("/");
            const name = path.slice(slash + 1);
            const lower = name.toLowerCase();
            const score = lower === q ? 0 : lower.startsWith(q) ? 1 : lower.includes(q) ? 2 : 3;
            items.push({
                path,
                name,
                parentDir: path.slice(0, Math.max(slash, 0)) || "/",
                isDir,
                score,
                depth: path.split("/").length,
                onClicked: list => root.open(list, path)
            });
        }
        items.sort((a, b) => a.score - b.score || a.depth - b.depth || a.name.length - b.name.length);
        return items.slice(0, maxResults);
    }

    function open(list: var, path: string): void {
        list.screenState.launcher = false;
        Quickshell.execDetached(AppScope.wrap(["xdg-open", path]));
    }

    // Shows the item in its folder: Nautilus selects it, anything else opens the folder.
    // The path is a positional argument, never part of the script text.
    function reveal(list: var, path: string): void {
        if (!path)
            return;
        list.screenState.launcher = false;
        Quickshell.execDetached(AppScope.wrap(["sh", "-c", "if command -v nautilus >/dev/null; then exec nautilus --select \"$1\"; else exec xdg-open \"$(dirname \"$1\")\"; fi", "sh", path]));
    }

    onQueryTextChanged: debounce.restart()

    Timer {
        id: debounce

        interval: 150
        onTriggered: root.search()
    }

    Component {
        id: fdComp

        Process {
            id: proc

            property int gen
            property string query

            stdout: StdioCollector {
                onStreamFinished: {
                    if (proc.gen !== root.generation)
                        return;
                    root.results = root.rank(text.split("\n"), proc.query);
                    root.busy = false;
                }
            }

            onRunningChanged: {
                if (!running && proc.gen === root.generation)
                    root.busy = false;
            }
        }
    }
}
