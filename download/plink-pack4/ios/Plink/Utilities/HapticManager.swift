import Foundation
import UIKit

// MARK: - HapticManager (Pack 4: Rich haptics)
/// Полная система тактильной обратной связи для всех взаимодействий.

@MainActor
final class HapticManager {
    static let shared = HapticManager()
    
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let selection = UISelectionFeedbackGenerator()
    private let notification = UINotificationFeedbackGenerator()
    
    private init() {
        // Pre-warm generators для минимальной задержки
        lightImpact.prepare()
        mediumImpact.prepare()
        selection.prepare()
        notification.prepare()
    }
    
    // MARK: - Impact Feedback
    
    /// Лёгкий тап (кнопки, чипы)
    func tap() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
    }
    
    /// Средний удар (карточки, switches)
    func press() {
        mediumImpact.impactOccurred()
        mediumImpact.prepare()
    }
    
    /// Тяжёлый удар (модалки, alerts)
    func heavyPress() {
        heavyImpact.impactOccurred()
        heavyImpact.prepare()
    }
    
    /// Жёсткий удар (deletes, разрушительные действия)
    func rigid() {
        rigidImpact.impactOccurred()
        rigidImpact.prepare()
    }
    
    /// Мягкий удар (success transitions)
    func soft() {
        softImpact.impactOccurred()
        softImpact.prepare()
    }
    
    // MARK: - Selection Feedback
    
    /// Изменение выбора (segmented controls, pickers)
    func selectionChanged() {
        selection.selectionChanged()
        selection.prepare()
    }
    
    // MARK: - Notification Feedback
    
    /// Успех (логин, отправка сообщения, покупка)
    func success() {
        notification.notificationOccurred(.success)
        notification.prepare()
    }
    
    /// Предупреждение (validation error)
    func warning() {
        notification.notificationOccurred(.warning)
        notification.prepare()
    }
    
    /// Ошибка (network failure, login failed)
    func error() {
        notification.notificationOccurred(.error)
        notification.prepare()
    }
    
    // MARK: - Domain-specific haptics
    
    /// Реакция (эмодзи в комнате)
    func reaction() {
        // Двойной мягкий удар для приятного эффекта
        soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.lightImpact.impactOccurred()
            self?.lightImpact.prepare()
        }
    }
    
    /// Отправка сообщения в чат
    func sendMessage() {
        success()
    }
    
    /// Получение нового сообщения
    func receiveMessage() {
        lightImpact.impactOccurred(intensity: 0.6)
        lightImpact.prepare()
    }
    
    /// Play/pause toggle
    func playToggle() {
        mediumImpact.impactOccurred(intensity: 0.7)
        mediumImpact.prepare()
    }
    
    /// Перемотка
    func seek() {
        rigidImpact.impactOccurred(intensity: 0.5)
        rigidImpact.prepare()
    }
    
    /// Присоединение к комнате
    func joinRoom() {
        // Pattern: soft → medium (как "привет")
        soft()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.mediumImpact.impactOccurred()
            self?.mediumImpact.prepare()
        }
    }
    
    /// Выход из комнаты
    func leaveRoom() {
        // Pattern: medium → soft (как "пока")
        mediumImpact.impactOccurred(intensity: 0.5)
        mediumImpact.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.soft()
        }
    }
    
    /// Лайк (двойной тап)
    func like() {
        lightImpact.impactOccurred()
        lightImpact.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.lightImpact.impactOccurred()
            self?.lightImpact.prepare()
        }
    }
    
    /// Длинное нажатие
    func longPress() {
        // Pattern: подготовка → medium
        lightImpact.impactOccurred(intensity: 0.3)
        lightImpact.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
            self?.mediumImpact.impactOccurred()
            self?.mediumImpact.prepare()
        }
    }
    
    /// Покупка Premium
    func purchase() {
        // Pattern: success + celebration
        notification.notificationOccurred(.success)
        notification.prepare()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.soft()
            self?.softImpact.prepare()
        }
    }
    
    // MARK: - Disabled support
    
    /// Проверить, включены ли haptics в настройках системы
    static var isEnabled: Bool {
        return true // UIKit сам проверяет настройки
    }
}
