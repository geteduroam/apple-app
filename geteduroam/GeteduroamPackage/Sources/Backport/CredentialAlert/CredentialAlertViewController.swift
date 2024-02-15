// From https://stackoverflow.com/a/61902990/60488
#if os(iOS)
import Combine
import SwiftUI
import UIKit

public class CredentialAlertViewController: UIViewController {
    
    /// Presents a UIAlertController (alert style) 
    init(alert: CredentialAlert) {
        self.alert = alert
        if let username = alert.username {
            self._username = username
        } else {
            self._username = .constant("")
        }
        self._password = alert.password
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Dependencies
    private let alert: CredentialAlert
    @Binding private var username: String
    @Binding private var password: String
    
    // MARK: - Private Properties
    private var usernameSubscription: AnyCancellable?
    private var passwordSubscription: AnyCancellable?
    
    // MARK: - Lifecycle
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        presentAlertController()
    }
    
    private func presentAlertController() {
        guard usernameSubscription == nil else { return } // present only once
        
        let alertController = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
        
        if let _ = alert.username {
            // add a textField and create a subscription to update the `text` binding
            alertController.addTextField { [weak self] textField in
                guard let self = self else { return }
                textField.placeholder = alert.usernamePrompt
                textField.autocapitalizationType = .none
                textField.autocorrectionType = .no
                self.usernameSubscription = NotificationCenter.default
                    .publisher(for: UITextField.textDidChangeNotification, object: textField)
                    .map { ($0.object as? UITextField)?.text ?? "" }
                    .assign(to: \.username, on: self)
            }
        }
        
        alertController.addTextField { [weak self] textField in
            guard let self = self else { return }
            textField.placeholder = alert.passwordPrompt
            textField.isSecureTextEntry = true
            textField.autocapitalizationType = .none
            textField.autocorrectionType = .no
            self.passwordSubscription = NotificationCenter.default
                .publisher(for: UITextField.textDidChangeNotification, object: textField)
                .map { ($0.object as? UITextField)?.text ?? "" }
                .assign(to: \.password, on: self)
        }
        
        let cancelAction = UIAlertAction(title: alert.cancelButtonTitle, style: .cancel) { [weak self] _ in
            self?.alert.cancelAction()
            self?.alert.isPresented.wrappedValue = false
        }
        alertController.addAction(cancelAction)
        
        let action = UIAlertAction(title: alert.doneButtonTitle, style: .default) { [weak self] _ in
            self?.alert.doneAction()
            self?.alert.isPresented.wrappedValue = false
        }
        alertController.addAction(action)
        
        present(alertController, animated: true, completion: nil)
    }
}
#endif
