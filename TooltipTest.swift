import SwiftUI

@main
struct TooltipTestApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Tooltip Test App")
                .font(.title)
            
            Text("Hover over buttons below — tooltips should appear after 1-2 seconds")
                .foregroundStyle(.secondary)
            
            Divider()
            
            VStack(spacing: 16) {
                // Test 1: Simple button with .help()
                Button("Test Button 1") {
                    print("Clicked 1")
                }
                .help("This is tooltip 1")
                
                // Test 2: Button with icon
                Button(action: {}) {
                    Label("Test Button 2", systemImage: "star.fill")
                }
                .help("This is tooltip 2 with icon")
                
                // Test 3: Icon-only button
                Button(action: {}) {
                    Image(systemName: "trash")
                }
                .help("This is tooltip 3 (icon only)")
                
                // Test 4: Label with .labelStyle(.iconOnly)
                Button(action: {}) {
                    Label("Hidden Text", systemImage: "folder")
                }
                .labelStyle(.iconOnly)
                .help("This is tooltip 4 (.labelStyle + .help)")
                
                // Test 5: Just .labelStyle
                Button(action: {}) {
                    Label("Tooltip from label text", systemImage: "doc")
                }
                .labelStyle(.iconOnly)
            }
            
            Divider()
            
            Text("Expected: Yellow tooltip boxes")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(40)
        .frame(width: 500, height: 500)
    }
}
