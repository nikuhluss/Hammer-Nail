import UIKit
import SceneKit

class GameViewController: UIViewController {

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

    override func viewDidLoad() {
        super.viewDidLoad()
        setupView()
        setupScene()
        setupCamera()
        setupLights()
        createHammer()
        createNail()
        setupUI()
        setupHammerButton()
        setupMenuButton()
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
        titleLabel.text = "Menu"
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
    }
    
    @objc func menuOptionSelected(_ sender: UIButton) {
        toggleMenu()
        
        // Add a slight delay to allow menu to close before showing next screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            switch sender.tag {
            case 0: // Settings
                print("Settings selected")
            case 1: // Customize
                self.showCustomizationScreen()
            case 2: // Share
                print("Share selected")
            case 3: // Shop
                print("Shop selected")
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
        customizationView.removeFromSuperview()
        previewNode?.removeFromParentNode()
        previewNode = nil
        selectedPart = nil
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
    
    @objc func saveCustomization() {
        // You could save the color choice to UserDefaults here if you want persistence
        hideCustomizationScreen()
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        if isMenuOpen, let touch = touches.first {
            let location = touch.location(in: view)
            if !menuView.frame.contains(location) && !menuButton.frame.contains(location) {
                toggleMenu()
            }
        }
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
