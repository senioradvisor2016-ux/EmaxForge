import SwiftUI

/// Displays a waveform visualization of sample data with playback position
struct WaveformView: View {
    let samples: [Float]
    var playbackProgress: Double = 0
    var accentColor: Color = Theme.accent
    
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let midY = h / 2
            ZStack {
                // Background
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.3))
                
                // Center line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: midY))
                    path.addLine(to: CGPoint(x: w, y: midY))
                }
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                
                // Waveform bars
                Canvas { context, size in
                    let barW = size.width / CGFloat(max(samples.count, 1))
                    let playbackX = size.width * CGFloat(playbackProgress)
                    
                    for (i, sample) in samples.enumerated() {
                        let x = CGFloat(i) * barW
                        let barHeight = CGFloat(sample) * (size.height * 0.8)
                        let halfBar = barHeight / 2
                        
                        let rect = CGRect(
                            x: x,
                            y: size.height / 2 - halfBar,
                            width: max(barW - 0.5, 0.5),
                            height: max(barHeight, 0.5)
                        )
                        
                        // Color: played portion uses accent, unplayed is dimmer
                        let color: Color = x < playbackX
                            ? accentColor
                            : accentColor.opacity(0.35)
                        
                        context.fill(
                            Path(roundedRect: rect, cornerRadius: barW > 3 ? 1 : 0),
                            with: .color(color)
                        )
                    }
                }
                
                // Playback position indicator
                if playbackProgress > 0 && playbackProgress < 1 {
                    Path { path in
                        let x = w * CGFloat(playbackProgress)
                        path.move(to: CGPoint(x: x, y: 2))
                        path.addLine(to: CGPoint(x: x, y: h - 2))
                    }
                    .stroke(Color.white.opacity(0.8), lineWidth: 1.5)
                }
            }
        }
    }
}

/// Compact inline waveform for list rows
struct MiniWaveformView: View {
    let samples: [Float]
    var color: Color = Theme.accent
    
    var body: some View {
        Canvas { context, size in
            let barW = size.width / CGFloat(max(samples.count, 1))
            
            for (i, sample) in samples.enumerated() {
                let x = CGFloat(i) * barW
                let barHeight = CGFloat(sample) * (size.height * 0.85)
                let halfBar = barHeight / 2
                
                let rect = CGRect(
                    x: x,
                    y: size.height / 2 - halfBar,
                    width: max(barW - 0.3, 0.3),
                    height: max(barHeight, 0.3)
                )
                
                context.fill(Path(rect), with: .color(color.opacity(0.6)))
            }
        }
    }
}

// Preview available in Xcode:
// #Preview("Waveform") {
//     VStack(spacing: 20) {
//         WaveformView(
//             samples: (0..<200).map { _ in Float.random(in: 0...1) },
//             playbackProgress: 0.4
//         )
//         .frame(height: 80)
//     }
//     .padding()
//     .background(.black)
// }
