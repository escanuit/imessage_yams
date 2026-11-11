import Messages
import SwiftUI
import UIKit

final class MessagesViewController: MSMessagesAppViewController {
    private let model = GameModel()
    /// Session du message ouvert : la réutiliser fait que chaque coup remplace la bulle précédente.
    private var session: MSSession?

    override func viewDidLoad() {
        super.viewDidLoad()

        let host = UIHostingController(rootView: RootView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        host.view.backgroundColor = .clear
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        host.didMove(toParent: self)

        model.onExpand = { [weak self] in self?.requestPresentationStyle(.expanded) }
        model.onSend = { [weak self] game, dice in self?.send(game, dice: dice) }
    }

    // MARK: - Cycle de vie de la conversation

    override func willBecomeActive(with conversation: MSConversation) {
        super.willBecomeActive(with: conversation)
        model.isCompact = presentationStyle == .compact
        load(conversation.selectedMessage, in: conversation)
    }

    override func didSelect(_ message: MSMessage, conversation: MSConversation) {
        super.didSelect(message, conversation: conversation)
        load(message, in: conversation)
    }

    override func didReceive(_ message: MSMessage, conversation: MSConversation) {
        super.didReceive(message, conversation: conversation)
        // L'autre vient de jouer pendant que la partie est ouverte : on met à jour.
        guard let incoming = message.url.flatMap(Game.init(url:)),
              let shown = model.game, shown.id == incoming.id, incoming.turn > shown.turn else { return }
        load(message, in: conversation)
    }

    override func willTransition(to presentationStyle: MSMessagesAppPresentationStyle) {
        super.willTransition(to: presentationStyle)
        model.isCompact = presentationStyle == .compact
    }

    // MARK: - Lecture et envoi

    private func load(_ message: MSMessage?, in conversation: MSConversation) {
        guard let message, let game = message.url.flatMap(Game.init(url:)) else {
            // Aucune bulle ouverte : on garde la partie en cours d'écran, sinon l'accueil.
            if message == nil, model.game != nil { return }
            session = nil
            model.show(nil, me: 0)
            return
        }
        session = message.session

        // Un message est toujours envoyé par le joueur qui vient de jouer : on en déduit qui je suis.
        let sentByMe = message.senderParticipantIdentifier == conversation.localParticipantIdentifier
        let sender = game.last?.player ?? (1 - game.currentPlayer)
        model.show(game, me: sentByMe ? sender : 1 - sender)
    }

    private func send(_ game: Game, dice: [Int]) {
        guard let conversation = activeConversation, let move = game.last else { return }

        // `$<identifiant>` est remplacé par le prénom du contact dans la bulle.
        let me = "$\(conversation.localParticipantIdentifier.uuidString)"
        let layout = MSMessageTemplateLayout()
        layout.image = BubbleImage.render(dice: dice, game: game)
        layout.caption = "\(me) : \(move.value) pts en \(move.category.name)"
        layout.trailingCaption = "\(game.total(move.player)) – \(game.total(1 - move.player))"
        if game.isOver {
            layout.subcaption = game.winner == nil ? "Partie terminée : égalité !" : "Partie terminée 🏆"
        } else {
            layout.subcaption = "À toi de jouer !"
        }

        // Premier coup d'une partie (ou d'une revanche) : nouvelle bulle.
        let session = (game.turn == 1 ? nil : self.session) ?? MSSession()
        self.session = session
        let message = MSMessage(session: session)
        message.url = game.url
        message.layout = layout
        message.summaryText = game.isOver ? "Yams : partie terminée" : "Yams : à toi de jouer"

        conversation.insert(message) { error in
            if let error { NSLog("Yams: insertion du message impossible: \(error)") }
        }
        // Retour à la conversation : il ne reste qu'à appuyer sur la flèche d'envoi.
        requestPresentationStyle(.compact)
    }
}

/// Image de la bulle : les cinq dés du coup joué sur un tapis vert.
enum BubbleImage {
    static func render(dice: [Int], game: Game) -> UIImage {
        let size = CGSize(width: 600, height: 300)
        return UIGraphicsImageRenderer(size: size).image { context in
            let cg = context.cgContext
            let colors = [UIColor(red: 0.09, green: 0.40, blue: 0.20, alpha: 1).cgColor,
                          UIColor(red: 0.05, green: 0.25, blue: 0.13, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
                cg.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            }

            let title = game.isOver ? "Yams — partie terminée" : "Yams — manche \(game.round) / \(Category.allCases.count)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 30, weight: .bold),
                .foregroundColor: UIColor.white,
            ]
            let titleSize = title.size(withAttributes: attributes)
            title.draw(at: CGPoint(x: (size.width - titleSize.width) / 2, y: 36), withAttributes: attributes)

            let side: CGFloat = 92, gap: CGFloat = 18
            let total = side * 5 + gap * 4
            for (index, value) in dice.enumerated() {
                let rect = CGRect(x: (size.width - total) / 2 + CGFloat(index) * (side + gap), y: 130, width: side, height: side)
                cg.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.35).cgColor)
                UIColor.white.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: side * 0.2).fill()
                cg.setShadow(offset: .zero, blur: 0, color: nil)

                UIColor(white: 0.1, alpha: 1).setFill()
                let cell = side * 0.72 / 3, inset = side * 0.14, pip = cell * 0.7
                for position in Pips.positions(for: value) {
                    let x = rect.minX + inset + CGFloat(position % 3) * cell + (cell - pip) / 2
                    let y = rect.minY + inset + CGFloat(position / 3) * cell + (cell - pip) / 2
                    UIBezierPath(ovalIn: CGRect(x: x, y: y, width: pip, height: pip)).fill()
                }
            }
        }
    }
}
