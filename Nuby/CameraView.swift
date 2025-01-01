import SwiftUI

struct CameraView: UIViewControllerRepresentable {
    var movie: Movie
    var onNumbersDetected: ([Int]) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController(movie: movie, onNumbersDetected: onNumbersDetected)
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}
