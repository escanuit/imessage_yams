import SwiftUI
import UIKit

/// Cases (0...8, lues ligne par ligne) occupées par les points d'une face de dé.
enum Pips {
    static func positions(for value: Int) -> [Int] {
        switch value {
        case 1: return [4]
        case 2: return [0, 8]
        case 3: return [0, 4, 8]
        case 4: return [0, 2, 6, 8]
        case 5: return [0, 2, 4, 6, 8]
        case 6: return [0, 2, 3, 5, 6, 8]
        default: return []
        }
    }
}

private enum Palette {
    static let felt = LinearGradient(
        colors: [Color(red: 0.09, green: 0.40, blue: 0.20), Color(red: 0.05, green: 0.25, blue: 0.13)],
        startPoint: .top, endPoint: .bottom)
    static let card = Color(UIColor.secondarySystemGroupedBackground)
    static let accent = Color(red: 0.86, green: 0.15, blue: 0.15)
    static let held = Color.orange
}

struct RootView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Palette.felt.ignoresSafeArea()
            if model.isCompact {
                CompactView(model: model)
            } else if model.game != nil {
                GameView(model: model)
            } else {
                HomeView(model: model)
            }
        }
    }
}

// MARK: - Accueil et vue compacte (à la place du clavier)

private struct HomeView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 14) {
            Text("🎲 Yams").font(.largeTitle.bold()).foregroundColor(.white)
            Text("Joue ton tour, envoie le message.\nL’autre touche la bulle pour jouer le sien.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundColor(.white.opacity(0.85))
            Button("Nouvelle partie") { model.startGame() }
                .buttonStyle(PrimaryButtonStyle())
                .padding(.top, 6)
        }
        .padding(24)
    }
}

private struct CompactView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(spacing: 12) {
            if let game = model.game {
                Text(statusLine(game)).font(.headline).foregroundColor(.white)
                Text("Moi \(game.total(model.me)) – \(game.total(model.other)) Adversaire")
                    .font(.subheadline.monospacedDigit()).foregroundColor(.white.opacity(0.85))
                if model.isMyTurn {
                    Button("Jouer mon tour") { model.onExpand?() }.buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("Voir la feuille de score") { model.onExpand?() }.buttonStyle(SecondaryButtonStyle())
                }
                Button("Nouvelle partie") { model.startGame() }
                    .font(.footnote).foregroundColor(.white.opacity(0.75))
            } else {
                Text("🎲 Yams").font(.title.bold()).foregroundColor(.white)
                Button("Nouvelle partie") { model.startGame() }.buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func statusLine(_ game: Game) -> String {
        if game.isOver { return "Partie terminée" }
        return model.isMyTurn ? "À toi de jouer !" : "Coup prêt : appuie sur la flèche d’envoi ↑"
    }
}

// MARK: - Partie

private struct GameView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        if let game = model.game {
            ScrollView {
                VStack(spacing: 12) {
                    header(game)
                        .padding(14)
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    ScoreCard(model: model, game: game)
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Palette.card)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func header(_ game: Game) -> some View {
        if game.isOver {
            VStack(spacing: 10) {
                Text(resultLine(game)).font(.title2.bold())
                Text("\(game.total(model.me)) – \(game.total(model.other))")
                    .font(.title3.monospacedDigit()).foregroundColor(.secondary)
                Button("Revanche") { model.startGame() }.buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        } else if model.isMyTurn {
            VStack(spacing: 12) {
                VStack(spacing: 2) {
                    Text("À toi de jouer !").font(.headline)
                    Text(lastMoveLine(game)).font(.subheadline).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    ForEach(0..<5, id: \.self) { index in
                        DieView(value: model.turn.dice[index], held: model.turn.held[index])
                            .onTapGesture { model.toggleHold(index) }
                    }
                }
                .padding(.bottom, 6)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: model.turn)

                if let category = model.selected {
                    Button("Marquer \(category.score(model.turn.dice)) en \(category.name)") { model.confirm() }
                        .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button(rollLabel) {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        model.roll()
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(model.turn.rollsLeft == 0)
                }
                Text(hintLine).font(.footnote).foregroundColor(.secondary)
            }
        } else {
            VStack(spacing: 4) {
                Text("Au tour de l’adversaire").font(.headline)
                Text("Envoie le message pour lui passer la main.").font(.subheadline).foregroundColor(.secondary)
                #if DEBUG
                Button("Mode test : jouer l’autre côté") { model.swapSides() }
                    .font(.footnote).padding(.top, 6)
                #endif
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var rollLabel: String {
        let left = model.turn.rollsLeft
        if !model.turn.hasRolled { return "Lancer les dés" }
        if left == 0 { return "Plus de lancer" }
        return "Relancer (\(left) restant\(left > 1 ? "s" : ""))"
    }

    private var hintLine: String {
        if !model.turn.hasRolled { return " " }
        return model.turn.rollsLeft > 0
            ? "Touche les dés à garder, ou choisis une case."
            : "Choisis une case dans ta colonne."
    }

    private func lastMoveLine(_ game: Game) -> String {
        if let last = game.last, last.player == model.other {
            return "L’adversaire a marqué \(last.value) en \(last.category.name)."
        }
        return "Manche \(game.round) sur \(Category.allCases.count)"
    }

    private func resultLine(_ game: Game) -> String {
        guard let winner = game.winner else { return "Égalité ! 🤝" }
        return winner == model.me ? "Tu as gagné ! 🏆" : "Perdu… 🏆 pour l’adversaire"
    }
}

private struct DieView: View {
    let value: Int
    let held: Bool

    var body: some View {
        let pips = Pips.positions(for: value)
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { column in
                        Circle()
                            .fill(Color(white: 0.1))
                            .padding(2)
                            .opacity(pips.contains(row * 3 + column) ? 1 : 0)
                    }
                }
            }
        }
        .padding(8)
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: 68)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous).stroke(held ? Palette.held : Color.clear, lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        .opacity(value == 0 ? 0.35 : 1)
        .offset(y: held ? 8 : 0)
        .accessibilityLabel(value == 0 ? "Dé non lancé" : "Dé \(value)\(held ? ", gardé" : "")")
    }
}

// MARK: - Feuille de score

private struct ScoreCard: View {
    @ObservedObject var model: GameModel
    let game: Game

    private let columnWidth: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                columnTitle("Moi", active: !game.isOver && game.currentPlayer == model.me)
                columnTitle("Adv.", active: !game.isOver && game.currentPlayer == model.other)
            }
            .padding(.vertical, 8)
            Divider()

            ForEach(Category.upper) { row($0) }

            HStack {
                Text("Bonus").fontWeight(.semibold)
                Text("si ≥ 63 : +35").font(.caption).foregroundColor(.secondary)
                Spacer()
                bonusCell(model.me)
                bonusCell(model.other)
            }
            .padding(.vertical, 9)
            Divider()

            ForEach(Category.lower) { row($0) }

            HStack {
                Text("Total").font(.title3.weight(.heavy))
                Spacer()
                Text("\(game.total(model.me))").font(.title3.weight(.heavy).monospacedDigit()).frame(width: columnWidth)
                Text("\(game.total(model.other))").font(.title3.weight(.heavy).monospacedDigit()).frame(width: columnWidth)
            }
            .padding(.vertical, 10)
        }
    }

    private func columnTitle(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundColor(active ? Palette.accent : .secondary)
            .frame(width: columnWidth)
    }

    private func bonusCell(_ player: Int) -> some View {
        Text(game.hasBonus(player) ? "+35" : "\(game.upperTotal(player))/63")
            .font(.subheadline.weight(.semibold).monospacedDigit())
            .frame(width: columnWidth)
    }

    @ViewBuilder
    private func row(_ category: Category) -> some View {
        HStack {
            Text(category.name).lineLimit(1).layoutPriority(1)
            Text(category.hint).font(.caption).foregroundColor(.secondary).lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            myCell(category)
            scoreText(game.scores[model.other][category.rawValue], player: model.other, category: category)
        }
        .padding(.vertical, 5)
        Divider()
    }

    @ViewBuilder
    private func myCell(_ category: Category) -> some View {
        if game.scores[model.me][category.rawValue] == nil, model.canPick {
            let value = category.score(model.turn.dice)
            let isSelected = model.selected == category
            Button { model.select(category) } label: {
                Text("\(value)")
                    .font(.body.monospacedDigit().weight(isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? Color.primary : Color.secondary.opacity(value == 0 ? 0.5 : 0.9))
                    .frame(width: columnWidth, height: 32)
                    .background(isSelected ? Color.yellow.opacity(0.35) : Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(category.name) : \(value) points")
        } else {
            scoreText(game.scores[model.me][category.rawValue], player: model.me, category: category)
        }
    }

    private func scoreText(_ value: Int?, player: Int, category: Category) -> some View {
        let isLast = game.last?.player == player && game.last?.category == category
        return Text(value.map(String.init) ?? "")
            .font(.body.monospacedDigit().weight(isLast ? .bold : .regular))
            .foregroundColor(isLast ? Palette.accent : .primary)
            .frame(width: columnWidth, height: 32)
    }
}

// MARK: - Boutons

private struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.8 : 1) : 0.4)
    }
}

private struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Color.white.opacity(configuration.isPressed ? 0.25 : 0.18))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
