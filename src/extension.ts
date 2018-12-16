import * as path from 'path';
import * as vscode from 'vscode';


export function activate(context: vscode.ExtensionContext) {

    context.subscriptions.push(vscode.commands.registerCommand('emu.liveErrorView', () => {
        MarkupPanel.createOrShow(context.extensionPath);
    }));

    context.subscriptions.push(vscode.commands.registerCommand('catCoding.doRefactor', () => {
        if (MarkupPanel.currentPanel) {
            MarkupPanel.currentPanel.doRefactor();
        }
    }));

    if (vscode.window.registerWebviewPanelSerializer) {
        // Make sure we register a serilizer in activation event
        vscode.window.registerWebviewPanelSerializer(MarkupPanel.viewType, {
            async deserializeWebviewPanel(webviewPanel: vscode.WebviewPanel, state: any) {
                console.log(`Got state: ${state}`);
                MarkupPanel.revive(webviewPanel, context.extensionPath);
            }
        });
    }
}

function prepareRanges(ranges) {
    const rangeLength = ranges.length;

    var prepared = [];
    for (var i = 0; i < rangeLength; i++) {
        const start = {
            character: ranges[i].start.character,
            line: ranges[i].start.line
        }
        const end = {
            character: ranges[i].end.character,
            line: ranges[i].end.line
        }
        prepared.push({ start: start, end: end });
    }
    return prepared
}

/**
 * Manages cat coding webview panels
 */
class MarkupPanel {
    /**
     * Track the currently panel. Only allow a single panel to exist at a time.
     */
    public static currentPanel: MarkupPanel | undefined;

    public static readonly viewType = 'catCoding';

    private readonly _panel: vscode.WebviewPanel;
    private readonly _extensionPath: string;
    private _disposables: vscode.Disposable[] = [];

    public static createOrShow(extensionPath: string) {

        // If we already have a panel, show it.
        if (MarkupPanel.currentPanel) {
            MarkupPanel.currentPanel._panel.reveal(vscode.ViewColumn.Two);
            return;
        }

        // Otherwise, create a new panel.
        const panel = vscode.window.createWebviewPanel(MarkupPanel.viewType, "Live Elm Markup",
            vscode.ViewColumn.Two, {
                // Enable javascript in the webview
                enableScripts: true,

                // And restric the webview to only loading content from our extension's `media` directory.
                localResourceRoots: [
                    vscode.Uri.file(path.join(extensionPath, 'media'))
                ]
            });

        vscode.window.onDidChangeActiveTextEditor(editor => {
            if (editor) {
                MarkupPanel.currentPanel.doChangeEditor({
                    command: "RefreshEditor",
                    fileName: editor.document.fileName,
                    ranges: prepareRanges(editor.visibleRanges),
                    selections: editor.selections,
                });
            }
        });

        vscode.window.onDidChangeTextEditorVisibleRanges(visibleRanges => {
            if (visibleRanges) {

                MarkupPanel.currentPanel.doChangeEditor({
                    command: "ViewRange",
                    fileName: visibleRanges.textEditor.document.fileName,
                    ranges: prepareRanges(visibleRanges.visibleRanges)
                });
            }
        });

        vscode.window.onDidChangeTextEditorSelection(editor => {
            if (editor) {


                MarkupPanel.currentPanel.doChangeEditor({
                    command: "EditorSelection",
                    fileName: editor.textEditor.document.fileName,
                    selections: editor.selections
                });
            }
        });

        MarkupPanel.currentPanel = new MarkupPanel(panel, extensionPath);

        if (vscode.window.activeTextEditor) {
            MarkupPanel.currentPanel.doChangeEditor({
                command: "RefreshEditor",
                fileName: vscode.window.activeTextEditor.document.fileName,
                ranges: prepareRanges(vscode.window.activeTextEditor.visibleRanges),
                selections: vscode.window.activeTextEditor.selections,
            });
        }
    }

    public static revive(panel: vscode.WebviewPanel, extensionPath: string) {
        MarkupPanel.currentPanel = new MarkupPanel(panel, extensionPath);
    }

    private constructor(
        panel: vscode.WebviewPanel,
        extensionPath: string
    ) {
        this._panel = panel;
        this._extensionPath = extensionPath;

        // Set the webview's initial html content 
        this._update();

        // Listen for when the panel is disposed
        // This happens when the user closes the panel or when the panel is closed programatically
        this._panel.onDidDispose(() => this.dispose(), null, this._disposables);

        // Update the content based on view changes
        this._panel.onDidChangeViewState(e => {
            if (this._panel.visible) {
                this._update()
            }
        }, null, this._disposables);

        // Handle messages from the webview
        this._panel.webview.onDidReceiveMessage(message => {
            switch (message.command) {
                case 'alert':
                    vscode.window.showErrorMessage(message.text);
                    return;
            }
        }, null, this._disposables);
    }

    public doRefactor() {
        // Send a message to the webview webview.
        // You can send any JSON serializable data.
        this._panel.webview.postMessage({ command: 'refactor' });
    }


    public doChangeEditor(event) {

        this._panel.webview.postMessage(event);
    }


    public dispose() {
        MarkupPanel.currentPanel = undefined;

        // Clean up our resources
        this._panel.dispose();

        while (this._disposables.length) {
            const x = this._disposables.pop();
            if (x) {
                x.dispose();
            }
        }
    }

    private _update() {


        this._panel.webview.html = this._getHtmlForWebview();
        // const z = 1 + 2;
        // // Vary the webview's content based on where it is located in the editor.
        // switch (this._panel.viewColumn) {
        //     case vscode.ViewColumn.Two:
        //         this._updateForMarkup('Compiling Markup');
        //         return;

        //     case vscode.ViewColumn.Three:
        //         this._updateForMarkup('Testing Markup');
        //         return;

        //     case vscode.ViewColumn.One:
        //     default:
        //         this._updateForMarkup('Coding Markup');
        //         return;
        // }
    }

    // private _updateForMarkup(catName: keyof typeof cats) {
    //     this._panel.title = catName;
    //     this._panel.webview.html = this._getHtmlForWebview(cats[catName]);
    // }

    private _getHtmlForWebview() {

        // Local path to main script run in the webview
        const scriptPathOnDisk = vscode.Uri.file(path.join(this._extensionPath, 'media', 'main.js'));

        // And the uri we use to load this script in the webview
        const scriptUri = scriptPathOnDisk.with({ scheme: 'vscode-resource' });

        // Use a nonce to whitelist which scripts can be run
        const nonce = getNonce();

        return `<!DOCTYPE html>
            <html lang="en">
            <head>
                <meta charset="UTF-8">

                <!--
                Use a content security policy to only allow loading images from https or from our extension directory,
                and only allow scripts that have a specific nonce.
                -->
                <meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src vscode-resource: https:; script-src 'nonce-${nonce}';">

                <meta name="viewport" content="width=device-width, initial-scale=1.0">
                <script nonce="${nonce}" src="${scriptUri}"></script>
                <title>Elm Markup Live View</title>
            </head>
            <body>
                <script nonce="${nonce}">
                    var app = Elm.Main.init();
                    const vscode = acquireVsCodeApi();

                    // const oldState = vscode.getState();
                
                    // Handle messages sent from the extension to the webview
                    window.addEventListener('message', event => {
                        const message = event.data; // The json data that the extension sent
                        app.ports.editorChange.send(message);
                    });
                    
                    app.ports.notify.subscribe(function(message) {
                        vscode.postMessage(message);
                    });

                </script>
            </body>
            </html>`;
    }
}

function getNonce() {
    let text = "";
    const possible = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    for (let i = 0; i < 32; i++) {
        text += possible.charAt(Math.floor(Math.random() * possible.length));
    }
    return text;
}