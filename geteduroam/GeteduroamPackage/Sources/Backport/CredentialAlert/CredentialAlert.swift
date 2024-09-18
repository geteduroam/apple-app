// Based on https://stackoverflow.com/a/61902990/60488
#if os(iOS)
import SwiftUI

public struct CredentialAlert {
    public init(title: String, isPresented: Binding<Bool>, usernamePrompt: String, username: Binding<String>, onUsernameSubmit: @escaping () -> (), passwordPrompt: String, password: Binding<String>, cancelButtonTitle: String, cancelAction: @escaping () -> (), doneButtonTitle: String, doneAction: @escaping () -> (), message: String) {
        self.title = title
        self.isPresented = isPresented
        self.usernamePrompt = usernamePrompt
        self.username = username
        self.onUsernameSubmit = onUsernameSubmit
        self.passwordPrompt = passwordPrompt
        self.password = password
        self.cancelButtonTitle = cancelButtonTitle
        self.cancelAction = cancelAction
        self.doneButtonTitle = doneButtonTitle
        self.doneAction = doneAction
        self.message = message
    }
    
    public init(title: String, isPresented: Binding<Bool>, passwordPrompt: String, password: Binding<String>, cancelButtonTitle: String, cancelAction: @escaping () -> (), doneButtonTitle: String, doneAction: @escaping () -> (), message: String) {
        self.title = title
        self.isPresented = isPresented
        self.usernamePrompt = nil
        self.username = nil
        self.onUsernameSubmit = nil
        self.passwordPrompt = passwordPrompt
        self.password = password
        self.cancelButtonTitle = cancelButtonTitle
        self.cancelAction = cancelAction
        self.doneButtonTitle = doneButtonTitle
        self.doneAction = doneAction
        self.message = message
    }
    
    let title: String
    let isPresented: Binding<Bool>
    let usernamePrompt: String?
    let username: Binding<String>?
    let onUsernameSubmit: (() -> ())?
    let passwordPrompt: String
    let password: Binding<String>
    let cancelButtonTitle: String
    let cancelAction: () -> ()
    let doneButtonTitle: String
    let doneAction: () -> ()
    let message: String
}

extension CredentialAlert: UIViewControllerRepresentable {
    
    public typealias UIViewControllerType = CredentialAlertViewController
    
    public func makeUIViewController(context: UIViewControllerRepresentableContext<CredentialAlert>) -> UIViewControllerType {
        CredentialAlertViewController(alert: self)
    }
    
    public func updateUIViewController(_ uiViewController: UIViewControllerType,
                                       context: UIViewControllerRepresentableContext<CredentialAlert>) {
        // no update needed
    }
}

struct CredentialAlertWrapper<PresentingView: View>: View {
    
    @Binding var isPresented: Bool
    let presentingView: PresentingView
    let content: () -> CredentialAlert
    
    var body: some View {
        ZStack {
            if (isPresented) { content() }
            presentingView
        }
    }
}

public extension View {
    func credentialAlert(isPresented: Binding<Bool>,
                         content: @escaping () -> CredentialAlert) -> some View {
        CredentialAlertWrapper(isPresented: isPresented,
                               presentingView: self,
                               content: content)
    }
}

public extension Backport where Content: View {
    @MainActor @ViewBuilder
    func credentialAlert(_ alert: CredentialAlert) -> some View {
        if #available(iOS 16, tvOS 16.0, watchOS 9.0, macOS 12.0, *) {
            content.alert(
                alert.title,
                isPresented: alert.isPresented,
                actions: {
                    if let usernamePrompt = alert.usernamePrompt, let username = alert.username, let onUsernameSubmit = alert.onUsernameSubmit {
                        TextField(usernamePrompt, text: username)
                            .textContentType(.username)
                            .autocorrectionDisabled(true)
                            .textInputAutocapitalization(.never)
                            .flipsForRightToLeftLayoutDirection(false)
                            .onSubmit(onUsernameSubmit)
                    }
                    SecureField(alert.passwordPrompt, text: alert.password)
                        .textContentType(.password)
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                        .flipsForRightToLeftLayoutDirection(false)
                    Button(alert.cancelButtonTitle, role: .cancel, action: alert.cancelAction)
                    Button(alert.doneButtonTitle, action: alert.doneAction)
                }, message: {
                    Text(verbatim: alert.message)
                })
        } else {
            content.credentialAlert(isPresented: alert.isPresented) {
                alert
            }
        }
    }
}
#endif
