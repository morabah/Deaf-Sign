import Foundation
import os.log

struct TimelineUtils {
    static func formatTimeInterval(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60
        let tenths = Int((time.truncatingRemainder(dividingBy: 1)) * 10)
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d.%01d", hours, minutes, seconds, tenths)
        } else {
            return String(format: "%02d:%02d.%01d", minutes, seconds, tenths)
        }
    }
    
    static func validateAndFormatTimeline(_ numbers: [Int]) -> (String, Int)? {
        if numbers.count >= 4 {
            // Handle hours:minutes:seconds format (HH:MM:SS)
            let hours = numbers[0]
            let minutes = numbers[1]
            let seconds = numbers[2...3].reduce(0) { $0 * 10 + $1 }
            
            if hours < 24 && minutes < 60 && seconds < 60 {
                let timeline = "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds))"
                let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
                return (timeline, totalSeconds)
            }
        } else if numbers.count >= 2 {
            // Handle minutes:seconds format (MM:SS)
            let minutes = numbers[0]
            let seconds = numbers[1]
            
            if minutes < 60 && seconds < 60 {
                let timeline = "\(minutes):\(String(format: "%02d", seconds))"
                let totalSeconds = (minutes * 60) + seconds
                return (timeline, totalSeconds)
            }
        }
        
        return nil
    }
}
