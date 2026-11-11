import Foundation

/// Les 12 cases de la feuille de score (règles maison : pas de Chance).
enum Category: Int, CaseIterable, Identifiable {
    case aces, twos, threes, fours, fives, sixes
    case threeOfAKind, fourOfAKind, fullHouse, smallStraight, largeStraight, yams

    var id: Int { rawValue }
    static let upper: [Category] = [.aces, .twos, .threes, .fours, .fives, .sixes]
    static let lower: [Category] = [.threeOfAKind, .fourOfAKind, .fullHouse, .smallStraight, .largeStraight, .yams]

    var name: String {
        ["As", "Deux", "Trois", "Quatre", "Cinq", "Six",
         "Brelan", "Carré", "Full", "Petite suite", "Grande suite", "Yams"][rawValue]
    }

    var hint: String {
        switch self {
        case .aces, .twos, .threes, .fours, .fives, .sixes: return "total des \(rawValue + 1)"
        case .threeOfAKind: return "somme"
        case .fourOfAKind: return "40"
        case .fullHouse: return "30"
        case .smallStraight: return "1-2-3-4-5 : 25"
        case .largeStraight: return "2-3-4-5-6 : 25"
        case .yams: return "50"
        }
    }

    /// Points rapportés par `dice` (5 valeurs de 1 à 6) dans cette case.
    func score(_ dice: [Int]) -> Int {
        var counts = [Int](repeating: 0, count: 7)
        for value in dice { counts[value] += 1 }
        let sum = dice.reduce(0, +)
        let most = counts.max() ?? 0

        /// Les cinq dés forment exactement la suite commençant à `start`.
        func isRun(from start: Int) -> Bool {
            (start..<(start + 5)).allSatisfy { counts[$0] == 1 }
        }

        switch self {
        case .aces, .twos, .threes, .fours, .fives, .sixes:
            return counts[rawValue + 1] * (rawValue + 1)
        case .threeOfAKind: return most >= 3 ? sum : 0
        case .fourOfAKind: return most >= 4 ? 40 : 0
        case .fullHouse: return counts.contains(3) && counts.contains(2) ? 30 : 0
        case .smallStraight: return isRun(from: 1) ? 25 : 0
        case .largeStraight: return isRun(from: 2) ? 25 : 0
        case .yams: return most == 5 ? 50 : 0
        }
    }
}

struct Move: Equatable {
    var player: Int
    var category: Category
    var value: Int
}

/// État complet d'une partie. Il voyage dans l'URL de chaque message iMessage :
/// aucun serveur, la conversation est la sauvegarde.
struct Game: Equatable {
    static let turnCount = Category.allCases.count * 2
    static let bonusThreshold = 63
    static let bonus = 35

    var id: String
    var seed: UInt32
    /// `scores[joueur][case]`, `nil` tant que la case est libre.
    var scores: [[Int?]]
    /// Nombre de tours déjà joués (0...24).
    var turn: Int
    /// Joueur qui a commencé.
    var first: Int
    var last: Move?

    init(first: Int = 0) {
        id = String(UInt32.random(in: .min ... .max), radix: 36)
        seed = UInt32.random(in: .min ... .max)
        scores = [[Int?]](repeating: [Int?](repeating: nil, count: Category.allCases.count), count: 2)
        turn = 0
        self.first = first
        last = nil
    }

    var currentPlayer: Int { (first + turn) % 2 }
    var isOver: Bool { turn >= Game.turnCount }
    /// Numéro de manche affiché (1...12).
    var round: Int { min(turn / 2 + 1, Category.allCases.count) }

    func upperTotal(_ player: Int) -> Int {
        Category.upper.reduce(0) { $0 + (scores[player][$1.rawValue] ?? 0) }
    }

    func hasBonus(_ player: Int) -> Bool { upperTotal(player) >= Game.bonusThreshold }

    func total(_ player: Int) -> Int {
        scores[player].reduce(0) { $0 + ($1 ?? 0) } + (hasBonus(player) ? Game.bonus : 0)
    }

    /// Gagnant, ou `nil` en cas d'égalité.
    var winner: Int? {
        let a = total(0), b = total(1)
        return a == b ? nil : (a > b ? 0 : 1)
    }

    /// Valeur d'un dé. Le tirage est entièrement déterminé par la graine de la partie :
    /// rouvrir le message redonne exactement les mêmes dés.
    func die(_ index: Int, roll: Int) -> Int {
        var h = seed
            ^ (UInt32(turn + 1) &* 0x9E37_79B1)
            ^ (UInt32(roll + 1) &* 0x85EB_CA6B)
            ^ (UInt32(index + 1) &* 0xC2B2_AE35)
        h = (h ^ (h >> 16)) &* 0x85EB_CA6B
        h = (h ^ (h >> 13)) &* 0xC2B2_AE35
        h ^= h >> 16
        return Int(h % 6) + 1
    }

    /// Inscrit `dice` dans `category` pour le joueur courant et passe la main.
    mutating func play(_ category: Category, dice: [Int]) {
        guard !isOver, scores[currentPlayer][category.rawValue] == nil else { return }
        let value = category.score(dice)
        let player = currentPlayer
        scores[player][category.rawValue] = value
        last = Move(player: player, category: category, value: value)
        turn += 1
    }
}

// MARK: - Sérialisation dans l'URL du message

extension Game {
    /// Les appareils sans l'extension (un Mac, par exemple) ouvrent cette adresse dans le navigateur.
    static let baseURL = "https://yams.invalid/partie"

    var url: URL {
        var components = URLComponents(string: Game.baseURL)!
        func column(_ player: Int) -> String {
            scores[player].map { $0.map(String.init) ?? "-" }.joined(separator: ".")
        }
        var items = [
            URLQueryItem(name: "g", value: id),
            URLQueryItem(name: "s", value: String(seed)),
            URLQueryItem(name: "t", value: String(turn)),
            URLQueryItem(name: "f", value: String(first)),
            URLQueryItem(name: "a", value: column(0)),
            URLQueryItem(name: "b", value: column(1)),
        ]
        if let last {
            items.append(URLQueryItem(name: "l", value: "\(last.player).\(last.category.rawValue).\(last.value)"))
        }
        components.queryItems = items
        return components.url!
    }

    init?(url: URL) {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        var values: [String: String] = [:]
        for item in items { values[item.name] = item.value }

        func column(_ key: String) -> [Int?]? {
            guard let parts = values[key]?.split(separator: ".", omittingEmptySubsequences: false),
                  parts.count == Category.allCases.count else { return nil }
            var result: [Int?] = []
            for part in parts {
                if part == "-" { result.append(nil); continue }
                guard let value = Int(part), (0...50).contains(value) else { return nil }
                result.append(value)
            }
            return result
        }

        guard let id = values["g"], !id.isEmpty,
              let seed = values["s"].flatMap({ UInt32($0) }),
              let turn = values["t"].flatMap({ Int($0) }), (0...Game.turnCount).contains(turn),
              let first = values["f"].flatMap({ Int($0) }), first == 0 || first == 1,
              let a = column("a"), let b = column("b"),
              a.compactMap({ $0 }).count + b.compactMap({ $0 }).count == turn
        else { return nil }

        self.id = id
        self.seed = seed
        self.turn = turn
        self.first = first
        self.scores = [a, b]
        self.last = nil

        if let parts = values["l"]?.split(separator: ".").map({ Int($0) }), parts.count == 3,
           let player = parts[0], player == 0 || player == 1,
           let raw = parts[1], let category = Category(rawValue: raw),
           let value = parts[2], scores[player][raw] == value {
            last = Move(player: player, category: category, value: value)
        }
    }
}

// MARK: - Tour en cours

/// Dés, dés gardés et nombre de lancers du tour en cours. Mémorisé sur l'appareil
/// pour qu'on ne puisse pas récupérer ses lancers en rouvrant le message.
struct TurnState: Codable, Equatable {
    static let maxRolls = 3

    var dice = [Int](repeating: 0, count: 5)
    var held = [Bool](repeating: false, count: 5)
    var rolls = 0

    var hasRolled: Bool { rolls > 0 }
    var rollsLeft: Int { TurnState.maxRolls - rolls }
    var canHold: Bool { hasRolled && rollsLeft > 0 }

    mutating func roll(in game: Game) {
        guard rollsLeft > 0 else { return }
        rolls += 1
        for index in dice.indices where rolls == 1 || !held[index] {
            dice[index] = game.die(index, roll: rolls)
        }
        if rollsLeft == 0 { held = held.map { _ in false } }
    }

    mutating func toggleHold(_ index: Int) {
        guard canHold else { return }
        held[index].toggle()
    }

    private static func key(_ game: Game) -> String { "turn.\(game.id).\(game.turn)" }

    static func load(for game: Game, defaults: UserDefaults = .standard) -> TurnState {
        guard let data = defaults.data(forKey: key(game)),
              let state = try? JSONDecoder().decode(TurnState.self, from: data),
              state.dice.count == 5, state.held.count == 5, (0...maxRolls).contains(state.rolls)
        else { return TurnState() }
        return state
    }

    func save(for game: Game, defaults: UserDefaults = .standard) {
        if let data = try? JSONEncoder().encode(self) {
            defaults.set(data, forKey: TurnState.key(game))
        }
    }
}
