//
//  LoremIpsumGenerator+Live.swift
//  Prata
//
//  Created by Alexander Cyon on 2022-09-06.
//

import P2PConnection

public extension LoremIpsumGenerator {
    static func live(
        getCached: @escaping @Sendable (String) -> Data?,
        setCached: @escaping @Sendable (Data, String) async -> Void
    ) -> Self {
        return Self { bytesToGenerate, cacheKey in
            let encoding: String.Encoding = .utf8
            
            if
                let cachedData = getCached(cacheKey),
                let cached = String(data: cachedData, encoding: encoding)
            {
                loggerGlobal.debug("LoremIpsumGenerator - found cached for size: \(bytesToGenerate), key: \(cacheKey), actual size: \(cached.count)")
                return cached
            }
            
            let generated: String = await Task {
                do {
                    let newlyGenerated = try Lorem._bytes(
                        minByteCount: Int(0.8*Double(bytesToGenerate)),
                        maxByteCount: Int(1.2*Double(bytesToGenerate))
                    )
                    loggerGlobal.debug("LoremIpsumGenerator - generate LOREM of size: \(bytesToGenerate), actual size: \(newlyGenerated.count)")
                    return newlyGenerated
                } catch {
                    let repeated = "NoLorem"
                    let count = bytesToGenerate / repeated.count
                    let fallback = String(repeating: repeated, count: count)
                    loggerGlobal.debug("LoremIpsumGenerator - failed to generate LOREM of size: \(bytesToGenerate), using fallback string of size: \(fallback.count)")
                    return fallback
                }
            }.value
            
            if let toCache = generated.data(using: encoding) {
                await setCached(toCache, cacheKey)
            } else {
                loggerGlobal.debug("LoremIpsumGenerator - failed to create data from LOREM of size: \(bytesToGenerate), cacheKey: \(cacheKey)")
            }
            
            return generated
        }
    }
}

//
//  LoremIpsumGenerator.swift
//
// Copyright © 2014-2021 Lukas Kubanek.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

// From: https://github.com/lukaskubanek/LoremSwiftum/blob/master/Sources/LoremSwiftum.swift
//
import Foundation

public extension Lorem {
    
    static func bytes(range byteCountRange: ClosedRange<Int>) throws -> String {
        try _bytes(minByteCount: byteCountRange.min()!, maxByteCount: byteCountRange.max()!)
    }
    
    static func bytes(range byteCountRange: Range<Int>) throws -> String {
        try _bytes(minByteCount: byteCountRange.min()!, maxByteCount: byteCountRange.max()!)
    }
    enum Error: Swift.Error {
        case failedToGenerateByteCountAfterSeveralAttempts(minByteCount: Int, maxByteCount: Int)
        case rangeTooNarrowUseLargerDiffBetweenMinAndMax(maxShare: Float, butGot: Float)
    }
    internal static func _bytes(minByteCount: Int, maxByteCount: Int) throws -> String {
        precondition(maxByteCount >= minByteCount)
        let minOfMax = Float(minByteCount) / Float(maxByteCount)
        let maxShare: Float = 0.99
        guard minOfMax <= maxShare else {
            throw Error.rangeTooNarrowUseLargerDiffBetweenMinAndMax(maxShare: maxShare, butGot: minOfMax)
        }
        
        var attempts = 0
        func generateLorem(assumedByteCountPerWord: Float) -> String? {
            func wordCount(byteCount: Int) -> Int {
                Int(Float(byteCount)/assumedByteCountPerWord)
            }
            let minWordCount = wordCount(byteCount: minByteCount)
            let maxWordCount = wordCount(byteCount: maxByteCount)
            
            // "Lorem ipsum dolor sit amet " is 27 bytes
            let alwaysStartWithLoremIpsumDolorSitAmet = minByteCount >= 27
            
            let lorem = Self.words(
                Range(uncheckedBounds: (minWordCount, maxWordCount)),
                alwaysStartWithLoremIpsumDolorSitAmet: alwaysStartWithLoremIpsumDolorSitAmet
            )
            
            guard lorem.count >= minByteCount else {
                return nil
            }
            guard lorem.count <= maxByteCount else {
                return nil
            }
            return lorem
            
        }
        
        let byteCountOfAllWords = allWords.map { $0.count }.reduce(0, +)

        let underEstimatedAverageByteCountPerWord = Float(byteCountOfAllWords) / Float(allWords.count)
    
        
        var byteCountPerWord = underEstimatedAverageByteCountPerWord
        while true {
            defer { attempts += 1 }
            if let lorem = generateLorem(assumedByteCountPerWord: byteCountPerWord) {
                return lorem
            } else {
                if attempts > 30 {
                    throw Error.failedToGenerateByteCountAfterSeveralAttempts(minByteCount: minByteCount, maxByteCount: maxByteCount)
                } // else try again
                
                byteCountPerWord += 0.1
                
            }
            
        }
    }
}

/// A lightweight lorem ipsum generator.
public final class Lorem {
    
    // ======================================================= //
    // MARK: - Text
    // ======================================================= //
    
    /// Generates a single word.
    public static var word: String {
        return allWords.randomElement()!
    }
    
    /// Generates multiple words whose count is defined by the given value.
    ///
    /// - Parameter count: The number of words to generate.
    /// - Returns: The generated words joined by a space character.
    public static func words(
        _ count: Int,
        alwaysStartWithLoremIpsumDolorSitAmet: Bool
    ) -> String {
        return _compose(
            word,
            count: count,
            joinBy: .space,
            alwaysStartWithLoremIpsumDolorSitAmet: alwaysStartWithLoremIpsumDolorSitAmet
        )
    }
    
    /// Generates multiple words whose count is randomly selected from within the given range.
    ///
    /// - Parameter range: The range of number of words to generate.
    /// - Returns: The generated words joined by a space character.
    public static func words(
        _ range: Range<Int>,
        alwaysStartWithLoremIpsumDolorSitAmet: Bool
    ) -> String {
        _compose(
            word,
            count: Int.random(in: range),
            joinBy: .space,
            alwaysStartWithLoremIpsumDolorSitAmet: alwaysStartWithLoremIpsumDolorSitAmet
        )
    }
    
    /// Generates multiple words whose count is randomly selected from within the given closed range.
    ///
    /// - Parameter range: The range of number of words to generate.
    /// - Returns: The generated words joined by a space character.
    public static func words(
        _ range: ClosedRange<Int>,
        alwaysStartWithLoremIpsumDolorSitAmet: Bool
    ) -> String {
        _compose(
            word,
            count: Int.random(in: range),
            joinBy: .space,
            alwaysStartWithLoremIpsumDolorSitAmet: alwaysStartWithLoremIpsumDolorSitAmet
        )
    }
    
    /// Generates a single sentence.
    public static var sentence: String {
        let numberOfWords = Int.random(
            in: minWordsCountInSentence...maxWordsCountInSentence
        )
        
        return _compose(
            word,
            count: numberOfWords,
            joinBy: .space,
            endWith: .dot,
            decorate: { $0.firstLetterCapitalized }
        )
    }
    
    /// Generates multiple sentences whose count is defined by the given value.
    ///
    /// - Parameter count: The number of sentences to generate.
    /// - Returns: The generated sentences joined by a space character.
    public static func sentences(_ count: Int) -> String {
        return _compose(
            sentence,
            count: count,
            joinBy: .space
        )
    }
    
    /// Generates multiple sentences whose count is selected from within the given range.
    ///
    /// - Parameter count: The number of sentences to generate.
    /// - Returns: The generated sentences joined by a space character.
    public static func sentences(_ range: Range<Int>) -> String {
        return _compose(sentence, count: Int.random(in: range), joinBy: .space)
    }
    
    /// Generates multiple sentences whose count is selected from within the given closed range.
    ///
    /// - Parameter count: The number of sentences to generate.
    /// - Returns: The generated sentences joined by a space character.
    public static func sentences(_ range: ClosedRange<Int>) -> String {
        return _compose(sentence, count: Int.random(in: range), joinBy: .space)
    }
    
    /// Generates a single paragraph.
    public static var paragraph: String {
        let numberOfSentences = Int.random(
            in: minSentencesCountInParagraph...maxSentencesCountInParagraph
        )
        
        return _compose(
            sentence,
            count: numberOfSentences,
            joinBy: .space
        )
    }
    
    /// Generates multiple paragraphs whose count is defined by the given value.
    ///
    /// - Parameter count: The number of paragraphs to generate.
    /// - Returns: The generated paragraphs joined by a new line character.
    public static func paragraphs(_ count: Int) -> String {
        return _compose(
            paragraph,
            count: count,
            joinBy: .newLine
        )
    }
    
    /// Generates multiple paragraphs whose count is selected from within the given range.
    ///
    /// - Parameter count: The number of paragraphs to generate.
    /// - Returns: The generated paragraphs joined by a new line character.
    public static func paragraphs(_ range: Range<Int>) -> String {
        return _compose(
            paragraph,
            count: Int.random(in: range),
            joinBy: .newLine
        )
    }
    
    /// Generates multiple paragraphs whose count is selected from within the given closed range.
    ///
    /// - Parameter count: The number of paragraphs to generate.
    /// - Returns: The generated paragraphs joined by a new line character.
    public static func paragraphs(_ range: ClosedRange<Int>) -> String {
        return _compose(
            paragraph,
            count: Int.random(in: range),
            joinBy: .newLine
        )
    }
    
    /// Generates a capitalized title.
    public static var title: String {
        let numberOfWords = Int.random(
            in: minWordsCountInTitle...maxWordsCountInTitle
        )
        
        return _compose(
            word,
            count: numberOfWords,
            joinBy: .space,
            decorate: { $0.capitalized }
        )
    }
    
    // ======================================================= //
    // MARK: - Names
    // ======================================================= //
    
    /// Generates a first name.
    public static var firstName: String {
        return firstNames.randomElement()!
    }
    
    /// Generates a last name.
    public static var lastName: String {
        return lastNames.randomElement()!
    }
    
    /// Generates a full name.
    public static var fullName: String {
        return "\(firstName) \(lastName)"
    }
    
    // ======================================================= //
    // MARK: - Email Addresses & URLs
    // ======================================================= //
    
    /// Generates an email address.
    public static var emailAddress: String {
        let emailDelimiter = emailDelimiters.randomElement()!
        let emailDomain = emailDomains.randomElement()!
        
        return "\(firstName)\(emailDelimiter)\(lastName)@\(emailDomain)".lowercased()
    }
    
    /// Generates a URL.
    public static var url: String {
        let urlScheme = urlSchemes.randomElement()!
        let urlDomain = urlDomains.randomElement()!
        return "\(urlScheme)://\(urlDomain)"
    }
    
    // ======================================================= //
    // MARK: - Tweets
    // ======================================================= //
    
    /// Generates a random tweet which is shorter than 140 characters.
    public static var shortTweet: String {
        return _composeTweet(shortTweetMaxLength)
    }
    
    /// Generates a random tweet which is shorter than 280 characters.
    public static var tweet: String {
        return _composeTweet(tweetMaxLength)
    }
    
}

extension Lorem {
    
    fileprivate enum Separator: String {
        case none = ""
        case space = " "
        case dot = "."
        case newLine = "\n"
    }
    
    fileprivate static func _compose(
        _ provider: @autoclosure () -> String,
        count: Int,
        joinBy middleSeparator: Separator,
        endWith endSeparator: Separator = .none,
        alwaysStartWithLoremIpsumDolorSitAmet: Bool = false,
        decorate decorator: ((String) -> String)? = nil
    ) -> String {
        var string = alwaysStartWithLoremIpsumDolorSitAmet ? "Lorem ipsum dolor sit amet " : ""
        
        for index in 0..<count {
            string += provider()
            
            if (index < count - 1) {
                string += middleSeparator.rawValue
            } else {
                string += endSeparator.rawValue
            }
        }
        
        if let decorator = decorator {
            string = decorator(string)
        }
        
        return string
    }
    
    fileprivate static func _composeTweet(_ maxLength: Int) -> String {
        for numberOfSentences in [4, 3, 2, 1] {
            let tweet = sentences(numberOfSentences)
            if tweet.count < maxLength {
                return tweet
            }
        }
        
        return ""
    }
    
    fileprivate static let minWordsCountInSentence = 4
    fileprivate static let maxWordsCountInSentence = 16
    fileprivate static let minSentencesCountInParagraph = 3
    fileprivate static let maxSentencesCountInParagraph = 9
    fileprivate static let minWordsCountInTitle = 2
    fileprivate static let maxWordsCountInTitle = 7
    fileprivate static let shortTweetMaxLength = 140
    fileprivate static let tweetMaxLength = 280
    
    fileprivate static let allWords = ["alias", "consequatur", "aut", "perferendis", "sit", "voluptatem", "accusantium", "doloremque", "aperiam", "eaque", "ipsa", "quae", "ab", "illo", "inventore", "veritatis", "et", "quasi", "architecto", "beatae", "vitae", "dicta", "sunt", "explicabo", "aspernatur", "aut", "odit", "aut", "fugit", "sed", "quia", "consequuntur", "magni", "dolores", "eos", "qui", "ratione", "voluptatem", "sequi", "nesciunt", "neque", "dolorem", "ipsum", "quia", "dolor", "sit", "amet", "consectetur", "adipisci", "velit", "sed", "quia", "non", "numquam", "eius", "modi", "tempora", "incidunt", "ut", "labore", "et", "dolore", "magnam", "aliquam", "quaerat", "voluptatem", "ut", "enim", "ad", "minima", "veniam", "quis", "nostrum", "exercitationem", "ullam", "corporis", "nemo", "enim", "ipsam", "voluptatem", "quia", "voluptas", "sit", "suscipit", "laboriosam", "nisi", "ut", "aliquid", "ex", "ea", "commodi", "consequatur", "quis", "autem", "vel", "eum", "iure", "reprehenderit", "qui", "in", "ea", "voluptate", "velit", "esse", "quam", "nihil", "molestiae", "et", "iusto", "odio", "dignissimos", "ducimus", "qui", "blanditiis", "praesentium", "laudantium", "totam", "rem", "voluptatum", "deleniti", "atque", "corrupti", "quos", "dolores", "et", "quas", "molestias", "excepturi", "sint", "occaecati", "cupiditate", "non", "provident", "sed", "ut", "perspiciatis", "unde", "omnis", "iste", "natus", "error", "similique", "sunt", "in", "culpa", "qui", "officia", "deserunt", "mollitia", "animi", "id", "est", "laborum", "et", "dolorum", "fuga", "et", "harum", "quidem", "rerum", "facilis", "est", "et", "expedita", "distinctio", "nam", "libero", "tempore", "cum", "soluta", "nobis", "est", "eligendi", "optio", "cumque", "nihil", "impedit", "quo", "porro", "quisquam", "est", "qui", "minus", "id", "quod", "maxime", "placeat", "facere", "possimus", "omnis", "voluptas", "assumenda", "est", "omnis", "dolor", "repellendus", "temporibus", "autem", "quibusdam", "et", "aut", "consequatur", "vel", "illum", "qui", "dolorem", "eum", "fugiat", "quo", "voluptas", "nulla", "pariatur", "at", "vero", "eos", "et", "accusamus", "officiis", "debitis", "aut", "rerum", "necessitatibus", "saepe", "eveniet", "ut", "et", "voluptates", "repudiandae", "sint", "et", "molestiae", "non", "recusandae", "itaque", "earum", "rerum", "hic", "tenetur", "a", "sapiente", "delectus", "ut", "aut", "reiciendis", "voluptatibus", "maiores", "doloribus", "asperiores", "repellat"]
    
    fileprivate static let firstNames = ["Judith", "Angelo", "Margarita", "Kerry", "Elaine", "Lorenzo", "Justice", "Doris", "Raul", "Liliana", "Kerry", "Elise", "Ciaran", "Johnny", "Moses", "Davion", "Penny", "Mohammed", "Harvey", "Sheryl", "Hudson", "Brendan", "Brooklynn", "Denis", "Sadie", "Trisha", "Jacquelyn", "Virgil", "Cindy", "Alexa", "Marianne", "Giselle", "Casey", "Alondra", "Angela", "Katherine", "Skyler", "Kyleigh", "Carly", "Abel", "Adrianna", "Luis", "Dominick", "Eoin", "Noel", "Ciara", "Roberto", "Skylar", "Brock", "Earl", "Dwayne", "Jackie", "Hamish", "Sienna", "Nolan", "Daren", "Jean", "Shirley", "Connor", "Geraldine", "Niall", "Kristi", "Monty", "Yvonne", "Tammie", "Zachariah", "Fatima", "Ruby", "Nadia", "Anahi", "Calum", "Peggy", "Alfredo", "Marybeth", "Bonnie", "Gordon", "Cara", "John", "Staci", "Samuel", "Carmen", "Rylee", "Yehudi", "Colm", "Beth", "Dulce", "Darius", "inley", "Javon", "Jason", "Perla", "Wayne", "Laila", "Kaleigh", "Maggie", "Don", "Quinn", "Collin", "Aniya", "Zoe", "Isabel", "Clint", "Leland", "Esmeralda", "Emma", "Madeline", "Byron", "Courtney", "Vanessa", "Terry", "Antoinette", "George", "Constance", "Preston", "Rolando", "Caleb", "Kenneth", "Lynette", "Carley", "Francesca", "Johnnie", "Jordyn", "Arturo", "Camila", "Skye", "Guy", "Ana", "Kaylin", "Nia", "Colton", "Bart", "Brendon", "Alvin", "Daryl", "Dirk", "Mya", "Pete", "Joann", "Uriel", "Alonzo", "Agnes", "Chris", "Alyson", "Paola", "Dora", "Elias", "Allen", "Jackie", "Eric", "Bonita", "Kelvin", "Emiliano", "Ashton", "Kyra", "Kailey", "Sonja", "Alberto", "Ty", "Summer", "Brayden", "Lori", "Kelly", "Tomas", "Joey", "Billie", "Katie", "Stephanie", "Danielle", "Alexis", "Jamal", "Kieran", "Lucinda", "Eliza", "Allyson", "Melinda", "Alma", "Piper", "Deana", "Harriet", "Bryce", "Eli", "Jadyn", "Rogelio", "Orlaith", "Janet", "Randal", "Toby", "Carla", "Lorie", "Caitlyn", "Annika", "Isabelle", "inn", "Ewan", "Maisie", "Michelle", "Grady", "Ida", "Reid", "Emely", "Tricia", "Beau", "Reese", "Vance", "Dalton", "Lexi", "Rafael", "Makenzie", "Mitzi", "Clinton", "Xena", "Angelina", "Kendrick", "Leslie", "Teddy", "Jerald", "Noelle", "Neil", "Marsha", "Gayle", "Omar", "Abigail", "Alexandra", "Phil", "Andre", "Billy", "Brenden", "Bianca", "Jared", "Gretchen", "Patrick", "Antonio", "Josephine", "Kyla", "Manuel", "Freya", "Kellie", "Tonia", "Jamie", "Sydney", "Andres", "Ruben", "Harrison", "Hector", "Clyde", "Wendell", "Kaden", "Ian", "Tracy", "Cathleen", "Shawn"]
    
    fileprivate static let lastNames = ["Chung", "Chen", "Melton", "Hill", "Puckett", "Song", "Hamilton", "Bender", "Wagner", "McLaughlin", "McNamara", "Raynor", "Moon", "Woodard", "Desai", "Wallace", "Lawrence", "Griffin", "Dougherty", "Powers", "May", "Steele", "Teague", "Vick", "Gallagher", "Solomon", "Walsh", "Monroe", "Connolly", "Hawkins", "Middleton", "Goldstein", "Watts", "Johnston", "Weeks", "Wilkerson", "Barton", "Walton", "Hall", "Ross", "Chung", "Bender", "Woods", "Mangum", "Joseph", "Rosenthal", "Bowden", "Barton", "Underwood", "Jones", "Baker", "Merritt", "Cross", "Cooper", "Holmes", "Sharpe", "Morgan", "Hoyle", "Allen", "Rich", "Rich", "Grant", "Proctor", "Diaz", "Graham", "Watkins", "Hinton", "Marsh", "Hewitt", "Branch", "Walton", "O'Brien", "Case", "Watts", "Christensen", "Parks", "Hardin", "Lucas", "Eason", "Davidson", "Whitehead", "Rose", "Sparks", "Moore", "Pearson", "Rodgers", "Graves", "Scarborough", "Sutton", "Sinclair", "Bowman", "Olsen", "Love", "McLean", "Christian", "Lamb", "James", "Chandler", "Stout", "Cowan", "Golden", "Bowling", "Beasley", "Clapp", "Abrams", "Tilley", "Morse", "Boykin", "Sumner", "Cassidy", "Davidson", "Heath", "Blanchard", "McAllister", "McKenzie", "Byrne", "Schroeder", "Griffin", "Gross", "Perkins", "Robertson", "Palmer", "Brady", "Rowe", "Zhang", "Hodge", "Li", "Bowling", "Justice", "Glass", "Willis", "Hester", "Floyd", "Graves", "Fischer", "Norman", "Chan", "Hunt", "Byrd", "Lane", "Kaplan", "Heller", "May", "Jennings", "Hanna", "Locklear", "Holloway", "Jones", "Glover", "Vick", "O'Donnell", "Goldman", "McKenna", "Starr", "Stone", "McClure", "Watson", "Monroe", "Abbott", "Singer", "Hall", "Farrell", "Lucas", "Norman", "Atkins", "Monroe", "Robertson", "Sykes", "Reid", "Chandler", "Finch", "Hobbs", "Adkins", "Kinney", "Whitaker", "Alexander", "Conner", "Waters", "Becker", "Rollins", "Love", "Adkins", "Black", "Fox", "Hatcher", "Wu", "Lloyd", "Joyce", "Welch", "Matthews", "Chappell", "MacDonald", "Kane", "Butler", "Pickett", "Bowman", "Barton", "Kennedy", "Branch", "Thornton", "McNeill", "Weinstein", "Middleton", "Moss", "Lucas", "Rich", "Carlton", "Brady", "Schultz", "Nichols", "Harvey", "Stevenson", "Houston", "Dunn", "West", "O'Brien", "Barr", "Snyder", "Cain", "Heath", "Boswell", "Olsen", "Pittman", "Weiner", "Petersen", "Davis", "Coleman", "Terrell", "Norman", "Burch", "Weiner", "Parrott", "Henry", "Gray", "Chang", "McLean", "Eason", "Weeks", "Siegel", "Puckett", "Heath", "Hoyle", "Garrett", "Neal", "Baker", "Goldman", "Shaffer", "Choi", "Carver"]
    
    fileprivate static let emailDomains = ["gmail.com", "yahoo.com", "hotmail.com", "email.com", "live.com", "me.com", "mac.com", "aol.com", "fastmail.com", "mail.com"]
    
    fileprivate static let emailDelimiters = ["", ".", "-", "_"]
    
    fileprivate static let urlSchemes = ["http", "https"]
    
    fileprivate static let urlDomains = ["twitter.com", "google.com", "youtube.com", "wordpress.org", "adobe.com", "blogspot.com", "godaddy.com", "wikipedia.org", "wordpress.com", "yahoo.com", "linkedin.com", "amazon.com", "flickr.com", "w3.org", "apple.com", "myspace.com", "tumblr.com", "digg.com", "microsoft.com", "vimeo.com", "pinterest.com", "stumbleupon.com", "youtu.be", "miibeian.gov.cn", "baidu.com", "feedburner.com", "bit.ly"]
    
}

extension String {
    
    fileprivate var firstLetterCapitalized: String {
        guard !isEmpty else { return self }
        return prefix(1).capitalized + dropFirst()
    }
    
}