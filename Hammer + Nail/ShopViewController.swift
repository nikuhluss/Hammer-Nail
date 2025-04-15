//
//  ShopViewController.swift
//  Hammer + Nail
//
//  Created by Nicholas Scott on 4/13/25.
//

import Foundation

// ShopViewController.swift
import UIKit
import StoreKit

// --- Cell for displaying products in the table view ---
class ProductCell: UITableViewCell {
    static let identifier = "ProductCell"

    let nameLabel = UILabel()
    let descriptionLabel = UILabel()
    let priceLabel = UILabel()
    let buyButton = UIButton(type: .system)
    var purchaseAction: (() -> Void)? // Closure to handle buy button tap

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCellUI()
        buyButton.addTarget(self, action: #selector(buyButtonTapped), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupCellUI() {
        nameLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        descriptionLabel.font = UIFont.systemFont(ofSize: 14)
        descriptionLabel.textColor = .darkGray
        descriptionLabel.numberOfLines = 0 // Allow multiple lines
        priceLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        priceLabel.textAlignment = .right

        buyButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        buyButton.layer.cornerRadius = 8
        buyButton.contentEdgeInsets = UIEdgeInsets(top: 8, left: 15, bottom: 8, right: 15)

        let textStack = UIStackView(arrangedSubviews: [nameLabel, descriptionLabel])
        textStack.axis = .vertical
        textStack.spacing = 4

        let mainStack = UIStackView(arrangedSubviews: [textStack, priceLabel, buyButton])
        mainStack.axis = .horizontal
        mainStack.alignment = .center
        mainStack.spacing = 10
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(mainStack)

        // Set hugging and compression resistance priorities
        textStack.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textStack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        priceLabel.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        priceLabel.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        buyButton.setContentHuggingPriority(.defaultHigh, for: .horizontal)
        buyButton.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)


        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            mainStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10),
            mainStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            mainStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            buyButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80) // Ensure button has minimum width
        ])
    }

    @objc private func buyButtonTapped() {
        purchaseAction?()
    }

    func configure(product: Product, isPurchased: Bool, purchaseHandler: @escaping () -> Void) {
        nameLabel.text = product.displayName
        descriptionLabel.text = product.description
        priceLabel.text = product.displayPrice
        purchaseAction = purchaseHandler

        if isPurchased {
            buyButton.setTitle("Owned", for: .normal)
            buyButton.isEnabled = false
            buyButton.backgroundColor = .systemGray
            buyButton.setTitleColor(.white, for: .disabled)
        } else {
            buyButton.setTitle("Buy", for: .normal)
            buyButton.isEnabled = true
            buyButton.backgroundColor = .systemBlue
            buyButton.setTitleColor(.white, for: .normal)
        }
        // Reset alpha for cell reuse
        buyButton.alpha = 1.0
        contentView.alpha = 1.0
    }

    // Visual feedback during purchase attempt
    func showProcessing() {
        buyButton.setTitle("...", for: .normal)
        buyButton.isEnabled = false
        buyButton.alpha = 0.5 // Dim slightly
    }
}

// --- The Shop View Controller ---
class ShopViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    var storeManager: StoreManager! // Passed from GameViewController
    private var products: [Product] = []
    private var purchasedIDs: Set<String> = []

    private let tableView = UITableView()
    private let activityIndicator = UIActivityIndicatorView(style: .large)
    private let statusLabel = UILabel()
    private var purchaseInProgressID: String? // Track which item is being purchased

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground

        guard storeManager != nil else {
            fatalError("StoreManager instance was not provided to ShopViewController.")
        }

        setupNavigationBar()
        setupTableView()
        setupStatusLabel()
        setupActivityIndicator()

        // Register observer for purchase updates
        NotificationCenter.default.addObserver(self, selector: #selector(handlePurchasesUpdated(_:)), name: .purchasesUpdated, object: nil)

        // Initial data load
        reloadData()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        print("ShopViewController deinitialized")
    }

    private func setupNavigationBar() {
        navigationItem.title = "Shop Colors"
        let closeButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(closeButtonTapped))
        navigationItem.rightBarButtonItem = closeButton
    }

     private func setupTableView() {
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(ProductCell.self, forCellReuseIdentifier: ProductCell.identifier)
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80 // Estimate
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.allowsSelection = false // Don't highlight rows on tap
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
    }

    private func setupStatusLabel() {
        statusLabel.text = "Loading Products..."
        statusLabel.textColor = .gray
        statusLabel.textAlignment = .center
        statusLabel.font = UIFont.systemFont(ofSize: 16)
        statusLabel.isHidden = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    private func setupActivityIndicator() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(activityIndicator)
        NSLayoutConstraint.activate([
            activityIndicator.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            activityIndicator.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func reloadData() {
        self.products = storeManager.availableProducts
        self.purchasedIDs = storeManager.purchasedProductIDs

        // Sort products (e.g., alphabetically by display name) for consistent order
        self.products.sort { $0.displayName < $1.displayName }

        if products.isEmpty {
            statusLabel.text = "No products available."
            statusLabel.isHidden = false
            tableView.isHidden = true
        } else {
            statusLabel.isHidden = true
            tableView.isHidden = false
            tableView.reloadData()
        }
        activityIndicator.stopAnimating()
    }

    @objc private func handlePurchasesUpdated(_ notification: Notification) {
        print("ShopVC: Received purchase update notification.")
        // Update purchased status and reload table view
        self.purchasedIDs = storeManager.purchasedProductIDs
        purchaseInProgressID = nil // Clear purchase indicator
        tableView.reloadData()
    }

    @objc private func closeButtonTapped() {
        dismiss(animated: true, completion: nil)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: ProductCell.identifier, for: indexPath) as? ProductCell else {
            return UITableViewCell() // Should not happen
        }

        let product = products[indexPath.row]
        let isPurchased = purchasedIDs.contains(product.id)

        cell.configure(product: product, isPurchased: isPurchased) { [weak self] in
            // --- Purchase Action ---
            guard let self = self else { return }

            print("Buy button tapped for: \(product.id)")
            self.purchaseInProgressID = product.id // Mark this product as being purchased
            cell.showProcessing() // Show visual feedback

            Task { // Perform purchase asynchronously
                do {
                    let transaction = try await self.storeManager.purchase(product)
                    if transaction != nil {
                        // Purchase successful (StoreManager handles finishing transaction and updating purchasedIDs)
                        print("Purchase initiated successfully for \(product.id). Waiting for notification.")
                        // UI update will happen via notification handler
                    } else {
                        // Purchase cancelled or pending - reset UI
                        print("Purchase cancelled or pending for \(product.id).")
                        await MainActor.run {
                            self.purchaseInProgressID = nil
                            tableView.reloadRows(at: [indexPath], with: .none) // Reset cell state
                        }
                    }
                } catch {
                    // Purchase failed
                    print("‼️ Purchase failed for \(product.id): \(error)")
                    await MainActor.run {
                        self.purchaseInProgressID = nil
                        tableView.reloadRows(at: [indexPath], with: .none) // Reset cell state
                        // Optionally show an alert to the user about the error
                        self.showErrorAlert(message: "Purchase failed. Please try again.")
                    }
                }
            }
        }

        // If this cell corresponds to the item currently being purchased, keep showing processing state
        if product.id == purchaseInProgressID {
            cell.showProcessing()
        }

        return cell
    }

    // Helper to show alerts
    private func showErrorAlert(title: String = "Error", message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}
