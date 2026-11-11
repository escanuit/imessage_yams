// Vérification de la logique de jeu, sans Xcode :
//   swiftc YamsMessages/Game.swift Tests/main.swift -o /tmp/yams-tests && /tmp/yams-tests
import Foundation

var failures = 0
func expect(_ condition: @autoclosure () -> Bool, _ label: String, line: Int = #line) {
    if !condition() { failures += 1; print("ÉCHEC ligne \(line): \(label)") }
}

// Barème
expect(Category.fullHouse.score([2, 2, 3, 3, 3]) == 30, "full")
expect(Category.fullHouse.score([3, 3, 3, 3, 3]) == 0, "un yams n'est pas un full")
expect(Category.smallStraight.score([5, 3, 1, 2, 4]) == 25, "petite suite 1-2-3-4-5")
expect(Category.smallStraight.score([2, 3, 4, 5, 6]) == 0, "2-3-4-5-6 n'est pas une petite suite")
expect(Category.smallStraight.score([1, 2, 3, 4, 4]) == 0, "quatre dés qui se suivent ne suffisent pas")
expect(Category.largeStraight.score([6, 2, 4, 3, 5]) == 25, "grande suite 2-3-4-5-6")
expect(Category.largeStraight.score([1, 2, 3, 4, 5]) == 0, "1-2-3-4-5 n'est pas une grande suite")
expect(Category.largeStraight.score([1, 2, 3, 4, 6]) == 0, "pas de grande suite")
expect(Category.allCases.count == 12 && Game.turnCount == 24, "12 cases, pas de Chance")
expect(Category.yams.score([4, 4, 4, 4, 4]) == 50, "yams")
expect(Category.threeOfAKind.score([5, 5, 5, 1, 2]) == 18, "brelan")
expect(Category.fourOfAKind.score([5, 5, 5, 1, 2]) == 0, "pas de carré")
expect(Category.fourOfAKind.score([6, 6, 6, 6, 2]) == 40, "carré")
expect(Category.fourOfAKind.score([3, 3, 3, 3, 3]) == 40, "un yams vaut aussi un carré")
expect(Category.aces.score([1, 1, 3, 4, 1]) == 3, "as")

// Tirage : déterministe, équilibré, identique à la version web
var fixed = Game(); fixed.seed = 123_456_789; fixed.turn = 4
expect((0..<5).map { fixed.die($0, roll: 2) } == (0..<5).map { fixed.die($0, roll: 2) }, "tirage déterministe")
if CommandLine.arguments.count > 1 {
    let web = CommandLine.arguments[1].split(separator: ",").compactMap { Int($0) }
    expect((0..<5).map { fixed.die($0, roll: 2) } == web, "même tirage que la version web")
}
var frequency = [Int](repeating: 0, count: 7)
for seed in 0..<2000 {
    var game = Game(); game.seed = UInt32(seed) &* 7919
    for i in 0..<30 { game.turn = i % 24; frequency[game.die(i % 5, roll: 1 + i % 3)] += 1 }
}
expect(frequency[1...6].allSatisfy { abs($0 - 10_000) < 500 }, "dés équilibrés \(frequency)")

// Tour : les dés gardés ne bougent pas, 3 lancers maximum
var game = Game()
var turn = TurnState()
turn.toggleHold(0); expect(turn.held[0] == false, "rien à garder avant le premier lancer")
turn.roll(in: game)
let firstDie = turn.dice[0]
turn.toggleHold(0); turn.roll(in: game)
expect(turn.dice[0] == firstDie, "dé gardé conservé")
turn.roll(in: game); turn.roll(in: game)
expect(turn.rolls == 3 && turn.rollsLeft == 0, "3 lancers maximum")
expect(turn.dice.allSatisfy { (1...6).contains($0) }, "valeurs de dés")

// Mémorisation du tour : rouvrir le message ne rend pas les lancers
let defaults = UserDefaults(suiteName: "yams-tests-\(game.id)")!
turn.save(for: game, defaults: defaults)
expect(TurnState.load(for: game, defaults: defaults) == turn, "tour mémorisé")
expect(TurnState.load(for: Game(), defaults: defaults) == TurnState(), "autre partie : tour vierge")

// Partie complète, en passant par l'URL à chaque coup comme entre deux téléphones
while !game.isOver {
    let player = game.currentPlayer
    var state = TurnState()
    state.roll(in: game)
    let free = Category.allCases.filter { game.scores[player][$0.rawValue] == nil }
    let best = free.max { $0.score(state.dice) < $1.score(state.dice) }!
    let before = game.turn
    game.play(best, dice: state.dice)
    expect(game.turn == before + 1 && game.last?.player == player, "coup joué")
    game.play(best, dice: state.dice) // case déjà prise par l'autre ou non : ne doit jamais écraser
    guard let received = Game(url: game.url) else { expect(false, "URL illisible: \(game.url)"); break }
    expect(received == game, "aller-retour par l'URL au tour \(game.turn)")
    game = received
}
expect(game.turn == Game.turnCount, "24 tours")
expect(game.scores.allSatisfy { $0.allSatisfy { $0 != nil } }, "feuilles complètes")
for player in 0...1 {
    let sum = game.scores[player].compactMap { $0 }.reduce(0, +)
    expect(game.total(player) == sum + (game.upperTotal(player) >= 63 ? 35 : 0), "total joueur \(player)")
}

// Bonus
var bonus = Game()
for category in Category.upper { bonus.scores[0][category.rawValue] = (category.rawValue + 1) * 3 }
expect(bonus.upperTotal(0) == 63 && bonus.hasBonus(0) && bonus.total(0) == 98, "bonus à 63")
bonus.scores[0][0] = 2
expect(!bonus.hasBonus(0) && bonus.total(0) == 62, "pas de bonus à 62")

// URL invalides
expect(Game(url: URL(string: "https://example.com/")!) == nil, "URL sans partie")
expect(Game(url: URL(string: "https://x.invalid/?g=a&s=1&t=99&f=0&a=-&b=-")!) == nil, "URL incohérente")
var tampered = URLComponents(url: Game().url, resolvingAgainstBaseURL: false)!
tampered.queryItems = tampered.queryItems!.map { $0.name == "t" ? URLQueryItem(name: "t", value: "3") : $0 }
expect(Game(url: tampered.url!) == nil, "nombre de tours incohérent avec les cases remplies")

print(failures == 0 ? "OK — tous les tests passent" : "\(failures) échec(s)")
exit(failures == 0 ? 0 : 1)
