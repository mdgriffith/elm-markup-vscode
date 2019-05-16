'use strict';
import * as vscode from 'vscode';
import * as path from 'path';
import * as compile from './compile';



export function activate(context: vscode.ExtensionContext) {
    const collection = vscode.languages.createDiagnosticCollection('elm-markup');
    if (vscode.window.activeTextEditor) {
        update(vscode.window.activeTextEditor.document, collection);
    }
    context.subscriptions.push(vscode.window.onDidChangeActiveTextEditor(editor => {
        if (editor) {
            update(editor.document, collection);
        }
    }));

    vscode.workspace.onDidSaveTextDocument(doc => {
        if (doc) {
            update(doc, collection);
        }
    })
}

function update(document: vscode.TextDocument, collection: vscode.DiagnosticCollection): void {

    if (document && !document.uri.path.includes("elm-stuff") && (document.uri.fsPath.endsWith('.emu') || document.uri.fsPath.endsWith('.elm'))) {
        compile.compile(document.uri.fsPath)
            .then(json => {
                collection.clear();
                const diagnostics = errorsToDiagnostics(json.errors)

                Object.keys(diagnostics).forEach((key) => {
                    collection.set(vscode.Uri.file(key), diagnostics[key])
                })
            }).catch(err => {
                console.error(err);
                collection.clear();
            })
    } else {
        collection.clear();
    }
}


function errorsToDiagnostics(errors): any {
    var diagnostics = {}
    errors.forEach((err) => {
        console.log(err)
        diagnostics[err.sourcePath] = err.problems.map((prob) => problemToDiag(prob, err.parser))
    })
    return diagnostics;
}
function problemToDiag(prob, parser) {
    return {
        code: '',
        message: prob.title + ' (parsed with ' + parser + ')' + '\n' + prob.message.map((msg) => msg.text).join('') + '\n',
        range: regionToRange(prob.range),
        severity: vscode.DiagnosticSeverity.Error,
        source: '',
        relatedInformation: []
    }
}

function regionToRange(region) {
    if (region) {
        return new vscode.Range(new vscode.Position(region.start.line, region.start.character), new vscode.Position(region.end.line, region.end.character))
    } else {
        return new vscode.Range(new vscode.Position(0, 0), new vscode.Position(1, 0))
    }
}