import AVFoundation
import UIKit
import Vision

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var photoOutput: AVCapturePhotoOutput!

    // Label to display the recognized timeline
    private let timelineLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.layer.cornerRadius = 10
        label.clipsToBounds = true
        return label
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
        setupCaptureButton()
        setupTimelineLabel()
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
        let captureButton = UIButton(type: .system)
        captureButton.setImage(UIImage(systemName: "camera.circle.fill"), for: .normal)
        captureButton.tintColor = .white
        captureButton.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        captureButton.layer.cornerRadius = 30
        captureButton.addTarget(self, action: #selector(capturePhoto), for: .touchUpInside)
        
        // Add button to the view
        view.addSubview(captureButton)
        
        // Position the button at the bottom center
        captureButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captureButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            captureButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            captureButton.widthAnchor.constraint(equalToConstant: 60),
            captureButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }

    private func setupTimelineLabel() {
        view.addSubview(timelineLabel)
        timelineLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            timelineLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            timelineLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            timelineLabel.widthAnchor.constraint(equalToConstant: 200),
            timelineLabel.heightAnchor.constraint(equalToConstant: 50)
        ])
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

        // Process the image to detect timeline
        recognizeTimeline(from: image)
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

            // Extract timeline from recognized text
            let timeline = self?.extractTimeline(from: recognizedText) ?? "00:00:00"
            DispatchQueue.main.async {
                self?.timelineLabel.text = timeline
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

    private func extractTimeline(from text: String) -> String {
        // Example: Extract a timeline in the format "HH:MM:SS"
        let pattern = "\\b\\d{2}:\\d{2}:\\d{2}\\b"
        let regex = try! NSRegularExpression(pattern: pattern)
        let range = NSRange(location: 0, length: text.utf16.count)

        if let match = regex.firstMatch(in: text, options: [], range: range),
           let range = Range(match.range, in: text) {
            return String(text[range])
        }

        return "00:00:00" // Default if no timeline is found
    }
}