import Foundation

/// Configurable filename template for sample export — closes the EMXP feature gap
/// "DEFINE FORMAT OF FILE NAMES CREATED".
///
/// Available variables:
///   {bank}       — Bank name (e.g. "STRINGS")
///   {sample}     — Sample name (e.g. "VIOLIN C3")
///   {index}      — 1-based sample index, zero-padded to 3 digits (e.g. "007")
///   {bankindex}  — 1-based bank index within the disk (e.g. "3")
///   {date}       — ISO-8601 date stamp (YYYY-MM-DD)
///   {key}        — MIDI root key as note name (e.g. "C4", "G#3") — empty if unknown
///
/// Default template: `{sample}` (matches previous behaviour exactly)
///
/// Example templates:
///   `{bank}_{index}_{sample}` → `STRINGS_007_VIOLIN C3`
///   `{bankindex}-{bank}-{sample}` → `3-STRINGS-VIOLIN C3`
///
/// Rules:
///   • All variable names are case-insensitive.
///   • Maximum resolved length: 200 characters (truncated before extension is added).
///   • Illegal filename characters (: / \ * ? " < > |) are removed from each variable
///     before substitution.
///   • If the resolved name is empty after substitution and sanitization, "untitled" is used.
struct SampleFilenameTemplate {

    // MARK: - Well-known templates

    /// Default: just the sample name (matches previous hard-coded behaviour)
    static let `default` = SampleFilenameTemplate("{sample}")

    /// Match EMXP's typical export naming: BankName_Index_SampleName
    static let emxpStyle = SampleFilenameTemplate("{bank}_{index}_{sample}")

    /// Bank and sample (no numeric index)
    static let bankAndSample = SampleFilenameTemplate("{bank}_{sample}")

    /// Bank, MIDI root key, and sample name — useful for multi-sampled instruments
    static let bankKeyAndSample = SampleFilenameTemplate("{bank}_{key}_{sample}")

    // MARK: - Pattern

    /// The pattern string, e.g. "{bank}_{index}_{sample}"
    let pattern: String

    init(_ pattern: String) {
        self.pattern = pattern.isEmpty ? "{sample}" : pattern
    }

    // MARK: - Resolution

    /// Context values for resolving a template.
    struct Context {
        let bankName: String
        let sampleName: String
        let sampleIndex: Int   // 1-based
        let bankIndex: Int     // 1-based position of the bank on the disk
        let date: Date
        let rootKey: Int       // MIDI root key (0–127), or -1 if unknown

        init(bankName: String, sampleName: String, sampleIndex: Int,
             bankIndex: Int, date: Date, rootKey: Int = -1) {
            self.bankName    = bankName
            self.sampleName  = sampleName
            self.sampleIndex = sampleIndex
            self.bankIndex   = bankIndex
            self.date        = date
            self.rootKey     = rootKey
        }
    }

    /// Resolve the template to a filename stem (no extension).
    ///
    /// Each variable is sanitized individually (illegal chars removed, length
    /// capped at 64 characters per variable). The total output is capped at
    /// 200 characters.
    func resolve(context: Context) -> String {
        var result = pattern

        let sanitize = { (s: String, maxLen: Int) -> String in
            let cleaned = SampleFilenameTemplate.removeIllegalChars(s)
                .trimmingCharacters(in: .whitespaces)
            let capped = cleaned.count > maxLen ? String(cleaned.prefix(maxLen)) : cleaned
            return capped
        }

        let dateStr = iso8601Date(context.date)
        let bankSanitized   = sanitize(context.bankName,   64)
        let sampleSanitized = sanitize(context.sampleName, 64)
        let indexStr        = String(format: "%03d", context.sampleIndex)
        let bankIndexStr    = String(context.bankIndex)
        let keyStr          = context.rootKey >= 0 ? SampleFilenameTemplate.midiNoteName(context.rootKey) : ""

        result = result.replacingOccurrences(of: "{bank}",      with: bankSanitized,   options: .caseInsensitive)
        result = result.replacingOccurrences(of: "{sample}",    with: sampleSanitized, options: .caseInsensitive)
        result = result.replacingOccurrences(of: "{index}",     with: indexStr,        options: .caseInsensitive)
        result = result.replacingOccurrences(of: "{bankindex}", with: bankIndexStr,    options: .caseInsensitive)
        result = result.replacingOccurrences(of: "{date}",      with: dateStr,         options: .caseInsensitive)
        result = result.replacingOccurrences(of: "{key}",       with: keyStr,          options: .caseInsensitive)

        // Final sanitization: remove any lingering illegal chars from literal text in the pattern
        result = SampleFilenameTemplate.removeIllegalChars(result)
            .trimmingCharacters(in: .whitespaces)

        // Cap total length
        if result.count > 200 { result = String(result.prefix(200)) }

        // Fallback
        return result.isEmpty ? "untitled" : result
    }

    // MARK: - Helpers

    /// Remove characters that are illegal in macOS / Windows filenames.
    static func removeIllegalChars(_ s: String) -> String {
        let illegal: Set<Character> = [":", "/", "\\", "*", "?", "\"", "<", ">", "|"]
        return String(s.filter { !illegal.contains($0) })
    }

    private func iso8601Date(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")
        return fmt.string(from: date)
    }

    // MARK: - MIDI note name utility

    /// Convert a MIDI note number (0–127) to a note name string (e.g. 60 → "C4", 69 → "A4").
    ///
    /// Uses the standard octave convention where middle C (MIDI 60) = C4.
    static func midiNoteName(_ note: Int) -> String {
        let names = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let clamped = max(0, min(127, note))
        let octave = (clamped / 12) - 1
        let name = names[clamped % 12]
        return "\(name)\(octave)"
    }

    // MARK: - Validate a pattern string

    /// Returns true if the pattern contains at least one recognized variable.
    static func isValid(_ pattern: String) -> Bool {
        let vars = ["{bank}", "{sample}", "{index}", "{bankindex}", "{date}", "{key}"]
        let lower = pattern.lowercased()
        return vars.contains { lower.contains($0) }
    }

    /// Returns the list of variable names recognized in a pattern.
    static func variablesUsed(in pattern: String) -> [String] {
        let vars = ["{bank}", "{sample}", "{index}", "{bankindex}", "{date}", "{key}"]
        let lower = pattern.lowercased()
        return vars.filter { lower.contains($0) }
    }
}
