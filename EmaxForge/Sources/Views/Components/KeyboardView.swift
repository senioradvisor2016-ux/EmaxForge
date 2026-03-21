import SwiftUI

/// Interactive piano keyboard for playing samples at different pitches
struct KeyboardView: View {
    let startOctave: Int
    let octaves: Int
    let activeNote: UInt8?
    let onNoteOn: (UInt8) -> Void
    let onNoteOff: (UInt8) -> Void
    
    init(
        startOctave: Int = 3,
        octaves: Int = 3,
        activeNote: UInt8? = nil,
        onNoteOn: @escaping (UInt8) -> Void,
        onNoteOff: @escaping (UInt8) -> Void = { _ in }
    ) {
        self.startOctave = startOctave
        self.octaves = octaves
        self.activeNote = activeNote
        self.onNoteOn = onNoteOn
        self.onNoteOff = onNoteOff
    }
    
    // White key indices within octave: C=0, D=2, E=4, F=5, G=7, A=9, B=11
    private let whiteNotes: [Int] = [0, 2, 4, 5, 7, 9, 11]
    // Black keys relative to white key position
    private let blackNoteOffsets: [(whiteIndex: Int, semitone: Int)] = [
        (0, 1),   // C#
        (1, 3),   // D#
        (3, 6),   // F#
        (4, 8),   // G#
        (5, 10),  // A#
    ]
    
    private func midiNote(octave: Int, semitone: Int) -> UInt8 {
        UInt8(clamping: (octave + 1) * 12 + semitone)
    }
    
    private func noteName(_ note: UInt8) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = Int(note) / 12 - 1
        let semitone = Int(note) % 12
        return "\(names[semitone])\(octave)"
    }
    
    var body: some View {
        GeometryReader { geo in
            let totalWhiteKeys = octaves * 7
            let whiteKeyWidth = geo.size.width / CGFloat(totalWhiteKeys)
            let blackKeyWidth = whiteKeyWidth * 0.6
            let blackKeyHeight = geo.size.height * 0.6
            
            ZStack(alignment: .topLeading) {
                // White keys
                HStack(spacing: 0) {
                    ForEach(0..<octaves, id: \.self) { octaveOffset in
                        let octave = startOctave + octaveOffset
                        ForEach(whiteNotes, id: \.self) { semitone in
                            let note = midiNote(octave: octave, semitone: semitone)
                            let isActive = activeNote == note
                            let isRootC = semitone == 0
                            
                            WhiteKey(
                                note: note,
                                isActive: isActive,
                                label: isRootC ? "C\(octave)" : nil,
                                width: whiteKeyWidth
                            ) {
                                onNoteOn(note)
                            } onRelease: {
                                onNoteOff(note)
                            }
                        }
                    }
                }
                
                // Black keys
                ForEach(0..<octaves, id: \.self) { octaveOffset in
                    let octave = startOctave + octaveOffset
                    ForEach(blackNoteOffsets, id: \.semitone) { offset in
                        let note = midiNote(octave: octave, semitone: offset.semitone)
                        let isActive = activeNote == note
                        let xPos = CGFloat(octaveOffset * 7 + offset.whiteIndex) * whiteKeyWidth + whiteKeyWidth - blackKeyWidth / 2
                        
                        BlackKey(
                            note: note,
                            isActive: isActive,
                            width: blackKeyWidth,
                            height: blackKeyHeight
                        ) {
                            onNoteOn(note)
                        } onRelease: {
                            onNoteOff(note)
                        }
                        .offset(x: xPos)
                    }
                }
            }
        }
    }
}

// MARK: - White Key

private struct WhiteKey: View {
    let note: UInt8
    let isActive: Bool
    let label: String?
    let width: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 3)
                .fill(isActive || isPressed
                      ? Theme.accent.opacity(0.4)
                      : Color(white: 0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color(white: 0.7), lineWidth: 0.5)
                )
            
            if let label {
                Text(label)
                    .font(.system(size: 8, weight: .medium, design: .rounded))
                    .foregroundStyle(Color(white: 0.5))
                    .padding(.bottom, 4)
            }
        }
        .frame(width: width - 1)
        .padding(.horizontal, 0.5)
        .contentShape(Rectangle())
        .onTapGesture {
            onPress()
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        onPress()
                    }
                }
                .onEnded { _ in
                    isPressed = false
                    onRelease()
                }
        )
    }
}

// MARK: - Black Key

private struct BlackKey: View {
    let note: UInt8
    let isActive: Bool
    let width: CGFloat
    let height: CGFloat
    let onPress: () -> Void
    let onRelease: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(isActive || isPressed
                  ? Theme.accent
                  : Color(white: 0.15))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.3), Color(white: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(isActive || isPressed ? 0 : 0.5)
            )
            .frame(width: width, height: height)
            .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
            .contentShape(Rectangle())
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            onPress()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        onRelease()
                    }
            )
    }
}


