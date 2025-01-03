import AVFoundation
import UIKit
import Vision
import os.log

/// CameraViewController: Manages the camera interface for capturing and processing images.
///
/// Features:
/// - Real-time camera preview
/// - Large capture button with haptic feedback
/// - Exit button to dismiss the camera
/// - Text recognition for timeline extraction
/// - Error handling and logging
///
/// Design Principles:
/// - Minimalist and intuitive UI
/// - Smooth animations and transitions
/// - Accessibility and dark mode support
///
/// - Version: 1.0.0
/// - Author: Nuby Development Team
/// - Copyright: 2024 Nuby App

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void
    
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private var photoOutput: AVCapturePhotoOutput!
    private var feedbackGenerator: UIImpactFeedbackGenerator?
    
    // MARK: - UI Components
    
    private lazy var captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.backgroundColor = UIColor.systemBlue
        button.layer.cornerRadius = 40
        button.layer.borderWidth = 4
        button.layer.borderColor = UIColor.white.cgColor
        button.setImage(UIImage(systemName: "camera.fill"), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(captureButtonTapped), for: .touchUpInside)
        return button
    }()
    
    private lazy var exitButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "xmark.circle.fill")?.withConfiguration(
            UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        ), for: .normal)
        button.tintColor = .white
        button.addTarget(self, action: #selector(exitButtonTapped), for: .touchUpInside)
        return button
    }()
    
    // MARK: - Initialization
    
    init(movie: Movie, onNumbersDetected: @escaping ([Int]) -> Void) {
        self.movie = movie
        self.onNumbersDetected = onNumbersDetected
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        checkCameraPermissions()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }
    
    // MARK: - Camera Setup
    
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
            
            // Configure preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)
            
            // Start the capture session
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
                Logger.log("Camera capture session started", level: .info)
            }
            
            // Setup UI after camera is ready
            setupUI()
        } catch {
            Logger.handle(error, context: "Failed to initialize camera input", level: .error)
        }
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        Logger.log("Setting up camera UI", level: .debug)
        
        // Add capture button
        view.addSubview(captureButton)
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -32),
            captureButton.widthAnchor.constraint(equalToConstant: 80),
            captureButton.heightAnchor.constraint(equalToConstant: 80)
        ])
        
        // Add exit button
        view.addSubview(exitButton)
        exitButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            exitButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            exitButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            exitButton.widthAnchor.constraint(equalToConstant: 44),
            exitButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Add haptic feedback
        feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)
        feedbackGenerator?.prepare()
    }
    
    // MARK: - Actions
    
    @objc private func captureButtonTapped() {
        Logger.log("Capture button tapped", level: .debug)
        feedbackGenerator?.impactOccurred()
        captureImage()
    }
    
    @objc private func exitButtonTapped() {
        Logger.log("Exit button tapped", level: .debug)
        feedbackGenerator?.impactOccurred()
        dismiss(animated: true)
    }
    
    private func captureImage() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
    
    // MARK: - AVCapturePhotoCaptureDelegate
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Logger.log("Failed to capture photo", level: .error)
            return
        }
        
        let normalizedImage = fixImageOrientation(image)
        recognizeTimeline(from: normalizedImage)
    }
    
    // MARK: - Text Recognition
    
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
    
    // MARK: - Helper Methods
    
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
