import Foundation

/// The full set of pet states from the design's state machine.
///
/// `night` is an *overlay* (handled separately) and is not part of this primary
/// enum. The states below are the mutually-exclusive primary states.
enum PetState: String, CaseIterable {
    case idle
    case typing
    case flow
    case deleting
    case thinking
    case sleepy
    case sleeping
    case wakeup
    case record

    /// Higher value = higher priority when several conditions match.
    /// Mirrors the "状态优先级" list in the design doc.
    var priority: Int {
        switch self {
        case .record:   return 9
        case .wakeup:   return 8
        case .flow:     return 7
        case .deleting: return 6
        case .typing:   return 5
        case .thinking: return 4
        case .sleepy:   return 3
        case .sleeping: return 2
        case .idle:     return 1
        }
    }

    /// Human-readable label used in the menu bar / stats.
    var displayName: String {
        switch self {
        case .idle:     return "发呆"
        case .typing:   return "打字中"
        case .flow:     return "心流"
        case .deleting: return "纠结"
        case .thinking: return "思考"
        case .sleepy:   return "犯困"
        case .sleeping: return "睡着了"
        case .wakeup:   return "惊醒"
        case .record:   return "破纪录！"
        }
    }

    /// Emoji shorthand used as a quick visual cue.
    var emoji: String {
        switch self {
        case .idle:     return "😊"
        case .typing:   return "⌨️"
        case .flow:     return "🔥"
        case .deleting: return "😰"
        case .thinking: return "🤔"
        case .sleepy:   return "😪"
        case .sleeping: return "💤"
        case .wakeup:   return "😲"
        case .record:   return "🎉"
        }
    }
}
