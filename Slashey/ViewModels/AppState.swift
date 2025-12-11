//
//  AppState.swift
//  Slashey
//

import SwiftUI

@Observable
final class AppState {
    var toast: Toast?
    var isLoading = false
    var loadingMessage: String?

    // Alert state
    var showAlert = false
    var alertTitle = ""
    var alertMessage = ""

    // Confirmation dialog state
    var showConfirmation = false
    var confirmationTitle = ""
    var confirmationMessage = ""
    var confirmationAction: (() -> Void)?

    func showSuccess(_ message: String) {
        withAnimation {
            toast = Toast(message: message, type: .success)
        }
    }

    func showError(_ message: String) {
        withAnimation {
            toast = Toast(message: message, type: .error)
        }
    }

    func showWarning(_ message: String) {
        withAnimation {
            toast = Toast(message: message, type: .warning)
        }
    }

    func showInfo(_ message: String) {
        withAnimation {
            toast = Toast(message: message, type: .info)
        }
    }

    func showErrorAlert(title: String, message: String) {
        alertTitle = title
        alertMessage = message
        showAlert = true
    }

    func requestConfirmation(
        title: String,
        message: String,
        action: @escaping () -> Void
    ) {
        confirmationTitle = title
        confirmationMessage = message
        confirmationAction = action
        showConfirmation = true
    }

    func startLoading(_ message: String? = nil) {
        loadingMessage = message
        isLoading = true
    }

    func stopLoading() {
        isLoading = false
        loadingMessage = nil
    }
}
