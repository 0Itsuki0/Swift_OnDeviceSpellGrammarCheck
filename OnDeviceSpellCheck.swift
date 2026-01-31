
import SwiftUI
import NaturalLanguage

class SpellCheckingService {
    let checker = NSSpellChecker.shared
    
    init() {
        // the spell checker will automatically identify languages and call `availableLanguages` as necessary
        // otherwise, it will use the language set by setLanguage(_:).
        self.checker.automaticallyIdentifiesLanguages = true
    }
    
    func countWords(_ text: String) -> Int {
        return self.checker.countWords(in: text, language: nil)
    }
    
    
    
    // MARK: - spelling check
    
    // returning: a list of NSRange containing the mis-spelled words
    func checkSpelling(_ text: String) -> [NSRange] {
        guard !text.isEmpty else {
            return []
        }
        var misSpelledRanges: [NSRange] = []
        var offset = 0
        while offset < text.count {
            guard let range = self.checkSpelling(text, startingAt: offset) else {
                break
            }
            misSpelledRanges.append(range)
            offset += range.upperBound
        }
        
        
        return misSpelledRanges
    }
    
    func checkSpelling(_ text: String, ignoreWords words: [String]) -> [NSRange] {
        guard !words.isEmpty else {
            return self.checkSpelling(text)
        }
        guard !text.isEmpty else {
            return []
        }
        
        let documentTag = NSSpellChecker.uniqueSpellDocumentTag()
        defer {
            checker.closeSpellDocument(withTag: documentTag)
        }
        checker.setIgnoredWords(words, inSpellDocumentWithTag: documentTag)

        var misSpelledRanges: [NSRange] = []
        var offset = 0
        while offset < text.count {
            guard let range = self.checkSpelling(text, startingAt: offset, documentTag: documentTag) else {
                break
            }
            misSpelledRanges.append(range)
            offset += range.upperBound
        }
                
        return misSpelledRanges
    }
    
    func checkSpellingWithGuess(_ text: String, ignoreWords words: [String]) -> [(NSRange, [String])] {
        guard !text.isEmpty else {
            return []
        }
        
        let documentTag = NSSpellChecker.uniqueSpellDocumentTag()
        defer {
            checker.closeSpellDocument(withTag: documentTag)
        }
        checker.setIgnoredWords(words, inSpellDocumentWithTag: documentTag)

        var misSpelledRanges: [(NSRange, [String])] = []
        var offset = 0
        while offset < text.count {
            guard let range = self.checkSpelling(text, startingAt: offset, documentTag: documentTag) else {
                break
            }
            let guess = self.checker.guesses(forWordRange: range, in: text, language: nil, inSpellDocumentWithTag: documentTag) ?? []
            misSpelledRanges.append((range, guess))
            offset += range.upperBound
        }
        
        return misSpelledRanges
    }

    
    private func checkSpelling(_ text: String, startingAt offset: Int, documentTag: Int? = nil) -> NSRange? {
        let range = if let documentTag {
            self.checker.checkSpelling(of: text, startingAt: offset, language: nil, wrap: false, inSpellDocumentWithTag: documentTag, wordCount: nil)
        } else {
            self.checker.checkSpelling(of: text, startingAt: offset)
        }
        if !self.isValidRange(range) {
            return nil
        }
        return range
    }
    
    
    // MARK: - Grammar check
    func checkGrammar(_ text: String, ignoreWords words: [String]) -> [NSRange] {
        guard !text.isEmpty else {
            return []
        }
        
        let documentTag = NSSpellChecker.uniqueSpellDocumentTag()
        defer {
            checker.closeSpellDocument(withTag: documentTag)
        }
        checker.setIgnoredWords(words, inSpellDocumentWithTag: documentTag)

        var misSpelledRanges: [NSRange] = []
        var offset = 0
        while offset < text.count {
            guard let range = self.checkGrammar(text, startingAt: offset, documentTag: documentTag) else {
                break
            }
            misSpelledRanges.append(range)
            offset += range.upperBound
        }
                
        return misSpelledRanges
    }
    
    private func checkGrammar(_ text: String, startingAt offset: Int, documentTag: Int) -> NSRange? {
        var details: NSArray? = nil
        
        let range = self.checker.checkGrammar(of: text, startingAt: offset, language: nil, wrap: true, inSpellDocumentWithTag: documentTag, details: &details)

        if !self.isValidRange(range) {
            return nil
        }
        return range
    }
    
    // MARK: unified checking
    func check(_ text: String, ignoreWords words: [String]) -> [NSTextCheckingResult] {
        guard !text.isEmpty else {
            return []
        }
        
        let documentTag = NSSpellChecker.uniqueSpellDocumentTag()
        defer {
            checker.closeSpellDocument(withTag: documentTag)
        }
        checker.setIgnoredWords(words, inSpellDocumentWithTag: documentTag)

        let result = self.checker.check(text, range: .init(location: 0, length: text.count), types: NSTextCheckingAllTypes, options: [:], inSpellDocumentWithTag: documentTag, orthography: nil, wordCount: nil)
        return result
    }
    
    // MARK: - Learn & Unlearn words
    // Adds the word to the spell checker dictionary to be applied to all checking functions.
    // This is automatically preserved between app launches.
    func learnWords(_ words: [String]) {
        for word in words {
            self.checker.learnWord(word)
        }
    }
    
    func unlearnWords(_ words: [String]) {
        for word in words {
            self.checker.unlearnWord(word)
        }
    }
    
    func hasLearnedWord(_ word: String) -> Bool {
        return self.checker.hasLearnedWord(word)
    }

    // MARK: - AutoCorrection
    func correct(_ text: String, ignoreWords words: [String]) -> String? {
        guard !text.isEmpty else {
            return text
        }
        let range = NSRange(location: 0, length: text.count)
        guard let dominant = NLLanguageRecognizer.dominantLanguage(for: text) else {
            return nil
        }
        let language: String? = if let exact = self.checker.availableLanguages.first(where: {$0 == dominant.rawValue} ) {
            exact
        } else {
            self.checker.availableLanguages.first(where: {$0.localizedCaseInsensitiveContains(dominant.rawValue)})
        }
        guard let language = language else {
            return nil
        }
        let documentTag = NSSpellChecker.uniqueSpellDocumentTag()
        defer {
            checker.closeSpellDocument(withTag: documentTag)
        }
        checker.setIgnoredWords(words, inSpellDocumentWithTag: documentTag)

        let result = self.checker.correction(forWordRange: range, in: text, language: language, inSpellDocumentWithTag: documentTag)
        return result
    }

    
    private func isValidRange(_ range: NSRange) -> Bool {
        return range.location != NSNotFound
    }
}


import Playgrounds

#Playground {
    
    let service = SpellCheckingService()

    // check spelling
    print(service.checkSpelling("Helllo, how's goign")) // [{0, 6}, {14, 5}]
    print(service.checkSpelling("Helllo, how's goign", ignoreWords: ["helllo"])) // [{14, 5}]
    print(service.checkSpellingWithGuess("Helllo, how's goign", ignoreWords: ["helllo"])) // [({14, 5}, ["going", "goings", "coign"])]
    
    // check + correction? Not working. Either for a single word or a sentence.
    print(service.correct("Helllo, how's goign", ignoreWords: []) as Any) // nil
    print(service.correct("Helllo", ignoreWords: []) as Any) // nil

    // check grammar
    print(service.checkGrammar("Me and him was going to the store yesterday.", ignoreWords: []))
    
    // unified check
    print(service.check("Me and him was goign to the store yesterday.", ignoreWords: [])) // [<NSOrthographyCheckingResult: 0x7ce144460>{0, 44}{<NSSimpleOrthography: 0x7cd590e20>{Latn->en}}, <NSSpellCheckingResult: 0x7ce144640>{15, 5}, <NSDateCheckingResult: 0x7cd026b20>{34, 9}{2026-01-28 03:00:00 +0000}]
    
    print(service.check("Me and him was going to the store yesterday.", ignoreWords: [])) // [<NSOrthographyCheckingResult: 0xb2bd84ae0>{0, 44}{<NSSimpleOrthography: 0xb2b1f0ef0>{Latn->en}}, <NSGrammarCheckingResult: 0xb2bd84ba0>{0, 44}, <NSDateCheckingResult: 0xb2b026d60>{34, 9}{2026-01-28 03:00:00 +0000}]
    
    // learn words
    service.learnWords(["helllo"])
    print(service.checkSpelling("Helllo, how's goign")) // [{14, 5}]
    service.unlearnWords(["helllo"])
}
