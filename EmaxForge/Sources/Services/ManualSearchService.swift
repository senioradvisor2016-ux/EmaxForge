import Foundation

/// Provides searchable manual content for the AI Assistant.
/// Loads pre-extracted text files from the app's Resources or a config directory.
class ManualSearchService {
    
    struct SearchResult {
        let source: String    // "Operations Manual" or "Service Manual"
        let section: String   // Approximate section heading
        let content: String   // Matching text chunk
        let score: Double     // Simple relevance score
    }
    
    private var operationsChunks: [(section: String, text: String)] = []
    private var serviceChunks: [(section: String, text: String)] = []
    private var isLoaded = false
    
    /// Load manuals from ~/.emaxforge/manuals/ directory
    func loadManuals() {
        guard !isLoaded else { return }
        
        let basePath = NSString("~/.emaxforge/manuals").expandingTildeInPath
        
        let opsPath = "\(basePath)/EmaxII_OperationsManual.txt"
        let diagPath = "\(basePath)/EmaxII_Diagnostics.txt"
        
        if let opsText = try? String(contentsOfFile: opsPath, encoding: .utf8) {
            operationsChunks = chunkText(opsText, source: "Operations")
        }
        
        if let diagText = try? String(contentsOfFile: diagPath, encoding: .utf8) {
            serviceChunks = chunkText(diagText, source: "Diagnostics")
        }
        
        isLoaded = true
    }
    
    /// Search both manuals for relevant content
    func search(query: String, maxResults: Int = 5) -> [SearchResult] {
        loadManuals()
        
        let queryWords = query.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { $0.count > 2 }
        
        guard !queryWords.isEmpty else { return [] }
        
        var results: [SearchResult] = []
        
        for chunk in operationsChunks {
            let score = calculateScore(chunk: chunk.text, queryWords: queryWords)
            if score > 0.1 {
                results.append(SearchResult(
                    source: "EMAX II Operations Manual",
                    section: chunk.section,
                    content: chunk.text,
                    score: score
                ))
            }
        }
        
        for chunk in serviceChunks {
            let score = calculateScore(chunk: chunk.text, queryWords: queryWords)
            if score > 0.1 {
                results.append(SearchResult(
                    source: "EMAX II Diagnostics Manual",
                    section: chunk.section,
                    content: chunk.text,
                    score: score
                ))
            }
        }
        
        // Sort by score descending, take top results
        results.sort { $0.score > $1.score }
        return Array(results.prefix(maxResults))
    }
    
    // MARK: - Chunking
    
    /// Split text into ~800 char chunks with section headers
    private func chunkText(_ text: String, source: String) -> [(section: String, text: String)] {
        let lines = text.components(separatedBy: "\n")
        var chunks: [(String, String)] = []
        var currentSection = "Introduction"
        var currentChunk = ""
        let chunkSize = 800
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Detect section headers (ALL CAPS lines or MODULE names)
            if isLikelySectionHeader(trimmed) {
                currentSection = trimmed
            }
            
            currentChunk += line + "\n"
            
            if currentChunk.count >= chunkSize {
                let cleanChunk = currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleanChunk.isEmpty {
                    chunks.append((currentSection, cleanChunk))
                }
                currentChunk = ""
            }
        }
        
        // Final chunk
        let cleanChunk = currentChunk.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleanChunk.isEmpty {
            chunks.append((currentSection, cleanChunk))
        }
        
        return chunks
    }
    
    private func isLikelySectionHeader(_ line: String) -> Bool {
        guard line.count > 3 && line.count < 80 else { return false }
        
        // Known module names
        let moduleNames = ["MASTER", "PRESET DEFINITION", "PRESET MANAGEMENT",
                          "SAMPLE MANAGEMENT", "ANALOG PROCESSING", "DIGITAL PROCESSING",
                          "SEQUENCER", "MIDI", "CALIBRATION", "SPECIFICATIONS",
                          "APPENDIX", "GLOSSARY", "TROUBLESHOOTING"]
        
        for name in moduleNames {
            if line.uppercased().contains(name) { return true }
        }
        
        // ALL CAPS with mostly letters
        let letters = line.filter { $0.isLetter }
        if letters.count > 5 && letters == letters.uppercased() {
            return true
        }
        
        return false
    }
    
    // MARK: - Scoring
    
    /// Simple TF scoring — count how many query words appear in the chunk
    private func calculateScore(chunk: String, queryWords: [String]) -> Double {
        let chunkLower = chunk.lowercased()
        var matchCount = 0
        var totalOccurrences = 0
        
        for word in queryWords {
            if chunkLower.contains(word) {
                matchCount += 1
                // Count occurrences for weighting
                var searchRange = chunkLower.startIndex..<chunkLower.endIndex
                while let range = chunkLower.range(of: word, range: searchRange) {
                    totalOccurrences += 1
                    searchRange = range.upperBound..<chunkLower.endIndex
                }
            }
        }
        
        guard matchCount > 0 else { return 0 }
        
        // Score: % of query words found + bonus for multiple occurrences
        let coverage = Double(matchCount) / Double(queryWords.count)
        let densityBonus = min(Double(totalOccurrences) * 0.02, 0.3)
        
        return coverage + densityBonus
    }
    
    /// Get a context string for the AI from manual search results
    func contextForQuery(_ query: String) -> String? {
        let results = search(query: query, maxResults: 3)
        guard !results.isEmpty else { return nil }
        
        var context = "\n## Relevant Manual Excerpts\n"
        for (i, result) in results.enumerated() {
            context += "\n### [\(result.source)] \(result.section)\n"
            // Trim to ~600 chars per result
            let trimmed = String(result.content.prefix(600))
            context += trimmed + "\n"
            if i >= 2 { break }
        }
        
        return context
    }
}
