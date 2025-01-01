import AVFoundation
import UIKit
import Vision

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!
    var feedbackGenerator: UIImpactFeedbackGenerator?

    // Capture button
    private let captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 35
        button.layer.borderWidth = 3
        button.layer.borderColor = UIColor.white.cgColor
        button.setTitle("Capture", for: .normal)
        button.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        button.setTitleColor(.white, for: .normal)
        return button
    }()

    init(movie: Movie, onNumbersDetected: @escaping ([Int]) -> Void) {
        self.movie = movie
        self.onNumbersDetected = onNumbersDetected
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermissions()
        setupCamera()
        setupUI()
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            Logger.log("Camera access authorized", level: .info)
            setupCamera()
        case .notDetermined:
            Logger.log("Requesting camera access permission", level: .info)
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    Logger.log("Camera access permission granted", level: .info)
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    Logger.log("Camera access permission denied", level: .warning)
                }
            }
        default:
            Logger.log("Camera access not available", level: .error)
        }
    }

    private func setupCamera() {
        Logger.log("Setting up camera", level: .debug)
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            Logger.log("Failed to access video capture device", level: .error)
            return
        }
        
        do {
            let videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            } else {
                Logger.log("Failed to add video input to capture session", level: .error)
                return
            }
            
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            } else {
                Logger.log("Failed to add photo output to capture session", level: .error)
                return
            }
            
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                Logger.log("Camera capture session started", level: .info)
            }
        } catch {
            Logger.handle(error, context: "Failed to initialize camera input", level: .error)
        }
    }

    private func setupUI() {
        Logger.log("Setting up camera UI", level: .debug)
        
        // Configure preview layer
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Create a container view for buttons
        let buttonContainer = UIView()
        buttonContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttonContainer)
        
        // Setup exit button
        let exitButton = UIButton(type: .system)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        exitButton.setImage(UIImage(systemName: "xmark.circle.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        ), for: .normal)
        exitButton.tintColor = .white
        exitButton.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        buttonContainer.addSubview(exitButton)
        
        // Setup capture button
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        captureButton.layer.cornerRadius = 35
        captureButton.layer.borderWidth = 3
        captureButton.layer.borderColor = UIColor.white.cgColor
        captureButton.setTitle("Capture", for: .normal)
        captureButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 18)
        captureButton.setTitleColor(.white, for: .normal)
        captureButton.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        buttonContainer.addSubview(captureButton)
        
        // Add blur effect to the button container
        let blurEffect = UIBlurEffect(style: .dark)
        let blurView = UIVisualEffectView(effect: blurEffect)
        blurView.translatesAutoresizingMaskIntoConstraints = false
        buttonContainer.insertSubview(blurView, at: 0)
        
        // Setup constraints
        NSLayoutConstraint.activate([
            // Button container constraints
            buttonContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            buttonContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            buttonContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            buttonContainer.heightAnchor.constraint(equalToConstant: 120),
            
            // Blur view constraints
            blurView.topAnchor.constraint(equalTo: buttonContainer.topAnchor),
            blurView.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: buttonContainer.trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: buttonContainer.bottomAnchor),
            
            // Exit button constraints
            exitButton.topAnchor.constraint(equalTo: buttonContainer.topAnchor, constant: 10),
            exitButton.leadingAnchor.constraint(equalTo: buttonContainer.leadingAnchor, constant: 20),
            exitButton.widthAnchor.constraint(equalToConstant: 44),
            exitButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Capture button constraints
            captureButton.centerXAnchor.constraint(equalTo: buttonContainer.centerXAnchor),
            captureButton.centerYAnchor.constraint(equalTo: buttonContainer.centerYAnchor),
            captureButton.widthAnchor.constraint(equalToConstant: 70),
            captureButton.heightAnchor.constraint(equalToConstant: 70)
        ])
        
        // Add shadow to capture button
        captureButton.layer.shadowColor = UIColor.black.cgColor
        captureButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        captureButton.layer.shadowRadius = 4
        captureButton.layer.shadowOpacity = 0.3
        
        // Add haptic feedback
        feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator?.prepare()
    }
    
    @objc private func exitButtonTapped() {
        Logger.log("Exit button tapped", level: .debug)
        feedbackGenerator?.impactOccurred()
        dismiss(animated: true)
    }
    
    @objc private func captureButtonTapped() {
        Logger.log("Capture button tapped", level: .debug)
        feedbackGenerator?.impactOccurred()
        captureImage()
    }
    
    private func captureImage() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Logger.log("Failed to capture photo", level: .error)
            return
        }

        // Fix image orientation before processing
        let normalizedImage = fixImageOrientation(image)
        recognizeTimeline(from: normalizedImage)
    }

    private func recognizeTimeline(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            Logger.log("Failed to convert UIImage to CGImage", level: .error)
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            if let error = error {
                Logger.handle(error, context: "Text recognition failed", level: .error)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                Logger.log("No text recognized in image", level: .warning)
                return
            }

            var recognizedText = ""
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedText += topCandidate.string + "\n"
                }
            }

            Logger.log("Recognized text from image: \(recognizedText)", level: .debug)

            let time = self?.extractTime(from: recognizedText) ?? "00:00"
            Logger.log("Extracted time: \(time)", level: .debug)

            let numbers = self?.convertTimeToNumbers(time) ?? [0, 0, 0]
            Logger.log("Converted numbers: \(numbers)", level: .debug)

            DispatchQueue.main.async {
                self?.dismiss(animated: true) {
                    self?.onNumbersDetected(numbers)
                }
            }
        }

        request.recognitionLevel = .accurate

        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try requestHandler.perform([request])
            } catch {
                Logger.handle(error, context: "Failed to perform text recognition", level: .error)
            }
        }
    }

    private func extractTime(from text: String) -> String {
        Logger.log("Attempting to extract time from text: \(text)", level: .debug)
        
        let patterns = [
            "\\b\\d{1,2}[:.\\s]\\d{2}\\s*(AM|PM|am|pm)?\\b",
            "\\b(\\d{1,2})[:.\\s](\\d{2})\\b",
            "\\b\\d{4}\\b"
        ]
        
        for (index, pattern) in patterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let range = Range(match.range, in: text) {
                    let timeStr = String(text[range])
                    Logger.log("Time pattern \(index) matched: \(timeStr)", level: .debug)
                    return timeStr
                }
            } catch {
                Logger.handle(error, context: "Regex pattern matching failed", level: .error)
            }
        }
        
        Logger.log("No time pattern matched in the text", level: .warning)
        return "00:00"
    }
    
    private func convertTimeToNumbers(_ time: String) -> [Int] {
        Logger.log("Converting time string: \(time)", level: .debug)
        var numbers = [0, 0, 0] // [hours, minutes, seconds]
        
        // Remove any whitespace and convert to lowercase
        let cleanTime = time.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle 4-digit format (e.g., "0220" for 2:20)
        if cleanTime.count == 4, let timeInt = Int(cleanTime) {
            numbers[0] = timeInt / 100  // Hours
            numbers[1] = timeInt % 100  // Minutes
            Logger.log("Parsed 4-digit time: \(numbers[0]):\(numbers[1])", level: .debug)
            return numbers
        }
        
        // Split by common separators
        let components = cleanTime.components(separatedBy: CharacterSet(charactersIn: ": ."))
            .filter { !$0.isEmpty }
        
        Logger.log("Time components: \(components)", level: .debug)
        
        if components.count >= 2 {
            // Extract hours and minutes
            if let hours = Int(components[0]) {
                numbers[0] = hours
            }
            
            if let minutes = Int(components[1]) {
                numbers[1] = minutes
            }
            
            // Handle AM/PM
            let timeString = cleanTime
            if timeString.contains("pm") && numbers[0] < 12 {
                numbers[0] += 12
            } else if timeString.contains("am") && numbers[0] == 12 {
                numbers[0] = 0
            }
        }
        
        Logger.log("Final converted numbers: \(numbers)", level: .debug)
        return numbers
    }

    private func fixImageOrientation(_ image: UIImage) -> UIImage {
        if image.imageOrientation == .up {
            return image
        }

        UIGraphicsBeginImageContextWithOptions(image.size, false, image.scale)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        let normalizedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        return normalizedImage
    }
}
