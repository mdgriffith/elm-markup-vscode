'use strict';
import * as vscode from 'vscode';
import * as diagnostics from './diagnostics'
import * as panel from './panel'

export function activate(context: vscode.ExtensionContext) {
    diagnostics.activate(context)
    // panel.activate(context)
}
