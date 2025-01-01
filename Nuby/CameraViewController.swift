import AVFoundation
import UIKit
import Vision

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!

    // Capture button
    private let captureButton: UIButton = {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        button.tintColor = .white
        button.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        button.layer.cornerRadius = 30
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
        setupCaptureButton()
    }

    private func checkCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.setupCamera()
                    }
                } else {
                    print("Camera access denied")
                }
            }
        case .denied, .restricted:
            print("Camera access denied or restricted")
        @unknown default:
            print("Unknown camera permission status")
        }
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.beginConfiguration()

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("No camera available")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            // Add photo output
            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            // Add preview layer
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer.frame = view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            view.layer.addSublayer(previewLayer)

            captureSession.commitConfiguration()
            captureSession.startRunning()
        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    private func setupCaptureButton() {
        // Add capture button to the view
        view.addSubview(captureButton)
        
        // Position the button at the bottom center
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60)
        ])
        
        // Add action to the button
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
    }

    @objc private func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to capture photo")
            return
        }

        // Fix image orientation before processing
        let normalizedImage = fixImageOrientation(image)
        recognizeTimeline(from: normalizedImage)
    }

    private func recognizeTimeline(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            print("Failed to convert UIImage to CGImage")
            return
        }

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("No text recognized")
                return
            }

            var recognizedText = ""
            for observation in observations {
                if let topCandidate = observation.topCandidates(1).first {
                    recognizedText += topCandidate.string + "\n"
                }
            }

            // Log recognized text for debugging
            print("Recognized Text: \(recognizedText)")

            // Extract time from recognized text
            let time = self?.extractTime(from: recognizedText) ?? "00:00"
            print("Extracted Time: \(time)") // Debugging

            let numbers = self?.convertTimeToNumbers(time) ?? [0, 0, 0]
            print("Converted Numbers: \(numbers)") // Debugging

            DispatchQueue.main.async {
                // Dismiss the camera view
                self?.dismiss(animated: true) {
                    // Pass the recognized time back to the parent view
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
                print("Failed to perform text recognition: \(error)")
            }
        }
    }

    private func extractTime(from text: String) -> String {
        // More flexible patterns to match various time formats
        let patterns = [
            "\\b\\d{1,2}[:.\\s]\\d{2}\\s*(AM|PM|am|pm)?\\b",  // Matches "2:20 AM", "2.20 AM", "2 20 AM"
            "\\b(\\d{1,2})[:.\\s](\\d{2})\\b",                // Matches "2:20", "2.20", "2 20"
            "\\b\\d{4}\\b"                                     // Matches "0220" for 2:20
        ]
        
        print("Attempting to extract time from text: \(text)")
        
        for (index, pattern) in patterns.enumerated() {
            do {
                let regex = try NSRegularExpression(pattern: pattern)
                let range = NSRange(location: 0, length: text.utf16.count)
                
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   let range = Range(match.range, in: text) {
                    let timeStr = String(text[range])
                    print("Match found with pattern \(index): \(timeStr)")
                    return timeStr
                }
            } catch {
                print("Regex error with pattern \(index): \(error)")
            }
        }
        
        print("No time pattern matched in the text")
        return "00:00"
    }
    
    private func convertTimeToNumbers(_ time: String) -> [Int] {
        print("Converting time string: \(time)")
        var numbers = [0, 0, 0] // [hours, minutes, seconds]
        
        // Remove any whitespace and convert to lowercase
        let cleanTime = time.lowercased().trimmingCharacters(in: .whitespaces)
        
        // Handle 4-digit format (e.g., "0220" for 2:20)
        if cleanTime.count == 4, let timeInt = Int(cleanTime) {
            numbers[0] = timeInt / 100  // Hours
            numbers[1] = timeInt % 100  // Minutes
            print("Parsed 4-digit time: \(numbers[0]):\(numbers[1])")
            return numbers
        }
        
        // Split by common separators
        let components = cleanTime.components(separatedBy: CharacterSet(charactersIn: ": ."))
            .filter { !$0.isEmpty }
        
        print("Time components: \(components)")
        
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
        
        print("Final converted numbers: \(numbers)")
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
