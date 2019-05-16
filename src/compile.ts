import * as path from 'path';
import * as vscode from 'vscode';
import * as script from './script';
import * as which from 'which';
import * as glob from "glob";


export function compile(source) {

    let elmMarkupExe = which.sync("elm-markup");
    const folders = vscode.workspace.workspaceFolders;

    if (folders.length > 0) {
        // We find the parent folder that contains an `elm.json` nearest to the changed file.
        const projectRoot = folders[0].uri.path;
        let largestBase = "";
        let files = glob.sync("**/elm.json", { cwd: projectRoot })
        const fileLen = files.length;
        for (let i = 0; i < fileLen; i++) {
            var dir = path.join(projectRoot, path.dirname(files[i]));
            if (source.startsWith(dir)) {
                if (dir.length > largestBase.length) {
                    largestBase = dir
                }
            }
        }
        return script.executeExpectJson(elmMarkupExe, ["--report=json"], {
            cwd: largestBase,
            env: process.env
        })

    }
}

