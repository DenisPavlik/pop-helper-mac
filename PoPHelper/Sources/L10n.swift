import Foundation

/// UI strings. Tweak names/descriptions are localized in tweaks.json;
/// this covers everything else.
enum L10n {
    static let appTitle = LocalizedText(en: "PoP Helper", uk: "PoP Helper")
    static let modFolder = LocalizedText(en: "Mod folder", uk: "Папка мода")
    static let chooseFolder = LocalizedText(en: "Choose…", uk: "Вибрати…")
    static let modFolderMissing = LocalizedText(
        en: "Mod folder not found. Choose the Prophesy of Pendor module folder.",
        uk: "Папку мода не знайдено. Вибери папку модуля Prophesy of Pendor.")
    static let applyChanges = LocalizedText(en: "Apply changes", uk: "Застосувати зміни")
    static let discard = LocalizedText(en: "Discard", uk: "Скасувати")
    static let appliedMessage = LocalizedText(
        en: "Applied %d change(s). Backup: %@",
        uk: "Застосовано змін: %d. Бекап: %@")
    static let statusApplied = LocalizedText(en: "Applied", uk: "Застосовано")
    static let statusNotApplied = LocalizedText(en: "Off", uk: "Вимкнено")
    static let statusConflict = LocalizedText(en: "Conflict", uk: "Конфлікт")
    static let statusModified = LocalizedText(en: "Pending", uk: "Очікує")
    static let original = LocalizedText(en: "vanilla", uk: "стандартно")
    static let backups = LocalizedText(en: "Backups", uk: "Бекапи")
    static let restoreLatestBackup = LocalizedText(en: "Restore latest backup", uk: "Відновити останній бекап")
    static let openBackupsFolder = LocalizedText(en: "Open backups folder", uk: "Відкрити папку бекапів")
    static let noBackups = LocalizedText(en: "No backups yet", uk: "Бекапів ще немає")
    static let restoredMessage = LocalizedText(en: "Restored backup %@", uk: "Відновлено бекап %@")
    static let conflictHelp = LocalizedText(
        en: "This file doesn't match the pristine 3.9.5 layout nor a known tweaked form — it was likely edited by another tool. The app won't touch it.",
        uk: "Файл не збігається ні з оригіналом 3.9.5, ні з відомою твікнутою формою — схоже, його змінила інша програма. Додаток його не чіпатиме.")

    static func categoryName(_ category: String) -> LocalizedText {
        switch category {
        case "spawns": return LocalizedText(en: "Spawns & parties", uk: "Спавни та загони")
        case "tournaments": return LocalizedText(en: "Tournaments", uk: "Турніри")
        case "noldor": return LocalizedText(en: "Noldor", uk: "Нолдори")
        case "companions": return LocalizedText(en: "Companions", uk: "Компаньйони")
        case "prisoners": return LocalizedText(en: "Prisoners", uk: "Полонені")
        case "economy": return LocalizedText(en: "Economy", uk: "Економіка")
        default: return LocalizedText(en: "Other", uk: "Інше")
        }
    }
}
