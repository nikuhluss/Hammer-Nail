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
            // Update UI on the main thread
            DispatchQueue.main.async {
                self.nailsLabel.text = "Nails Hammered: \(self.nailsHammered)"
            }
        }
    }

    // UI
    var nailsLabel: UILabel!
    // tapToHammerLabel is no longer needed as the button itself guides the user
    // var tapToHammerLabel: UILabel!
    var hammerButton: UIButton!
    var autoHammerTimer: Timer?
    var isAutoHammering = false

    // Animation Keys
    let hammerAnimationKey = "hammerSwingAnimation"
    let nailAnimationKey = "nailBounceAnimation"

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
    }

    // MARK: - Setup Methods

    func setupView() {
        scnView = self.view as? SCNView
        scnView.showsStatistics = false // Disable for production
        scnView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1)

        // No need for a separate tap gesture on the view if using the button
        //let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        //scnView.addGestureRecognizer(tapGesture)
    }

    func setupScene() {
        scnScene = SCNScene()
        scnView.scene = scnScene
        // Disable camera control if you want a fixed view
        scnView.allowsCameraControl = false // Changed to false for fixed view
    }

    func setupCamera() {
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        // Adjusted position for a potentially better view
        cameraNode.position = SCNVector3(x: 0, y: 1, z: 8) // Slightly higher, closer
        // Keep side view if desired
        cameraNode.eulerAngles = SCNVector3(x: -0.1, y: 0, z: 0) // Slight downward angle
        scnScene.rootNode.addChildNode(cameraNode)
    }

    func setupLights() {
        // Key light (more directional)
        let keyLight = SCNNode()
        keyLight.light = SCNLight()
        keyLight.light?.type = .directional
        keyLight.light?.color = UIColor.white
        keyLight.light?.intensity = 1000 // Default is 1000
        keyLight.light?.castsShadow = true // Enable shadows for realism
        keyLight.position = SCNVector3(x: -5, y: 5, z: 5)
        keyLight.eulerAngles = SCNVector3(x: -.pi / 3, y: -.pi / 4, z: 0)
        scnScene.rootNode.addChildNode(keyLight)

        // Fill light (softer ambient)
        let fillLight = SCNNode()
        fillLight.light = SCNLight()
        fillLight.light?.type = .ambient
        fillLight.light?.color = UIColor(white: 0.5, alpha: 1.0) // Slightly brighter ambient
        fillLight.light?.intensity = 400
        scnScene.rootNode.addChildNode(fillLight)
    }

    // MARK: - Button Setup
    func setupHammerButton() {
        hammerButton = UIButton(type: .system)
        hammerButton.setTitle("🔨 HAMMER", for: .normal)
        hammerButton.titleLabel?.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        hammerButton.setTitleColor(.white, for: .normal) // White text
        hammerButton.backgroundColor = UIColor.systemOrange
        hammerButton.layer.cornerRadius = 10
        hammerButton.layer.shadowColor = UIColor.black.cgColor
        hammerButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        hammerButton.layer.shadowRadius = 3
        hammerButton.layer.shadowOpacity = 0.3
        hammerButton.translatesAutoresizingMaskIntoConstraints = false

        // Use touchDown for immediate response, allowing faster repeats
        hammerButton.addTarget(self, action: #selector(hammerButtonTapped), for: .touchDown)

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.3 // Keep long press for auto-hammer
        hammerButton.addGestureRecognizer(longPress)

        view.addSubview(hammerButton)

        NSLayoutConstraint.activate([
            hammerButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40), // More space
            hammerButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            hammerButton.widthAnchor.constraint(equalToConstant: 220), // Slightly wider
            hammerButton.heightAnchor.constraint(equalToConstant: 65) // Slightly taller
        ])
    }

    // MARK: - Button Actions

    @objc func hammerButtonTapped() {
        // Trigger hammer action immediately on touch down
        hammerAction()
    }

    // *** MODIFIED hammerAction ***
    func hammerAction() {
        // 1. Increment count IMMEDIATELY
        nailsHammered += 1

        // 2. Trigger the animation (which will handle interrupting previous ones)
        animateHammerSwing()
    }

    @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            // Only start auto-hammering if not already doing so
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
        hammerButton.backgroundColor = UIColor.systemRed // Indicate active auto-hammer

        // Hammer immediately on press start
        hammerAction()

        // Then continue hammering at intervals
        // Adjust time interval for desired auto-hammer speed
        autoHammerTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.hammerAction()
        }
    }

    func stopAutoHammering() {
        autoHammerTimer?.invalidate()
        autoHammerTimer = nil
        isAutoHammering = false
        hammerButton.backgroundColor = UIColor.systemOrange // Restore original color
    }

    // MARK: - Cleanup
    deinit {
        stopAutoHammering() // Ensure timer is stopped if view controller is deallocated
    }


    func createHammer() {
        // Hammer head (cube)
        let hammerHead = SCNBox(width: 1.0, height: 0.3, length: 0.5, chamferRadius: 0.05)
        hammerHead.firstMaterial?.diffuse.contents = UIColor.darkGray
        let hammerHeadNode = SCNNode(geometry: hammerHead)
        hammerHeadNode.position = SCNVector3(x: 0, y: 1.5, z: 0) // Position relative to handle pivot

        // Hammer handle (cylinder)
        let hammerHandle = SCNCylinder(radius: 0.08, height: 3.0)
        hammerHandle.firstMaterial?.diffuse.contents = UIColor.brown
        let hammerHandleNode = SCNNode(geometry: hammerHandle)
        // Position handle below the head pivot point
        hammerHandleNode.position = SCNVector3(x: 0, y: 0, z: 0)

        // Create pivot node AT THE TOP of the handle where it meets the head
        // This node will be rotated for the swing
        let pivotNode = SCNNode()
        pivotNode.position = SCNVector3(x: 1.5, y: 0, z: 0) // Position where handle joins head

        // Adjust component positions relative to the pivot
        hammerHeadNode.position = SCNVector3(x: 0, y: 1.5, z: 0) // Head centered at pivot
        hammerHandleNode.position = SCNVector3(x: 0, y: 0, z: 0) // Handle extends down from pivot

        // Hammer Base Node - this is the main node to position the whole hammer
        hammerNode = SCNNode()
        // Position the hammer assembly in the scene
        // The pivot point will be at roughly x=0 after positioning
        hammerNode.position = SCNVector3(x: 0.1, y: 0.2, z: 0) // Adjusted y position

        // Add components to the PIVOT node
        pivotNode.addChildNode(hammerHandleNode)
        pivotNode.addChildNode(hammerHeadNode)

        // Add the PIVOT node to the main hammerNode
        hammerNode.addChildNode(pivotNode)

        // Initial rotation (resting position) - apply to PIVOT node
        pivotNode.eulerAngles = SCNVector3(x: 0, y: 0, z: Float.pi / 12) // Slight angle up

        scnScene.rootNode.addChildNode(hammerNode)
    }


    func createNail() {
        // Nail head
        let nailHead = SCNCylinder(radius: 0.15, height: 0.1)
        nailHead.firstMaterial?.diffuse.contents = UIColor.lightGray // Lighter grey

        // Nail shaft
        let nailShaft = SCNCylinder(radius: 0.03, height: 1.2) // Slightly longer
        nailShaft.firstMaterial?.diffuse.contents = UIColor.darkGray

        // Combine nail parts
        let nailHeadNode = SCNNode(geometry: nailHead)
        nailHeadNode.position = SCNVector3(x: 0, y: (0.1/2), z: 0) // Centered vertically

        let nailShaftNode = SCNNode(geometry: nailShaft)
        nailShaftNode.position = SCNVector3(x: 0, y: -(1.2/2), z: 0) // Centered below head

        // Create nail node
        nailNode = SCNNode()
        nailNode.addChildNode(nailHeadNode)
        nailNode.addChildNode(nailShaftNode)
        // Position the nail so the head is roughly at y = 0 before animation
        nailNode.position = SCNVector3(x: 0, y: 0.5, z: 0)

        // Add wooden board under nail
        let board = SCNBox(width: 3.0, height: 1.5, length: 2, chamferRadius: 0.02) // Thinner, wider board
        // Wood texture (replace "wood_texture.png" with your image name if you have one)
        let woodMaterial = SCNMaterial()
        if let woodImage = UIImage(named: "wood_texture.png") {
             woodMaterial.diffuse.contents = woodImage
        } else {
             woodMaterial.diffuse.contents = UIColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1) // Fallback color
        }
        board.materials = [woodMaterial]

        let boardNode = SCNNode(geometry: board)
        // Position board below the nail's starting point
        boardNode.position = SCNVector3(x: 0, y: -1.0, z: 0) // Adjusted position
        scnScene.rootNode.addChildNode(boardNode)

        scnScene.rootNode.addChildNode(nailNode)
    }


    func setupUI() {
        // Nails counter
        nailsLabel = UILabel()
        nailsLabel.text = "Nails Hammered: 0"
        nailsLabel.font = UIFont.systemFont(ofSize: 28, weight: .bold) // Larger font
        nailsLabel.textColor = .black
        nailsLabel.textAlignment = .center
        nailsLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nailsLabel)

        // Remove tapToHammerLabel setup
        // tapToHammerLabel = UILabel()
        // ...

        // Constraints
        NSLayoutConstraint.activate([
            nailsLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 30), // More space top
            nailsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            nailsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            // Remove tapToHammerLabel constraints
            // tapToHammerLabel.bottomAnchor.constraint(equalTo: hammerButton.topAnchor, constant: -15), // Position above button
            // tapToHammerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    // MARK: - Game Actions

    // Original handleTap is no longer needed if using the button's touchDown event
    //@objc func handleTap(_ gestureRecognize: UIGestureRecognizer) {
    //    hammerAction() // Call the consolidated action
    //}

    // *** MODIFIED animateHammerSwing ***
    func animateHammerSwing() {
        // Get the pivot node (the one that actually rotates)
        guard let pivotNode = hammerNode.childNodes.first else { return }

        // --- Interrupt previous animations ---
        pivotNode.removeAction(forKey: hammerAnimationKey)
        nailNode.removeAction(forKey: nailAnimationKey)
        // Reset nail position slightly before new animation for consistency
        // (Optional, but can prevent slight drift if spammed very fast)
         nailNode.position.y = -0.5 // Reset to original y

        // --- Define New Animations ---
        let swingDuration = 0.05
        let impactDuration = 0.03 // Make impact faster
        let returnDuration = 0.06
        let nailBounceBack: Float = 1.5 // How much nail moves per hit
        let nailMoveDown: Float = 0 // Small bounce

        // Swing down (fast) - rotate around Z-axis to hit nail head
        // Adjust the angle to visually connect with the nail head
        let swingDown = SCNAction.rotateTo(x: 0, y: 0, z: .pi / 2.5, duration: swingDuration)
        swingDown.timingMode = .easeIn

        // Return to original position (slower)
        let returnUp = SCNAction.rotateTo(x: 0, y: 0, z: CGFloat(Float.pi) / 12, duration: returnDuration) // Return to resting angle
        returnUp.timingMode = .easeOut

        // Combine actions for Hammer
        // Removed the intermediate bounce for faster cycle
        let swingSequence = SCNAction.sequence([swingDown, returnUp])

        // Nail impact effect: Move down quickly, then bounce back slightly
        let nailDownAction = SCNAction.moveBy(x: 0, y: CGFloat(nailMoveDown), z: 0, duration: impactDuration)
        nailDownAction.timingMode = .easeIn
        let nailUpAction = SCNAction.moveBy(x: 0, y: CGFloat(nailBounceBack), z: 0, duration: returnDuration) // Slower return
        nailUpAction.timingMode = .easeOut

        // Add a small delay before nail moves to sync with hammer impact
        let waitAction = SCNAction.wait(duration: swingDuration * 0.8) // Wait slightly less than swing down

        let nailSequence = SCNAction.sequence([waitAction, nailDownAction, nailUpAction])


        // --- Run New Animations with Keys ---
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
