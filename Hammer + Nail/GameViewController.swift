import UIKit
import SceneKit

// MARK: - Simple Color Cell for CollectionView
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

    // SceneKit components
    var scnView: SCNView!
    var scnScene: SCNScene!
    var hammerNode: SCNNode!
    var nailNode: SCNNode!

    // Game state
    var nailsHammered = 0 {
        didSet {
            DispatchQueue.main.async {
                self.nailsLabel.text = "Nails Hammered: \(self.nailsHammered)"
            }
        }
    }

    // UI Elements
    var nailsLabel: UILabel!
    var hammerButton: UIButton!
    var autoHammerTimer: Timer?
    var isAutoHammering = false
    
    // Menu Elements
    var menuButton: UIButton!
    var menuView: UIView!
    var isMenuOpen = false

    // Animation Keys
    let hammerAnimationKey = "hammerSwingAnimation"
    let nailAnimationKey = "nailBounceAnimation"

    var overlayView: UIView!
    
    var customizationView: UIView!
    var colorOptions: [UIColor] = [.red, .blue, .green, .yellow, .purple, .orange]
    var currentColorIndex = 0
    var selectedPart: SCNNode? // Will store either hammer head or handle
    var previewNode: SCNNode? // For displaying the spinning preview

    // --- Customization Properties ---
    var customizationContainerView: UIView! // Main view for customization
    var hammerPreviewView: SCNView!        // SCNView for the hammer preview
    var previewScene: SCNScene!            // Scene for the preview
    var previewHammerNode: SCNNode?        // The cloned hammer node for preview
    var previewHammerHeadNode: SCNNode?    // Reference to preview head
    var previewHammerHandleNode: SCNNode?  // Reference to preview handle
    var headColorCollectionView: UICollectionView!
    var handleColorCollectionView: UICollectionView!
    // Store indices for saving/loading
    var selectedHeadColorIndex: Int = 0 // Default to index 0 (e.g., darkGray)
    var selectedHandleColorIndex: Int = 1 // Default to index 1 (e.g., brown)

    // Keys for UserDefaults persistence
    let headColorIndexKey = "selectedHeadColorIndex"
    let handleColorIndexKey = "selectedHandleColorIndex"

    override func viewDidLoad() {
        super.viewDidLoad()
        loadCustomization() // Load saved colors before setting up scene
        setupView()
        setupScene()
        setupCamera()
        setupLights()
        createHammer()      // Hammer created with loaded/default colors
        createNail()
        setupUI()
        setupHammerButton()
        setupMenuButton()   // Menu setup remains the same
        setupCustomizationUI() // Setup the customization view structure (initially hidden)
    }
    
    // MARK: - UICollectionViewDataSource

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return colorOptions.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCell.identifier, for: indexPath) as? ColorCell else {
            fatalError("Unable to dequeue ColorCell")
        }
        let color = colorOptions[indexPath.item]
        var isSelected = false

        if collectionView == headColorCollectionView {
            isSelected = (indexPath.item == selectedHeadColorIndex)
        } else if collectionView == handleColorCollectionView {
            isSelected = (indexPath.item == selectedHandleColorIndex)
        }

        cell.configure(color: color, isSelected: isSelected)
        return cell
    }
    
    // MARK: - UICollectionViewDelegate

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedColor = colorOptions[indexPath.item]

        if collectionView == headColorCollectionView {
            // Update head color selection
            let previousIndex = selectedHeadColorIndex
            selectedHeadColorIndex = indexPath.item
            previewHammerHeadNode?.geometry?.firstMaterial?.diffuse.contents = selectedColor

            // Reload this cell and the previously selected cell for border update
            let previousIndexPath = IndexPath(item: previousIndex, section: 0)
            collectionView.reloadItems(at: [indexPath, previousIndexPath].filter { $0.item < colorOptions.count && $0.item >= 0 })


        } else if collectionView == handleColorCollectionView {
            // Update handle color selection
            let previousIndex = selectedHandleColorIndex
            selectedHandleColorIndex = indexPath.item
            previewHammerHandleNode?.geometry?.firstMaterial?.diffuse.contents = selectedColor

             // Reload this cell and the previously selected cell for border update
            let previousIndexPath = IndexPath(item: previousIndex, section: 0)
            collectionView.reloadItems(at: [indexPath, previousIndexPath].filter { $0.item < colorOptions.count && $0.item >= 0 })
        }
         collectionView.scrollToItem(at: indexPath, at: .centeredHorizontally, animated: true)
    }
    
    func loadCustomization() {
        // Load saved indices from UserDefaults, using defaults if not found
        selectedHeadColorIndex = UserDefaults.standard.integer(forKey: headColorIndexKey) // Defaults to 0 if key doesn't exist
        selectedHandleColorIndex = UserDefaults.standard.object(forKey: handleColorIndexKey) as? Int ?? 1 // Default to 1 if key doesn't exist

         // Ensure indices are valid for the current colorOptions array
         if selectedHeadColorIndex < 0 || selectedHeadColorIndex >= colorOptions.count {
             selectedHeadColorIndex = 0 // Reset to default if saved index is invalid
         }
         if selectedHandleColorIndex < 0 || selectedHandleColorIndex >= colorOptions.count {
             selectedHandleColorIndex = 1 // Reset to default if saved index is invalid
         }
    }

    // MARK: - Setup Methods

    func setupView() {
        scnView = self.view as? SCNView
        scnView.showsStatistics = false
        scnView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)
        scnView.allowsCameraControl = false
    }

    func setupScene() {
        scnScene = SCNScene()
        scnView.scene = scnScene
    }

    func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 8)
        cameraNode.eulerAngles = SCNVector3(x: -0.1, y: 0, z: 0)
        scnScene.rootNode.addChildNode(cameraNode)
    }

    func setupLights() {
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

    // MARK: - Button Setup
    
    func setupHammerButton() {
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
        // Menu button in top-right corner
        menuButton = UIButton(type: .system)
        menuButton.setImage(UIImage(systemName: "line.horizontal.3"), for: .normal)
        menuButton.tintColor = .black
        menuButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        menuButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuButton)
        
        // Overlay view to block interactions when menu is open
        overlayView = UIView()
        overlayView.backgroundColor = UIColor.black.withAlphaComponent(0.3)
        overlayView.isHidden = true
        overlayView.alpha = 0
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(toggleMenu))
        overlayView.addGestureRecognizer(tapRecognizer)
        view.addSubview(overlayView)
        
        // Menu view (hidden by default)
        menuView = UIView()
        menuView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        menuView.layer.cornerRadius = 15
        menuView.layer.shadowOpacity = 0.3
        menuView.layer.shadowRadius = 10
        menuView.layer.shadowOffset = CGSize(width: 0, height: 5)
        menuView.isHidden = true
        menuView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(menuView)
        
        // Menu options
        let options = ["Settings", "Customize", "Share", "Shop"]
        var previousButton: UIButton?
        
        // Create menu title
        let titleLabel = UILabel()
        titleLabel.text = ""
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        menuView.addSubview(titleLabel)
        
        for (index, option) in options.enumerated() {
            let button = UIButton(type: .system)
            button.setTitle(option, for: .normal)
            button.setTitleColor(.black, for: .normal)
            button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
            button.tag = index
            button.addTarget(self, action: #selector(menuOptionSelected(_:)), for: .touchUpInside)
            button.translatesAutoresizingMaskIntoConstraints = false
            menuView.addSubview(button)
            
            NSLayoutConstraint.activate([
                button.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 16),
                button.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -16),
                button.heightAnchor.constraint(equalToConstant: 50)
            ])
            
            if let previous = previousButton {
                button.topAnchor.constraint(equalTo: previous.bottomAnchor).isActive = true
            } else {
                button.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10).isActive = true
            }
            
            // Add separator except for last item
            if index < options.count - 1 {
                let separator = UIView()
                separator.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
                separator.translatesAutoresizingMaskIntoConstraints = false
                menuView.addSubview(separator)
                
                NSLayoutConstraint.activate([
                    separator.leadingAnchor.constraint(equalTo: menuView.leadingAnchor, constant: 16),
                    separator.trailingAnchor.constraint(equalTo: menuView.trailingAnchor, constant: -16),
                    separator.topAnchor.constraint(equalTo: button.bottomAnchor),
                    separator.heightAnchor.constraint(equalToConstant: 1)
                ])
            }
            
            previousButton = button
        }
        
        // Add Close button at the bottom
        let closeButton = UIButton(type: .system)
        closeButton.setTitle("Close", for: .normal)
        closeButton.setTitleColor(.systemRed, for: .normal)
        closeButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        closeButton.addTarget(self, action: #selector(toggleMenu), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        menuView.addSubview(closeButton)
        
        // Add separator above close button
        let closeSeparator = UIView()
        closeSeparator.backgroundColor = UIColor.lightGray.withAlphaComponent(0.3)
        closeSeparator.translatesAutoresizingMaskIntoConstraints = false
        menuView.addSubview(closeSeparator)
        
        // Set constraints for menu view
        NSLayoutConstraint.activate([
            // Overlay view covers entire screen
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            
            // Menu button in top-right
            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            menuButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            menuButton.widthAnchor.constraint(equalToConstant: 44),
            menuButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Menu view centered
            menuView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            menuView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            menuView.widthAnchor.constraint(equalToConstant: 280),
            
            // Menu title
            titleLabel.topAnchor.constraint(equalTo: menuView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
            
            // Close button and separator
            closeSeparator.topAnchor.constraint(equalTo: previousButton!.bottomAnchor, constant: 10),
            closeSeparator.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
            closeSeparator.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
            closeSeparator.heightAnchor.constraint(equalToConstant: 1),
            
            closeButton.topAnchor.constraint(equalTo: closeSeparator.bottomAnchor, constant: 10),
            closeButton.leadingAnchor.constraint(equalTo: menuView.leadingAnchor),
            closeButton.trailingAnchor.constraint(equalTo: menuView.trailingAnchor),
            closeButton.heightAnchor.constraint(equalToConstant: 50),
            closeButton.bottomAnchor.constraint(equalTo: menuView.bottomAnchor, constant: -20)
        ])
    }
    
    func setupCustomizationUI() {
        // Main Container for Customization
        customizationContainerView = UIView()
        customizationContainerView.backgroundColor = UIColor(white: 0.9, alpha: 0.95) // Slightly transparent background
        customizationContainerView.layer.cornerRadius = 20
        customizationContainerView.layer.shadowColor = UIColor.black.cgColor
        customizationContainerView.layer.shadowOffset = CGSize(width: 0, height: 5)
        customizationContainerView.layer.shadowRadius = 15
        customizationContainerView.layer.shadowOpacity = 0.3
        customizationContainerView.isHidden = true // Start hidden
        customizationContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customizationContainerView) // Add to main view, above overlay

        // Back/Close Button (Top Left)
        let closeButton = UIButton(type: .system)
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.tintColor = .gray
        closeButton.addTarget(self, action: #selector(hideCustomizationScreen), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(closeButton)

        // Title Label
        let titleLabel = UILabel()
        titleLabel.text = "Customize Hammer"
        titleLabel.font = UIFont.systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(titleLabel)

        // --- Hammer Preview Setup ---
        hammerPreviewView = SCNView()
        hammerPreviewView.backgroundColor = UIColor.lightGray.withAlphaComponent(0.5)
        hammerPreviewView.layer.cornerRadius = 10
        hammerPreviewView.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(hammerPreviewView)
        setupPreviewScene() // Setup the scene, camera, lights for preview

        // --- Head Color Carousel ---
        let headLabel = UILabel()
        headLabel.text = "Head Color"
        headLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        headLabel.textAlignment = .center
        headLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(headLabel)

        let headLayout = UICollectionViewFlowLayout()
        headLayout.scrollDirection = .horizontal
        headLayout.itemSize = CGSize(width: 50, height: 50) // Adjust size as needed
        headLayout.minimumLineSpacing = 10
        headLayout.sectionInset = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        headColorCollectionView = UICollectionView(frame: .zero, collectionViewLayout: headLayout)
        headColorCollectionView.dataSource = self
        headColorCollectionView.delegate = self
        headColorCollectionView.register(ColorCell.self, forCellWithReuseIdentifier: ColorCell.identifier)
        headColorCollectionView.backgroundColor = .clear
        headColorCollectionView.showsHorizontalScrollIndicator = false
        headColorCollectionView.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(headColorCollectionView)

        // --- Handle Color Carousel ---
        let handleLabel = UILabel()
        handleLabel.text = "Handle Color"
        handleLabel.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
        handleLabel.textAlignment = .center
        handleLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(handleLabel)

        let handleLayout = UICollectionViewFlowLayout()
        handleLayout.scrollDirection = .horizontal
        handleLayout.itemSize = CGSize(width: 50, height: 50) // Adjust size as needed
        handleLayout.minimumLineSpacing = 10
        handleLayout.sectionInset = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)

        handleColorCollectionView = UICollectionView(frame: .zero, collectionViewLayout: handleLayout)
        handleColorCollectionView.dataSource = self
        handleColorCollectionView.delegate = self
        handleColorCollectionView.register(ColorCell.self, forCellWithReuseIdentifier: ColorCell.identifier)
        handleColorCollectionView.backgroundColor = .clear
        handleColorCollectionView.showsHorizontalScrollIndicator = false
        handleColorCollectionView.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(handleColorCollectionView)

        // --- Save Button ---
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save & Close", for: .normal)
        saveButton.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .bold)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveCustomization), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        customizationContainerView.addSubview(saveButton)

        // --- Constraints ---
        let padding: CGFloat = 20
        let carouselHeight: CGFloat = 60 // Height including inset

        NSLayoutConstraint.activate([
            // Container (slightly smaller than the old menu, adjust as needed)
            customizationContainerView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customizationContainerView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            customizationContainerView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.85), // 85% of screen width
            customizationContainerView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.7), // 70% of screen height

            // Close Button
            closeButton.topAnchor.constraint(equalTo: customizationContainerView.topAnchor, constant: padding / 2),
            closeButton.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding / 2),
            closeButton.widthAnchor.constraint(equalToConstant: 40),
            closeButton.heightAnchor.constraint(equalToConstant: 40),

            // Title
            titleLabel.topAnchor.constraint(equalTo: customizationContainerView.topAnchor, constant: padding),
            titleLabel.centerXAnchor.constraint(equalTo: customizationContainerView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: closeButton.trailingAnchor, constant: 5),
            titleLabel.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding - 35), // Space for close button

            // Preview View (takes up significant space)
            hammerPreviewView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: padding),
            hammerPreviewView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            hammerPreviewView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),
            // Height constraint will be determined by bottom elements

            // Head Label
            headLabel.topAnchor.constraint(equalTo: hammerPreviewView.bottomAnchor, constant: padding),
            headLabel.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            headLabel.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),

            // Head Collection View
            headColorCollectionView.topAnchor.constraint(equalTo: headLabel.bottomAnchor, constant: 5),
            headColorCollectionView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor),
            headColorCollectionView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor),
            headColorCollectionView.heightAnchor.constraint(equalToConstant: carouselHeight),

            // Handle Label
            handleLabel.topAnchor.constraint(equalTo: headColorCollectionView.bottomAnchor, constant: padding),
            handleLabel.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor, constant: padding),
            handleLabel.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor, constant: -padding),

            // Handle Collection View
            handleColorCollectionView.topAnchor.constraint(equalTo: handleLabel.bottomAnchor, constant: 5),
            handleColorCollectionView.leadingAnchor.constraint(equalTo: customizationContainerView.leadingAnchor),
            handleColorCollectionView.trailingAnchor.constraint(equalTo: customizationContainerView.trailingAnchor),
            handleColorCollectionView.heightAnchor.constraint(equalToConstant: carouselHeight),

             // Make Preview View fill space above head label and below handle collection view
            hammerPreviewView.bottomAnchor.constraint(equalTo: headLabel.topAnchor, constant: -padding),

            // Save Button (at the bottom)
            saveButton.topAnchor.constraint(equalTo: handleColorCollectionView.bottomAnchor, constant: padding),
            saveButton.centerXAnchor.constraint(equalTo: customizationContainerView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 150),
            saveButton.heightAnchor.constraint(equalToConstant: 50),
            saveButton.bottomAnchor.constraint(equalTo: customizationContainerView.bottomAnchor, constant: -padding) // Anchor to bottom
        ])
    }
    
    func setupPreviewScene() {
        previewScene = SCNScene()
        hammerPreviewView.scene = previewScene
        hammerPreviewView.allowsCameraControl = true // Allow user to rotate preview
        hammerPreviewView.autoenablesDefaultLighting = false // Use custom lights

        // Preview Camera
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 1, 6) // Adjust position for good view
        previewScene.rootNode.addChildNode(cameraNode)

        // Preview Lighting
        let ambientLight = SCNNode()
        ambientLight.light = SCNLight()
        ambientLight.light?.type = .ambient
        ambientLight.light?.intensity = 400
        ambientLight.light?.color = UIColor(white: 0.7, alpha: 1.0)
        previewScene.rootNode.addChildNode(ambientLight)

        let directionalLight = SCNNode()
        directionalLight.light = SCNLight()
        directionalLight.light?.type = .directional
        directionalLight.light?.intensity = 800
        directionalLight.light?.color = UIColor.white
        directionalLight.position = SCNVector3(-3, 5, 4)
        directionalLight.eulerAngles = SCNVector3(-Float.pi/4, -Float.pi/4, 0)
        previewScene.rootNode.addChildNode(directionalLight)
    }

    // MARK: - Button Actions

    @objc func hammerButtonTapped() {
        hammerAction()
    }

    func hammerAction() {
        nailsHammered += 1
        animateHammerSwing()
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
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
        guard !isAutoHammering else { return }
        isAutoHammering = true
        hammerButton.backgroundColor = UIColor.systemRed
        
        hammerAction()
        autoHammerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.hammerAction()
        }
    }

    func stopAutoHammering() {
        autoHammerTimer?.invalidate()
        autoHammerTimer = nil
        isAutoHammering = false
        hammerButton.backgroundColor = UIColor.systemOrange
    }
    
    // MARK: - Menu Actions (Updated)
    
    @objc func toggleMenu() {
        isMenuOpen.toggle()
        
        if isMenuOpen {
            // Disable other buttons
            hammerButton.isUserInteractionEnabled = false
            menuButton.isUserInteractionEnabled = false
            
            // Show overlay and menu
            overlayView.isHidden = false
            menuView.isHidden = false
            menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
                self.overlayView.alpha = 1
                self.menuView.transform = .identity
                self.menuButton.transform = CGAffineTransform(rotationAngle: .pi/2)
            })
        } else {
            UIView.animate(withDuration: 0.2, animations: {
                self.overlayView.alpha = 0
                self.menuView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
                self.menuButton.transform = .identity
            }) { _ in
                self.overlayView.isHidden = true
                self.menuView.isHidden = true
                
                // Re-enable buttons
                self.hammerButton.isUserInteractionEnabled = true
                self.menuButton.isUserInteractionEnabled = true
            }
        }
        if customizationContainerView != nil && !customizationContainerView.isHidden {
             hideCustomizationScreen()
         }
    }
    
    @objc func menuOptionSelected(_ sender: UIButton) {
        // Close menu first
        toggleMenu()

        // Add a slight delay to allow menu to close before showing next screen/action
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch sender.tag {
            case 0: // Settings
                print("Settings selected")
                // Implement Settings screen presentation
            case 1: // Customize
                 self.presentCustomizationScreen() // Call the new presentation method
            case 2: // Share
                print("Share selected")
                // Implement Share functionality
            case 3: // Shop
                print("Shop selected")
                // Implement Shop screen presentation
            default:
                break
            }
        }
    }
    
    func showCustomizationScreen() {
        toggleMenu() // Close the menu first
        
        // Create customization view
        customizationView = UIView()
        customizationView.backgroundColor = UIColor(white: 0.95, alpha: 1)
        customizationView.layer.cornerRadius = 15
        customizationView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(customizationView)
        
        // Back button
        let backButton = UIButton(type: .system)
        backButton.setTitle("Back", for: .normal)
        backButton.setTitleColor(.systemBlue, for: .normal)
        backButton.addTarget(self, action: #selector(hideCustomizationScreen), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(backButton)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Customize Hammer"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(titleLabel)
        
        // Part selection buttons
        let headButton = createPartButton(title: "Hammer Head")
        headButton.addTarget(self, action: #selector(selectHammerHead), for: .touchUpInside)
        customizationView.addSubview(headButton)
        
        let handleButton = createPartButton(title: "Handle")
        handleButton.addTarget(self, action: #selector(selectHandle), for: .touchUpInside)
        customizationView.addSubview(handleButton)
        
        // Preview container
        let previewContainer = UIView()
        previewContainer.backgroundColor = UIColor(white: 0.85, alpha: 1)
        previewContainer.layer.cornerRadius = 10
        previewContainer.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(previewContainer)
        
        // Color carousel controls
        let prevColorButton = UIButton(type: .system)
        prevColorButton.setTitle("<", for: .normal)
        prevColorButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        prevColorButton.addTarget(self, action: #selector(previousColor), for: .touchUpInside)
        prevColorButton.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(prevColorButton)
        
        let nextColorButton = UIButton(type: .system)
        nextColorButton.setTitle(">", for: .normal)
        nextColorButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        nextColorButton.addTarget(self, action: #selector(nextColor), for: .touchUpInside)
        nextColorButton.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(nextColorButton)
        
        // Save button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save", for: .normal)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = .systemGreen
        saveButton.layer.cornerRadius = 10
        saveButton.addTarget(self, action: #selector(saveCustomization), for: .touchUpInside)
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        customizationView.addSubview(saveButton)
        
        // Constraints
        NSLayoutConstraint.activate([
            customizationView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            customizationView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            customizationView.widthAnchor.constraint(equalToConstant: 300),
            customizationView.heightAnchor.constraint(equalToConstant: 500),
            
            backButton.topAnchor.constraint(equalTo: customizationView.topAnchor, constant: 15),
            backButton.leadingAnchor.constraint(equalTo: customizationView.leadingAnchor, constant: 15),
            
            titleLabel.topAnchor.constraint(equalTo: customizationView.topAnchor, constant: 20),
            titleLabel.centerXAnchor.constraint(equalTo: customizationView.centerXAnchor),
            
            headButton.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 30),
            headButton.centerXAnchor.constraint(equalTo: customizationView.centerXAnchor),
            headButton.widthAnchor.constraint(equalToConstant: 200),
            headButton.heightAnchor.constraint(equalToConstant: 50),
            
            handleButton.topAnchor.constraint(equalTo: headButton.bottomAnchor, constant: 20),
            handleButton.centerXAnchor.constraint(equalTo: customizationView.centerXAnchor),
            handleButton.widthAnchor.constraint(equalToConstant: 200),
            handleButton.heightAnchor.constraint(equalToConstant: 50),
            
            previewContainer.topAnchor.constraint(equalTo: handleButton.bottomAnchor, constant: 30),
            previewContainer.centerXAnchor.constraint(equalTo: customizationView.centerXAnchor),
            previewContainer.widthAnchor.constraint(equalToConstant: 200),
            previewContainer.heightAnchor.constraint(equalToConstant: 200),
            
            prevColorButton.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            prevColorButton.trailingAnchor.constraint(equalTo: previewContainer.leadingAnchor, constant: -20),
            
            nextColorButton.centerYAnchor.constraint(equalTo: previewContainer.centerYAnchor),
            nextColorButton.leadingAnchor.constraint(equalTo: previewContainer.trailingAnchor, constant: 20),
            
            saveButton.bottomAnchor.constraint(equalTo: customizationView.bottomAnchor, constant: -20),
            saveButton.centerXAnchor.constraint(equalTo: customizationView.centerXAnchor),
            saveButton.widthAnchor.constraint(equalToConstant: 100),
            saveButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Add tap to close when tapping outside
        let tapOutside = UITapGestureRecognizer(target: self, action: #selector(hideCustomizationScreen))
        tapOutside.cancelsTouchesInView = false
        view.addGestureRecognizer(tapOutside)
    }
    
    func createPartButton(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(.black, for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        button.backgroundColor = UIColor(white: 0.85, alpha: 1)
        button.layer.cornerRadius = 10
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }
    
    @objc func hideCustomizationScreen() {
        // Animate out
        UIView.animate(withDuration: 0.3, animations: {
            self.overlayView.alpha = 0 // Fade out overlay
            self.customizationContainerView.alpha = 0
            self.customizationContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        }) { _ in
            self.customizationContainerView.isHidden = true
            self.overlayView.isHidden = true

            // Clean up preview
            self.previewHammerNode?.removeFromParentNode()
            self.previewHammerNode = nil
            self.previewHammerHeadNode = nil
            self.previewHammerHandleNode = nil

            // Re-enable background interaction
            self.hammerButton.isUserInteractionEnabled = true
            self.menuButton.isUserInteractionEnabled = true
        }
    }
    
    @objc func selectHammerHead() {
        selectedPart = hammerNode.childNodes.first?.childNodes.first(where: { $0.geometry is SCNBox })
        setupPreview()
    }
    
    @objc func selectHandle() {
        selectedPart = hammerNode.childNodes.first?.childNodes.first(where: { $0.geometry is SCNCylinder })
        setupPreview()
    }
    
    func setupPreview() {
        guard let part = selectedPart else { return }
        
        // Remove previous preview
        previewNode?.removeFromParentNode()
        
        // Create a copy for preview
        previewNode = part.clone()
        previewNode?.position = SCNVector3(0, 0, 0)
        
        // Add to scene in preview container
        if let previewContainer = customizationView.subviews.first(where: { $0.backgroundColor == UIColor(white: 0.85, alpha: 1) }) {
            let previewScene = SCNScene()
            let cameraNode = SCNNode()
            cameraNode.camera = SCNCamera()
            cameraNode.position = SCNVector3(0, 0, 5)
            previewScene.rootNode.addChildNode(cameraNode)
            
            let lightNode = SCNNode()
            lightNode.light = SCNLight()
            lightNode.light?.type = .omni
            lightNode.position = SCNVector3(0, 10, 10)
            previewScene.rootNode.addChildNode(lightNode)
            
            previewScene.rootNode.addChildNode(previewNode!)
            
            let previewView = SCNView(frame: previewContainer.bounds)
            previewView.scene = previewScene
            previewView.backgroundColor = .clear
            previewView.allowsCameraControl = false
            previewContainer.addSubview(previewView)
            
            // Rotate slowly
            let rotateAction = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 0.5, z: 0, duration: 5))
            previewNode?.runAction(rotateAction)
        }
    }
    
    func presentCustomizationScreen() {
        guard let mainHammer = self.hammerNode else { return } // Ensure hammer exists

        // Disable background interaction
        hammerButton.isUserInteractionEnabled = false
        menuButton.isUserInteractionEnabled = false

        // Show overlay
        overlayView.isHidden = false

        // --- Setup Preview Hammer ---
        // Remove old preview if exists
        previewHammerNode?.removeFromParentNode()

        // Clone the *entire* hammer node from the main scene
        previewHammerNode = mainHammer.clone()
        previewHammerNode?.position = SCNVector3(0, 0, 0) // Center in preview
        previewHammerNode?.eulerAngles = SCNVector3(0, 0, 0) // Reset rotation for preview

        // Find the head and handle within the *cloned* node
        previewHammerHeadNode = previewHammerNode?.childNode(withName: "hammerHead", recursively: true)
        previewHammerHandleNode = previewHammerNode?.childNode(withName: "hammerHandle", recursively: true)

        // Add the cloned hammer to the preview scene
        if let previewHammer = previewHammerNode {
            previewScene.rootNode.addChildNode(previewHammer)
            // Optional: Add a slow rotation animation
             let rotateAction = SCNAction.repeatForever(SCNAction.rotateBy(x: 0, y: 1, z: 0, duration: 10))
             previewHammer.runAction(rotateAction)
        }

        // Reload collection views to show current selection
        headColorCollectionView.reloadData()
        handleColorCollectionView.reloadData()
        // Scroll to selected items initially (optional, but good UX)
        headColorCollectionView.scrollToItem(at: IndexPath(item: selectedHeadColorIndex, section: 0), at: .centeredHorizontally, animated: false)
        handleColorCollectionView.scrollToItem(at: IndexPath(item: selectedHandleColorIndex, section: 0), at: .centeredHorizontally, animated: false)


        // Prepare animation
        customizationContainerView.isHidden = false
        customizationContainerView.alpha = 0
        customizationContainerView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)

        // Animate in
        UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: [], animations: {
            self.overlayView.alpha = 1 // Fade in overlay fully
            self.customizationContainerView.alpha = 1
            self.customizationContainerView.transform = .identity
        })
    }
    
    
    // MARK: - Customization Actions

    @objc func saveCustomization() {
        // Apply selected colors to the *main game* hammer node
        let headColor = colorOptions[selectedHeadColorIndex]
        let handleColor = colorOptions[selectedHandleColorIndex]

        // Find the actual game hammer parts by name
        let gameHammerHead = hammerNode.childNode(withName: "hammerHead", recursively: true)
        let gameHammerHandle = hammerNode.childNode(withName: "hammerHandle", recursively: true)

        gameHammerHead?.geometry?.firstMaterial?.diffuse.contents = headColor
        gameHammerHandle?.geometry?.firstMaterial?.diffuse.contents = handleColor

        // --- Persistence ---
        UserDefaults.standard.set(selectedHeadColorIndex, forKey: headColorIndexKey)
        UserDefaults.standard.set(selectedHandleColorIndex, forKey: handleColorIndexKey)

        hideCustomizationScreen()
    }
    
    @objc func previousColor() {
        guard let part = selectedPart else { return }
        currentColorIndex = (currentColorIndex - 1 + colorOptions.count) % colorOptions.count
        part.geometry?.firstMaterial?.diffuse.contents = colorOptions[currentColorIndex]
        previewNode?.geometry?.firstMaterial?.diffuse.contents = colorOptions[currentColorIndex]
    }

    @objc func nextColor() {
        guard let part = selectedPart else { return }
        currentColorIndex = (currentColorIndex + 1) % colorOptions.count
        part.geometry?.firstMaterial?.diffuse.contents = colorOptions[currentColorIndex]
        previewNode?.geometry?.firstMaterial?.diffuse.contents = colorOptions[currentColorIndex]
    }
    
//    @objc func saveCustomization() {
//        // You could save the color choice to UserDefaults here if you want persistence
//        hideCustomizationScreen()
//    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
             super.touchesBegan(touches, with: event)

             if isMenuOpen, let touch = touches.first {
                 let location = touch.location(in: view)
                 // Close menu if tap is outside menu and menu button
                 if !menuView.frame.contains(location) && !menuButton.frame.contains(location) {
                     toggleMenu()
                 }
             }
             // Note: We don't need special touch handling to close the customization view here,
             // as the overlay and the view itself capture touches. The 'X' button is used to close.
         }

    // MARK: - Cleanup
    deinit {
        stopAutoHammering()
    }

    // MARK: - Scene Creation

    func createHammer() {
        let hammerHead = SCNBox(width: 1.0, height: 0.3, length: 0.5, chamferRadius: 0.05)
        hammerHead.firstMaterial?.diffuse.contents = UIColor.darkGray
        let hammerHeadNode = SCNNode(geometry: hammerHead)
        hammerHeadNode.position = SCNVector3(x: 0, y: 1.5, z: 0)

        let hammerHandle = SCNCylinder(radius: 0.08, height: 3.0)
        hammerHandle.firstMaterial?.diffuse.contents = UIColor.brown
        let hammerHandleNode = SCNNode(geometry: hammerHandle)
        hammerHandleNode.position = SCNVector3(x: 0, y: 0, z: 0)

        let pivotNode = SCNNode()
        pivotNode.position = SCNVector3(x: 1.5, y: 0, z: 0)

        hammerNode = SCNNode()
        hammerNode.position = SCNVector3(x: 0.1, y: 0.2, z: 0)

        pivotNode.addChildNode(hammerHandleNode)
        pivotNode.addChildNode(hammerHeadNode)
        hammerNode.addChildNode(pivotNode)

        pivotNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 12)

        scnScene.rootNode.addChildNode(hammerNode)
    }

    func createNail() {
        let nailHead = SCNCylinder(radius: 0.15, height: 0.1)
        nailHead.firstMaterial?.diffuse.contents = UIColor.lightGray

        let nailShaft = SCNCylinder(radius: 0.03, height: 1.2)
        nailShaft.firstMaterial?.diffuse.contents = UIColor.darkGray

        let nailHeadNode = SCNNode(geometry: nailHead)
        nailHeadNode.position = SCNVector3(x: 0, y: (0.1/2), z: 0)

        let nailShaftNode = SCNNode(geometry: nailShaft)
        nailShaftNode.position = SCNVector3(x: 0, y: -(1.2/2), z: 0)

        nailNode = SCNNode()
        nailNode.addChildNode(nailHeadNode)
        nailNode.addChildNode(nailShaftNode)
        nailNode.position = SCNVector3(x: 0, y: 0.5, z: 0)

        let board = SCNBox(width: 3.0, height: 1.5, length: 2, chamferRadius: 0.02)
        let woodMaterial = SCNMaterial()
        woodMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1)
        board.materials = [woodMaterial]

        let boardNode = SCNNode(geometry: board)
        boardNode.position = SCNVector3(x: 0, y: -1.0, z: 0)
        scnScene.rootNode.addChildNode(boardNode)

        scnScene.rootNode.addChildNode(nailNode)
    }

    // MARK: - UI Setup

    func setupUI() {
        nailsLabel = UILabel()
        nailsLabel.text = "Nails Hammered: 0"
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

    // MARK: - Animation

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

    // MARK: - Device Orientation

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
}
