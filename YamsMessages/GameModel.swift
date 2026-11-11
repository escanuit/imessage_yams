import Foundation
import Combine

/// État affiché par l'interface. Le contrôleur Messages le remplit à l'ouverture d'un message
/// et écoute `onSend` pour glisser le coup joué dans la conversation.
final class GameModel: ObservableObject {
    @Published var game: Game?
    /// Mon index de joueur (0 ou 1) dans la partie affichée.
    @Published var me = 0
    @Published var turn = TurnState()
    @Published var selected: Category?
    @Published var isCompact = true

    /// Appelé quand un coup vient d'être joué : (partie mise à jour, dés du coup).
    var onSend: ((Game, [Int]) -> Void)?
    /// Demande le passage en plein écran.
    var onExpand: (() -> Void)?

    var other: Int { 1 - me }

    var isMyTurn: Bool {
        guard let game else { return false }
        return !game.isOver && game.currentPlayer == me
    }

    var canPick: Bool { isMyTurn && turn.hasRolled }

    func show(_ game: Game?, me: Int) {
        self.game = game
        self.me = me
        selected = nil
        turn = game.map { TurnState.load(for: $0) } ?? TurnState()
    }

    /// Démarre une partie dont je suis le premier joueur.
    func startGame() {
        show(Game(first: 0), me: 0)
        onExpand?()
    }

#if DEBUG
    /// Test en solo (builds Debug uniquement) : prendre la place de l'autre joueur.
    func swapSides() {
        guard let game else { return }
        show(game, me: other)
    }
#endif

    func roll() {
        guard let game, isMyTurn, turn.rollsLeft > 0 else { return }
        turn.roll(in: game)
        turn.save(for: game)
        selected = nil
    }

    func toggleHold(_ index: Int) {
        guard let game, isMyTurn else { return }
        turn.toggleHold(index)
        turn.save(for: game)
    }

    func select(_ category: Category) {
        guard canPick, game?.scores[me][category.rawValue] == nil else { return }
        selected = selected == category ? nil : category
    }

    func confirm() {
        guard var game, canPick, let category = selected else { return }
        let dice = turn.dice
        game.play(category, dice: dice)
        self.game = game
        selected = nil
        turn = TurnState()
        onSend?(game, dice)
    }
}
