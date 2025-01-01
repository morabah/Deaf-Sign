import SwiftUI
import AVFoundation

struct CameraView: UIViewControllerRepresentable {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(movie: movie, onNumbersDetected: onNumbersDetected)
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

class CameraViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void
    var captureSession: AVCaptureSession!
    var photoOutput: AVCapturePhotoOutput!

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
        setupCamera()
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

            photoOutput = AVCapturePhotoOutput()
            if captureSession.canAddOutput(photoOutput) {
                captureSession.addOutput(photoOutput)
            }

            captureSession.commitConfiguration()
            captureSession.startRunning()
        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            print("Failed to capture photo")
            return
        }

        // Process the image to detect numbers
        let numbers = processImage(image)
        onNumbersDetected(numbers)
    }

    private func processImage(_ image: UIImage) -> [Int] {
        // Placeholder for image processing logic
        // Replace this with actual logic to detect numbers from the image
        return [1, 2, 3] // Example output
    }
}