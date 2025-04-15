import UIKit
import SceneKit

// MARK: - Simple Color Cell for CollectionView
// (Keep this class as it was in your original code)
class ColorCell: UICollectionViewCell {
    static let identifier = "ColorCell"
    let colorView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(colorView)
        colorView.layer.cornerRadius = frame.height / 2
        colorView.layer.borderWidth = 2
        colorView.layer.borderColor = UIColor.clear.cgColor // Default: not selected
        colorView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            colorView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            colorView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            colorView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            colorView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(color: UIColor, isSelected: Bool) {
        colorView.backgroundColor = color
        colorView.layer.borderColor = isSelected ? UIColor.black.cgColor : UIColor.clear.cgColor
        colorView.layer.borderWidth = isSelected ? 3 : 2 // Make selected border thicker
    }
}

class GameViewController: UIViewController, UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {

    // MARK: - Properties (Original + New Customization)

    // SceneKit components (Original)
    var scnView: SCNView!
    var scnScene: SCNScene!
    var hammerNode: SCNNode!
    var nailNode: SCNNode!

    // Game state (Original)
    var nailsHammered = 0 {
        didSet {
            DispatchQueue.main.async {
                self.nailsLabel.text = "Nails Hammered: \(self.nailsHammered)"
            }
        }
    }

    // UI Elements (Original)
    var nailsLabel: UILabel!
    var hammerButton: UIButton!
    var autoHammerTimer: Timer?
    var isAutoHammering = false

    // Menu Elements (Original)
    var menuButton: UIButton!
    var menuView: UIView!
    var isMenuOpen = false
    var overlayView: UIView! // Keep the overlay view

    // Animation Keys (Original)
    let hammerAnimationKey = "hammerSwingAnimation"
    let nailAnimationKey = "nailBounceAnimation"

    // --- NEW: Customization Properties ---
    var customizationContainerView: UIView! // Main view for customization UI
    var hammerPreviewView: SCNView!        // SCNView for the hammer preview
    var previewScene: SCNScene!            // Scene specifically for the preview
    var previewHammerNode: SCNNode?        // The cloned hammer node for the preview display
    var previewHammerHeadNode: SCNNode?    // Reference to the head part of the preview hammer
    var previewHammerHandleNode: SCNNode?  // Reference to the handle part of the preview hammer
    var headColorCollectionView: UICollectionView!
    var handleColorCollectionView: UICollectionView!

    // Color options (You can customize these colors)
    var colorOptions: [UIColor] = [
        .darkGray, .brown, .red, .blue, .green, .yellow, .purple, .orange, .black, .white, .systemTeal, .magenta
    ]
    
    let baseColorOptions: [UIColor] = [
        .darkGray, .brown, .red, .blue, .green, .yellow, .purple, .orange, .black, .white, .systemTeal, .magenta
    ]
    
    var availableColorOptions: [UIColor] = []
    // Store selected indices for saving/loading
    var selectedHeadColorIndex: Int = 0 // Default head color index (e.g., darkGray)
    var selectedHandleColorIndex: Int = 1 // Default handle color index (e.g., brown)

    // Keys for UserDefaults persistence
    let headColorIndexKey = "selectedHeadColorIndex"
    let handleColorIndexKey = "selectedHandleColorIndex"
    var storeManager: StoreManager!

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        // --- NEW: Initialize StoreManager ---
        storeManager = StoreManager() // Create the instance

        // --- NEW: Register for Purchase Notifications ---
        NotificationCenter.default.addObserver(self, selector: #selector(handlePurchasesUpdated(_:)), name: .purchasesUpdated, object: nil)



        updateAvailableColors() // Initial update
        loadCustomization()     // Now load indices based on potentially updated available colors

        // 2. Setup main view and scene (Original)
        setupView()
        setupScene()
        setupCamera()
        setupLights()

        // 3. Create game objects (Original geometry/positioning)
        createHammer()      // Now uses node naming
        createNail()

        // 4. Apply loaded/default colors to the MAIN hammer (Uses availableColorOptions now)
        applyHammerColors(headColorIndex: selectedHeadColorIndex, handleColorIndex: selectedHandleColorIndex)

        // 5. Setup UI elements (Original)
        setupUI()
        setupHammerButton()
        setupMenuButton()

        // 6. Setup the NEW customization UI structure (initially hidden)
        setupCustomizationUI() // This will now use availableColorOptions

        // --- NEW: Request products after setup ---
         // Perform initial check after a short delay to allow StoreManager init
        Task {
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000) // 1 second delay
            await storeManager.updatePurchasedStatus()
            await storeManager.requestProducts()
            updateAvailableColors()
        }
            
    }

    // MARK: - Setup Methods (Original + New)

    // Original Setup Methods (Keep these as they are)
    func setupView() {
        scnView = self.view as? SCNView
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        scnView.allowsCameraControl = false // Keep main camera fixed
    }

    func setupScene() {
        scnScene = SCNScene()
        scnView.scene = scnScene
    }

    func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Use original positions
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 8)
        cameraNode.eulerAngles = SCNVector3(x: -0.1, y: 0, z: 0)
        scnScene.rootNode.addChildNode(cameraNode)
    }

    func setupLights() {
        // Use original lighting setup
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor.white
        keyLight.light?.intensity = 1000
        keyLight.light?.castsShadow = true
        keyLight.position = SCNVector3(x: -5, y: 5, z: 5)
        keyLight.eulerAngles = SCNVector3(x: -.pi / 3, y: -.pi / 4, z: 0)
        scnScene.rootNode.addChildNode(keyLight)

        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.color = UIColor(white: 0.5, alpha: 1.0)
        fillLight.light?.intensity = 400
        scnScene.rootNode.addChildNode(fillLight)
    }

    func setupUI() {
        // Use original UI setup
        nailsLabel = UILabel()
        nailsLabel.text = "Nails Hammered: \(nailsHammered)" // Use property observer
        nailsLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold)
        nailsLabel.textColor = .black
        nailsLabel.textAlignment = .center
        nailsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nailsLabel)

        NSLayoutConstraint.activate([
            nailsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30),
            nailsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nailsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }

    func setupHammerButton() {
        // Use original button setup
        hammerButton = UIButton(type: .system)
        hammerButton.setTitle("🔨 HAMMER", for: .normal)
        hammerButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        hammerButton.setTitleColor(.white, for: .normal)
        hammerButton.backgroundColor = UIColor.systemOrange
        hammerButton.layer.cornerRadius = 10
        hammerButton.layer.shadowColor = UIColor.black.cgColor
        hammerButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        hammerButton.layer.shadowRadius = 3
        hammerButton.layer.shadowOpacity = 0.3
        hammerButton.translatesAutoresizingMaskIntoConstraints = false

        hammerButton.addTarget(self, action: #selector(hammerButtonTapped), for: .touchDown)
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3
        hammerButton.addGestureRecognizer(longPress)

        view.addSubview(hammerButton)

        NSLayoutConstraint.activate([
            hammerButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            hammerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hammerButton.widthAnchor.constraint(equalToConstant: 220),
            hammerButton.heightAnchor.constraint(equalToConstant: 65)
        ])
    }

    func setupMenuButton() {
        // Use original menu button and view setup, including overlay
        menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        menuButton.tintColor = .black
        menuButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)

        overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlayView.isHidden = true
        overlayView.alpha = 0
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        // *** NEW: Add tap recognizer for overlay to close things ***
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(overlayTapped))
        overlayView.addGestureRecognizer(tapRecognizer)
        view.addSubview(overlayView) // Ensure overlay is added

        menuView = UIView()
        menuView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        menuView.layer.cornerRadius = 15
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 10
        menuView.layer.shadowOffset = CGSize(width: 0, height: 5)
        menuView.isHidden = true
        menuView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuView) // Ensure menu view is added

        // --- Menu Content (Using Stack View for simplicity) ---
        let menuStackView = UIStackView()
        menuStackView.axis = .vertical
        menuStackView.alignment = .fill
        menuStackView.distribution = .equalSpacing
        menuStackView.spacing = 0 // Separators handle spacing
        menuStackView.translatesAutoresizingMaskIntoConstraints = false
        menuView.addSubview(menuStackView)

        // Title Label (Optional)
        let titleLabel = UILabel()
        titleLabel.text = "Menu"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        menuStackView.addArrangedSubview(titleLabel)
        menuStackView.setCustomSpacing(15, after: titleLabel)

        // *** IMPORTANT: Ensure "Customize" is tag 1 if using original options order ***
        let options = ["Settings", "Customize", "Shop", "Share"]
        for (index, option) in options.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(option, for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            button.contentHorizontalAlignment = .center
            button.tag = index // Tag matches array index
            button.addTarget(self, action: #selector(menuOptionSelected(_:)), for: .touchUpInside)

            menuStackView.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true

            if index < options.count - 1 {
                let separator = createSeparator()
                menuStackView.addArrangedSubview(separator)
                menuStackView.setCustomSpacing(0, after: button)
                menuStackView.setCustomSpacing(0, after: separator)
            }
        }

        // Separator before Close button
        let closeSeparator = createSeparator()
        menuStackView.addArrangedSubview(closeSeparator)
        menuStackView.setCustomSpacing(10, after: closeSeparator)

        // Close Button
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.systemRed, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        closeButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        menuStackView.addArrangedSubview(closeButton)
        closeButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

        // --- Constraints (Keep Original + Add StackView Constraints) ---
        NSLayoutConstraint.activate([
            // Overlay covers entire view
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            // Menu Button (Original)
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),

            // Menu View (Original Size/Position)
            menuView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuView.widthAnchor.constraint(equalToConstant: 280),

            // Stack View inside Menu View
            menuStackView.topAnchor.constraint(equalTo: menuView.topAnchor, constant: 20),
            menuStackView.bottomAnchor.constraint(equalTo: menuView.bottomAnchor, constant: -20),
            menuStackView.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 16),
            menuStackView.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -16),
        ])
    }

    // Helper for menu separators
    func createSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.heightAnchor.constraint(equalToConstant: 1).isActive = true
        return separator
    }


    // --- NEW: Customization UI Setup ---
    func setupCustomizationUI() {
        // Main Container for Customization
        customizationContainerView = UIView()
        customizationContainerView.backgroundColor = UIColor(white: 0.9, alpha: 0.95)
        customizationContainerView.layer.cornerRadius = 20
        customizationContainerView.layer.shadowColor = UIColor.black.cgColor
        customizationContainerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        customizationContainerView.layer.shadowRadius = 15
        customizationContainerView.layer.shadowOpacity = 0.3
        customizationContainerView.isHidden = true // Start hidden
        customizationContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customizationContainerView) // Add to main view

        // Back/Close Button (Top Left)
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .gray
        closeButton.addTarget(self, action: #selector(hideCustomizationScreenWrapper), for: .touchUpInside) // Wrapper to ensure correct dismissal
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(closeButton)

        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Customize Hammer"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(titleLabel)

        // Hammer Preview SCNView
        hammerPreviewView = SCNView()
        hammerPreviewView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        hammerPreviewView.layer.cornerRadius = 10
        hammerPreviewView.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(hammerPreviewView)
        setupPreviewScene() // Setup scene, camera, lights for the preview

        // Head Color Section Label
        let headLabel = UILabel()
        headLabel.text = "Head Color"
        headLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headLabel.textAlignment = .center
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(headLabel)

        // Head Color Collection View
        headColorCollectionView = createColorCollectionView()
        customizationContainerView.addSubview(headColorCollectionView)

        // Handle Color Section Label
        let handleLabel = UILabel()
        handleLabel.text = "Handle Color"
        handleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        handleLabel.textAlignment = .center
        handleLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(handleLabel)

        // Handle Color Collection View
        handleColorCollectionView = createColorCollectionView()
        customizationContainerView.addSubview(handleColorCollectionView)

        // Save Button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save & Close", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveCustomizationAndClose), for: .touchUpInside) // Calls save then hide
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(saveButton)

        // --- Constraints (Layout similar to working version) ---
        let padding: CGFloat = 20
        let carouselHeight: CGFloat = 60 // Height for collection view row

        NSLayoutConstraint.activate([
            // Container (adjust size multipliers as needed)
            customizationContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customizationContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            customizationContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85),
            // Allow height to be flexible based on content
            // customizationContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7), // Removed fixed height

            // Close Button
            closeButton.topAnchor.constraint(equalTo: customizationContainerView.topAnchor, constant: padding / 2),
            closeButton.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding / 2),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Title
            titleLabel.topAnchor.constraint(equalTo: customizationContainerView.topAnchor, constant: padding),
            titleLabel.centerXAnchor.constraint(equalTo: customizationContainerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 5), // Ensure space
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: customizationContainerView.trailingAnchor, constant: -padding), // Allow space on right

            // Preview View
            hammerPreviewView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: padding),
            hammerPreviewView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            hammerPreviewView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),
            // Set aspect ratio or fixed height for preview
             hammerPreviewView.heightAnchor.constraint(equalTo: customizationContainerView.widthAnchor, multiplier: 0.5), // Example: Height is half the container width

            // Head Label
            headLabel.topAnchor.constraint(equalTo: hammerPreviewView.bottomAnchor, constant: padding),
            headLabel.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            headLabel.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),

            // Head Collection View
            headColorCollectionView.topAnchor.constraint(equalTo: headLabel.bottomAnchor, constant: 5),
            headColorCollectionView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor), // Span full width
            headColorCollectionView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor),
            headColorCollectionView.heightAnchor.constraint(equalToConstant: carouselHeight),

            // Handle Label
            handleLabel.topAnchor.constraint(equalTo: headColorCollectionView.bottomAnchor, constant: padding),
            handleLabel.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            handleLabel.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),

            // Handle Collection View
            handleColorCollectionView.topAnchor.constraint(equalTo: handleLabel.bottomAnchor, constant: 5),
            handleColorCollectionView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor), // Span full width
            handleColorCollectionView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor),
            handleColorCollectionView.heightAnchor.constraint(equalToConstant: carouselHeight),

            // Save Button
            saveButton.topAnchor.constraint(equalTo: handleColorCollectionView.bottomAnchor, constant: padding * 1.5), // More space before save
            saveButton.centerXAnchor.constraint(equalTo: customizationContainerView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 150),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            // Anchor Save button to container bottom
            saveButton.bottomAnchor.constraint(equalTo: customizationContainerView.bottomAnchor, constant: -padding) // Ensure button is within bounds
        ])
    }

    // --- NEW: Helper to create Collection Views ---
    func createColorCollectionView() -> UICollectionView {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.itemSize = CGSize(width: 50, height: 50) // Square items for colors
        layout.minimumLineSpacing = 10
        // Add horizontal padding within the collection view itself
        layout.sectionInset = UIEdgeInsets(top: 5, left: 15, bottom: 5, right: 15)

        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(ColorCell.self, forCellWithReuseIdentifier: ColorCell.identifier)
        collectionView.backgroundColor = .clear // Make background transparent
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        return collectionView
    }

    // --- NEW: Setup Preview Scene ---
    func setupPreviewScene() {
        previewScene = SCNScene()
        hammerPreviewView.scene = previewScene
        hammerPreviewView.allowsCameraControl = true // Allow user interaction with preview
        hammerPreviewView.autoenablesDefaultLighting = false // Use custom lights below

        // Preview Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Position camera to view the hammer well (adjust as needed)
        cameraNode.position = SCNVector3(2, 0.5, 2) // Slightly above center, further back
        cameraNode.eulerAngles = SCNVector3(x: -Float.pi / 12, y: 0, z: -1) // Slight downward tilt
        previewScene.rootNode.addChildNode(cameraNode)

        // Preview Lighting (simpler than main scene perhaps)
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 500 // Decent ambient light
        ambientLight.light?.color = UIColor(white: 0.8, alpha: 1.0)
        previewScene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800 // Stronger directional light
        directionalLight.light?.color = UIColor.white
        directionalLight.position = SCNVector3(-3, 5, 4) // Position light source
        directionalLight.eulerAngles = SCNVector3(-Float.pi/4, -Float.pi/4, 0) // Angle light
        previewScene.rootNode.addChildNode(directionalLight)
    }

    // MARK: - Game Object Creation (Original + Naming)

    func createHammer() {
        // Use original geometry and positioning
        let hammerHeadGeo = SCNBox(width: 1.0, height: 0.3, length: 0.5, chamferRadius: 0.05)
        // Initial color set here, will be overridden by applyHammerColors
        hammerHeadGeo.firstMaterial?.diffuse.contents = colorOptions[selectedHeadColorIndex]
        let hammerHeadNode = SCNNode(geometry: hammerHeadGeo)
        hammerHeadNode.position = SCNVector3(x: 0, y: 1.5, z: 0) // Original relative position
        hammerHeadNode.name = "hammerHead" // *** Assign Name ***

        let hammerHandleGeo = SCNCylinder(radius: 0.08, height: 3.0)
        // Initial color set here, will be overridden by applyHammerColors
        hammerHandleGeo.firstMaterial?.diffuse.contents = colorOptions[selectedHandleColorIndex]
        let hammerHandleNode = SCNNode(geometry: hammerHandleGeo)
        hammerHandleNode.position = SCNVector3(x: 0, y: 0, z: 0) // Original relative position
        hammerHandleNode.name = "hammerHandle" // *** Assign Name ***

        // Original pivot and main node setup
        let pivotNode = SCNNode()
        pivotNode.position = SCNVector3(x: 1.5, y: 0, z: 0) // Original pivot position

        hammerNode = SCNNode()
        hammerNode.position = SCNVector3(x: 0.1, y: 0.2, z: 0) // Original main node position

        pivotNode.addChildNode(hammerHandleNode)
        pivotNode.addChildNode(hammerHeadNode)
        hammerNode.addChildNode(pivotNode)

        pivotNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 12) // Original initial tilt

        scnScene.rootNode.addChildNode(hammerNode)
    }

    func createNail() {
        // Use original nail and board geometry and positioning
        let nailHeadGeo = SCNCylinder(radius: 0.15, height: 0.1)
        nailHeadGeo.firstMaterial?.diffuse.contents = UIColor.lightGray

        let nailShaftGeo = SCNCylinder(radius: 0.03, height: 1.2)
        nailShaftGeo.firstMaterial?.diffuse.contents = UIColor.darkGray

        let nailHeadNode = SCNNode(geometry: nailHeadGeo)
        nailHeadNode.position = SCNVector3(x: 0, y: (0.1/2), z: 0) // Original relative position

        let nailShaftNode = SCNNode(geometry: nailShaftGeo)
        nailShaftNode.position = SCNVector3(x: 0, y: -(1.2/2), z: 0) // Original relative position

        nailNode = SCNNode()
        nailNode.addChildNode(nailHeadNode)
        nailNode.addChildNode(nailShaftNode)
        nailNode.position = SCNVector3(x: 0, y: 0.5, z: 0) // Original nail position

        // Original board setup
        let boardGeo = SCNBox(width: 3.0, height: 1.5, length: 2, chamferRadius: 0.02)
        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        boardGeo.materials = [woodMaterial]

        let boardNode = SCNNode(geometry: boardGeo)
        boardNode.position = SCNVector3(x: 0, y: -1.0, z: 0) // Original board position
        scnScene.rootNode.addChildNode(boardNode)

        scnScene.rootNode.addChildNode(nailNode)
    }
    


    // MARK: - Button Actions & Game Logic (Original)

    @objc func hammerButtonTapped() {
        // Original action, maybe prevent during auto-hammer
        guard !isAutoHammering else { return }
        hammerAction()
    }

    func hammerAction() {
        // Original action logic
        // Prevent re-triggering animation if already running
        guard let pivot = hammerNode.childNodes.first, pivot.action(forKey: hammerAnimationKey) == nil else { return }
        
        nailsHammered += 1
        animateHammerSwing()
        //animateNailHit() // Call the original nail animation
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        // Original long press logic
        switch gesture.state {
        case .began:
            if !isAutoHammering {
                startAutoHammering()
            }
        case .ended, .cancelled:
            stopAutoHammering()
        default:
            break
        }
    }

    func startAutoHammering() {
        // Original auto-hammer start
        guard !isAutoHammering else { return }
        isAutoHammering = true
        hammerButton.backgroundColor = UIColor.systemRed // Indicate active

        hammerAction() // Initial hit
        autoHammerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in // Original interval
            self?.hammerAction()
        }
    }

    func stopAutoHammering() {
        // Original auto-hammer stop
        autoHammerTimer?.invalidate()
        autoHammerTimer = nil
        isAutoHammering = false
        hammerButton.backgroundColor = UIColor.systemOrange // Restore color
    }

    // MARK: - Menu Actions (Original logic, Updated Customize action)

    @objc func toggleMenu() {
        // Use original animation logic, ensure overlay is handled
        isMenuOpen.toggle()

        if isMenuOpen {
            hammerButton.isUserInteractionEnabled = false
            menuButton.isUserInteractionEnabled = false // Disable menu button while open

            overlayView.isHidden = false
            menuView.isHidden = false
            menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: -20)
            menuView.alpha = 0

            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self.overlayView.alpha = 1
                self.menuView.transform = .identity
                self.menuView.alpha = 1
                self.menuButton.transform = CGAffineTransform(rotationAngle: .pi / 4) // Example rotation
            })
        } else {
            UIView.animate(withDuration: 0.25, animations: {
                self.overlayView.alpha = 0
                self.menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9).translatedBy(x: 0, y: -20)
                self.menuView.alpha = 0
                self.menuButton.transform = .identity
            }) { _ in
                self.overlayView.isHidden = true
                self.menuView.isHidden = true

                // Re-enable interaction only if customization isn't showing
                if self.customizationContainerView == nil || self.customizationContainerView.isHidden {
                     self.hammerButton.isUserInteractionEnabled = true
                     self.menuButton.isUserInteractionEnabled = true
                }
            }
        }

        // If customization screen is open when toggling menu, hide it
         if customizationContainerView != nil && !customizationContainerView.isHidden {
             hideCustomizationScreen(animated: false) // Hide immediately
         }
    }

    // --- MODIFIED: Menu Option Handling ---
    @objc func menuOptionSelected(_ sender: UIButton) {
        toggleMenu() // Close the menu first

        // Delay action slightly
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
             // Corresponds to ["Settings", "Customize", "Shop", "Share"] order
            switch sender.tag {
            case 0: // Settings
                print("Settings selected")
            case 1: // Customize
                // Ensure colors are up-to-date before presenting
                self.updateAvailableColors()
                self.presentCustomizationScreen()
            case 2: // Shop
                print("Attempting to present shop")
                print("Current available products count: \(self.storeManager.availableProducts.count)")
                print("Current purchased IDs: \(self.storeManager.purchasedProductIDs)")
                
                if self.storeManager.availableProducts.isEmpty {
                    print("No products available - attempting to fetch")
                    let loadingAlert = UIAlertController(title: "Loading Shop", message: nil, preferredStyle: .alert)
                    self.present(loadingAlert, animated: true)
                    
                    Task {
                        await self.storeManager.requestProducts()
                        
                        await MainActor.run {
                            loadingAlert.dismiss(animated: true) {
                                if self.storeManager.availableProducts.isEmpty {
                                    print("Still no products after fetch attempt")
                                    self.showSimpleAlert(title: "Shop Unavailable",
                                                      message: "Please check your internet connection and try again.")
                                } else {
                                    print("Products loaded successfully, presenting shop")
                                    self.presentShop(manager: self.storeManager)
                                }
                            }
                        }
                    }
                } else {
                    print("Products already available, presenting shop")
                    self.presentShop(manager: self.storeManager)
                }

            case 3: // Share
                print("Share selected")
            default:
                break
            }
        }
    }
    
    // --- NEW: Helper to present Shop ---
    private func presentShop(manager: StoreManager) {
        let shopVC = ShopViewController()
        shopVC.storeManager = manager // Pass the instance

        // Embed in a Navigation Controller for the title bar and close button
        let navController = UINavigationController(rootViewController: shopVC)
        navController.modalPresentationStyle = .pageSheet // Or .formSheet etc.
        self.present(navController, animated: true, completion: nil)
    }
    
    // --- NEW: Helper for simple alerts ---
    private func showSimpleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        // Ensure presentation happens on the main thread
        DispatchQueue.main.async {
            self.present(alert, animated: true)
        }
    }

    // --- NEW: Overlay Tap Handler ---
    @objc func overlayTapped() {
         if isMenuOpen {
             toggleMenu() // Close menu if tapped outside
         } else if customizationContainerView != nil && !customizationContainerView.isHidden {
             // Decide: close without saving? Or maybe prompt? For now, just close.
             hideCustomizationScreen(animated: true)
         }
     }


    // MARK: - Customization Screen Presentation/Dismissal (NEW)

    func presentCustomizationScreen() {
        guard let mainHammer = self.hammerNode else {
            print("Error: Main hammer node not found.")
            return
        }

        // Disable background interaction
        hammerButton.isUserInteractionEnabled = false
        menuButton.isUserInteractionEnabled = false

        // Show overlay
        overlayView.isHidden = false // Make sure overlay view is part of the hierarchy

        // --- Setup Preview Hammer ---
        previewHammerNode?.removeFromParentNode() // Clear old preview if any

        previewHammerNode = mainHammer.clone() // Clone the *entire* main hammer
        previewHammerNode?.position = SCNVector3(0, 0, 0) // Center in preview scene
        previewHammerNode?.eulerAngles = SCNVector3(0, 0, 0) // Reset rotation for preview

        // Find parts *by name* within the cloned node
        previewHammerHeadNode = previewHammerNode?.childNode(withName: "hammerHead", recursively: true)
        previewHammerHandleNode = previewHammerNode?.childNode(withName: "hammerHandle", recursively: true)

        if previewHammerHeadNode == nil { print("Warning: Preview hammer head node not found by name.") }
        if previewHammerHandleNode == nil { print("Warning: Preview hammer handle node not found by name.") }


        // Add the cloned hammer to the preview scene
        if let previewHammer = previewHammerNode {
            previewScene.rootNode.addChildNode(previewHammer)
             // Optional: Add slow rotation if desired
             // let rotateAction = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 1, z: 0, duration: 10))
             // previewHammer.runAction(rotateAction, forKey: "previewRotation")
        } else {
            print("Error: Failed to clone hammer for preview.")
            overlayView.isHidden = true // Hide overlay if preview fails
            hammerButton.isUserInteractionEnabled = true
            menuButton.isUserInteractionEnabled = true
            return
        }

        // Update collection views to reflect current selection state
        headColorCollectionView.reloadData()
        handleColorCollectionView.reloadData()

        // Scroll to initially selected colors
        scrollToSelected(collectionView: headColorCollectionView, index: selectedHeadColorIndex)
        scrollToSelected(collectionView: handleColorCollectionView, index: selectedHandleColorIndex)

        // Prepare and animate the customization view in
        customizationContainerView.isHidden = false
        customizationContainerView.alpha = 0
        customizationContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.overlayView.alpha = 1 // Ensure overlay is visible
            self.customizationContainerView.alpha = 1
            self.customizationContainerView.transform = .identity
        })
    }

    // --- NEW: Hide Customization Screen Function ---
    // Add wrapper for button action to allow default parameter
     @objc func hideCustomizationScreenWrapper() {
         hideCustomizationScreen(animated: true)
     }

    func hideCustomizationScreen(animated: Bool = true) {
        // Stop any preview animations if running
        previewHammerNode?.removeAction(forKey: "previewRotation") // Use the correct key if you added rotation

        let duration = animated ? 0.3 : 0.0

        UIView.animate(withDuration: duration, animations: {
            self.overlayView.alpha = 0 // Fade out overlay
            self.customizationContainerView.alpha = 0
            self.customizationContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.customizationContainerView.isHidden = true
            self.overlayView.isHidden = true // Hide overlay completely

            // Clean up preview node from scene
            self.previewHammerNode?.removeFromParentNode()
            self.previewHammerNode = nil // Release the node
            self.previewHammerHeadNode = nil
            self.previewHammerHandleNode = nil

            // Re-enable background interaction only if menu isn't also open
            if self.isMenuOpen == false {
                self.hammerButton.isUserInteractionEnabled = true
                self.menuButton.isUserInteractionEnabled = true
            }
        }
    }


    // MARK: - Customization Logic (NEW)

    // MARK: - Customization Logic (MODIFIED)
    @objc func saveCustomizationAndClose() {
        // Apply colors using the potentially filtered availableColorOptions indices
        applyHammerColors(headColorIndex: selectedHeadColorIndex, handleColorIndex: selectedHandleColorIndex)

        // Save the selected indices persistently
        UserDefaults.standard.set(selectedHeadColorIndex, forKey: headColorIndexKey)
        UserDefaults.standard.set(selectedHandleColorIndex, forKey: handleColorIndexKey)
        print("Customization Saved: Head Index \(selectedHeadColorIndex), Handle Index \(selectedHandleColorIndex) (relative to available options)")

        hideCustomizationScreen(animated: true)
    }

    // --- NEW: Load Customization Function ---
    func loadCustomization() {
        // Load saved indices
        let savedHeadIndex = UserDefaults.standard.object(forKey: headColorIndexKey) as? Int
        let savedHandleIndex = UserDefaults.standard.object(forKey: handleColorIndexKey) as? Int

        // Use saved index if valid and within bounds of *currently available* colors, otherwise use default
        selectedHeadColorIndex = (savedHeadIndex != nil && savedHeadIndex! >= 0 && savedHeadIndex! < availableColorOptions.count) ? savedHeadIndex! : 0
        selectedHandleColorIndex = (savedHandleIndex != nil && savedHandleIndex! >= 0 && savedHandleIndex! < availableColorOptions.count) ? savedHandleIndex! : min(1, availableColorOptions.count - 1) // Default handle index (avoid index out of bounds)

        print("Customization Loaded: Head Index \(selectedHeadColorIndex), Handle Index \(selectedHandleColorIndex) (relative to \(availableColorOptions.count) available options)")

        // Ensure indices are valid if available options changed drastically
        if selectedHeadColorIndex >= availableColorOptions.count { selectedHeadColorIndex = 0 }
        if selectedHandleColorIndex >= availableColorOptions.count { selectedHandleColorIndex = min(1, availableColorOptions.count - 1)}
        if availableColorOptions.isEmpty {
             selectedHeadColorIndex = 0
             selectedHandleColorIndex = 0
        }

    }

    // --- NEW: Function to Apply Colors ---
    // --- MODIFIED: Apply colors using availableColorOptions ---
    func applyHammerColors(headColorIndex: Int, handleColorIndex: Int) {
        // Validate indices against *available* colors
        guard !availableColorOptions.isEmpty,
              headColorIndex >= 0 && headColorIndex < availableColorOptions.count,
              handleColorIndex >= 0 && handleColorIndex < availableColorOptions.count else {
            print("Error: Invalid color index provided during apply. Head: \(headColorIndex), Handle: \(handleColorIndex) (Available: \(availableColorOptions.count))")
            // Fallback to default colors if indices invalid
            applyFallbackColors()
            return
        }

        let headColor = availableColorOptions[headColorIndex]
        let handleColor = availableColorOptions[handleColorIndex]

        // Find the main game hammer parts by name
        // ... (Keep the rest of the geometry finding logic) ...
        guard let mainHammer = hammerNode,
              let gameHammerHead = mainHammer.childNode(withName: "hammerHead", recursively: true),
              let gameHammerHandle = mainHammer.childNode(withName: "hammerHandle", recursively: true) else {
            print("Error: Could not find main hammer parts by name during apply.")
            return
        }

        // ... (Keep the material creation and SCNTransaction logic) ...
        let newHeadMaterial = SCNMaterial()
        newHeadMaterial.diffuse.contents = headColor
        let newHandleMaterial = SCNMaterial()
        newHandleMaterial.diffuse.contents = handleColor

        SCNTransaction.begin()
        gameHammerHead.geometry?.materials = [newHeadMaterial]
        gameHammerHandle.geometry?.materials = [newHandleMaterial]
        SCNTransaction.commit()
        _ = scnView.snapshot()
        print("Applied colors (Head: \(headColorIndex), Handle: \(handleColorIndex)) from available options and forced snapshot.")
    }

    // --- NEW: Fallback color application ---
    func applyFallbackColors() {
        print("Applying fallback colors.")
         guard let mainHammer = hammerNode,
               let gameHammerHead = mainHammer.childNode(withName: "hammerHead", recursively: true),
               let gameHammerHandle = mainHammer.childNode(withName: "hammerHandle", recursively: true) else {
             return
         }
         let headColor = baseColorOptions.first ?? .darkGray
         let handleColor = baseColorOptions.count > 1 ? baseColorOptions[1] : .brown

         let newHeadMaterial = SCNMaterial()
         newHeadMaterial.diffuse.contents = headColor
         let newHandleMaterial = SCNMaterial()
         newHandleMaterial.diffuse.contents = handleColor

         SCNTransaction.begin()
         gameHammerHead.geometry?.materials = [newHeadMaterial]
         gameHammerHandle.geometry?.materials = [newHandleMaterial]
         SCNTransaction.commit()
         _ = scnView.snapshot()
    }
    
    // --- NEW: Update Available Colors based on Purchases ---
    func updateAvailableColors() {
        guard let manager = storeManager else {
            print("Warning: StoreManager not initialized yet for color update.")
            availableColorOptions = baseColorOptions // Use base if manager unavailable
            return
        }

        var currentAvailable = baseColorOptions // Start with base colors

        // Add purchased colors
        for purchasedID in manager.purchasedProductIDs {
            if let color = shopColorMap[purchasedID] { // Use the map from StoreManager
                if !currentAvailable.contains(color) { // Avoid duplicates if base includes purchasable ones
                    currentAvailable.append(color)
                    print("Added purchased color for ID: \(purchasedID)")
                }
            }
        }

        if availableColorOptions != currentAvailable {
            print("Available colors updated. Count: \(currentAvailable.count)")
            availableColorOptions = currentAvailable

            // If customization screen is visible, reload its data
            if customizationContainerView != nil && !customizationContainerView.isHidden {
                headColorCollectionView.reloadData()
                handleColorCollectionView.reloadData()
                // Re-validate selected indices after reload
                loadCustomization()
                applyPreviewColors() // Update preview immediately
            }
             // Also re-apply to main hammer if colors changed significantly
             // and customization isn't open (to avoid conflict)
             else {
                 // Re-load indices and apply to main hammer
                 loadCustomization()
                 applyHammerColors(headColorIndex: selectedHeadColorIndex, handleColorIndex: selectedHandleColorIndex)
             }
        }
    }
    
    // --- NEW: Notification Handler ---
    @objc func handlePurchasesUpdated(_ notification: Notification) {
        print("GameVC: Received purchase update notification.")
        // Update the available colors list
        updateAvailableColors()
    }
    
    // --- NEW: Apply colors to preview hammer ---
    func applyPreviewColors() {
         guard selectedHeadColorIndex >= 0 && selectedHeadColorIndex < availableColorOptions.count,
               selectedHandleColorIndex >= 0 && selectedHandleColorIndex < availableColorOptions.count else {
             print("Preview Apply Error: Invalid indices (\(selectedHeadColorIndex), \(selectedHandleColorIndex)) for available options (\(availableColorOptions.count))")
             return
         }
         previewHammerHeadNode?.geometry?.firstMaterial?.diffuse.contents = availableColorOptions[selectedHeadColorIndex]
         previewHammerHandleNode?.geometry?.firstMaterial?.diffuse.contents = availableColorOptions[selectedHandleColorIndex]
         // print("Applied preview colors.")
     }


    // MARK: - UICollectionViewDataSource (NEW)

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
       // Use the dynamic list of available colors
       return availableColorOptions.count
   }


    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCell.identifier, for: indexPath) as? ColorCell else {
            fatalError("Unable to dequeue ColorCell")
        }
        // Use the dynamic list of available colors
        guard indexPath.item < availableColorOptions.count else {
             print("Error: Index out of bounds for availableColorOptions in cellForItemAt")
             // Return a placeholder or default cell
             cell.configure(color: .lightGray, isSelected: false)
             return cell
         }

        let color = availableColorOptions[indexPath.item]
        var isSelected = false

        if collectionView == headColorCollectionView {
            isSelected = (indexPath.item == selectedHeadColorIndex)
        } else if collectionView == handleColorCollectionView {
            isSelected = (indexPath.item == selectedHandleColorIndex)
        }

        cell.configure(color: color, isSelected: isSelected)
        return cell
    }

    // MARK: - UICollectionViewDelegate (MODIFIED)
   func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard indexPath.item < availableColorOptions.count else {
            print("Error: Index out of bounds for availableColorOptions in didSelectItemAt")
            return
        }
       let selectedColor = availableColorOptions[indexPath.item]
       var previousIndexPath: IndexPath?

       if collectionView == headColorCollectionView {
           if indexPath.item != selectedHeadColorIndex {
               previousIndexPath = IndexPath(item: selectedHeadColorIndex, section: 0)
               selectedHeadColorIndex = indexPath.item
               applyPreviewColors() // Update preview
           }
       } else if collectionView == handleColorCollectionView {
            if indexPath.item != selectedHandleColorIndex {
               previousIndexPath = IndexPath(item: selectedHandleColorIndex, section: 0)
               selectedHandleColorIndex = indexPath.item
               applyPreviewColors() // Update preview
           }
       }

        // Update cell appearance (efficiently)
       if let currentCell = collectionView.cellForItem(at: indexPath) as? ColorCell {
            currentCell.configure(color: selectedColor, isSelected: true)
        }
        if let prevPath = previousIndexPath, prevPath != indexPath,
           prevPath.item < availableColorOptions.count, // Bounds check for prev path
           let previousCell = collectionView.cellForItem(at: prevPath) as? ColorCell {
            let previousColor = availableColorOptions[prevPath.item]
            previousCell.configure(color: previousColor, isSelected: false)
        }

        scrollToSelected(collectionView: collectionView, index: indexPath.item)
   }

    // --- NEW: Helper to scroll collection view ---
    func scrollToSelected(collectionView: UICollectionView, index: Int) {
        guard index >= 0 && index < collectionView.numberOfItems(inSection: 0) else { return }
        let indexPath = IndexPath(item: index, section: 0)
        // Use .centeredHorizontally for best visibility in a row
        collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }


    // MARK: - Animation (Original)

    func animateHammerSwing() {
        guard let pivotNode = hammerNode.childNodes.first else { return }

        pivotNode.removeAction(forKey: hammerAnimationKey)
        nailNode.removeAction(forKey: nailAnimationKey)
        nailNode.position.y = -0.5

        let swingDuration = 0.05
        let impactDuration = 0.03
        let returnDuration = 0.06
        let nailBounceBack: Float = 1.5
        let nailMoveDown: Float = 0

        let swingDown = SCNAction.rotateTo(x: 0, y: 0, z: .pi / 2.5, duration: swingDuration)
        swingDown.timingMode = .easeIn

        let returnUp = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(Float.pi) / 12, duration: returnDuration)
        returnUp.timingMode = .easeOut

        let swingSequence = SCNAction.sequence([swingDown, returnUp])

        let nailDownAction = SCNAction.moveBy(x: 0, y: CGFloat(nailMoveDown), z: 0, duration: impactDuration)
        nailDownAction.timingMode = .easeIn
        let nailUpAction = SCNAction.moveBy(x: 0, y: CGFloat(nailBounceBack), z: 0, duration: returnDuration)
        nailUpAction.timingMode = .easeOut

        let waitAction = SCNAction.wait(duration: swingDuration * 0.8)
        let nailSequence = SCNAction.sequence([waitAction, nailDownAction, nailUpAction])

        pivotNode.runAction(swingSequence, forKey: hammerAnimationKey)
        nailNode.runAction(nailSequence, forKey: nailAnimationKey)
    }


    // MARK: - Device Orientation & Status Bar (Original)

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    // MARK: - Cleanup (Original)
    deinit {
        stopAutoHammering()
        // --- NEW: Remove Observer ---
        NotificationCenter.default.removeObserver(self)
        print("GameViewController deinitialized")
    }

    // --- REMOVED: Old Customization Functions ---
    // @objc func showCustomizationScreen() { ... } // Replaced by presentCustomizationScreen
    // func createPartButton(title: String) -> UIButton { ... } // No longer needed
    // @objc func selectHammerHead() { ... } // No longer needed
    // @objc func selectHandle() { ... } // No longer needed
    // func setupPreview() { ... } // Replaced by logic within presentCustomizationScreen
    // @objc func previousColor() { ... } // Handled by collection view delegate
    // @objc func nextColor() { ... } // Handled by collection view delegate
    // @objc func saveCustomization() { ... } // Replaced by saveCustomizationAndClose

} // End of GameViewController
