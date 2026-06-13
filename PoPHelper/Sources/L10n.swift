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
    static let resetToDefaults = LocalizedText(en: "Reset to defaults", uk: "Скинути до дефолту")
    static let resetConfirmTitle = LocalizedText(
        en: "Reset all tweaks to vanilla 3.9.5?",
        uk: "Скинути всі твіки до ванільної 3.9.5?")
    static let resetConfirmMessage = LocalizedText(
        en: "This restores every module file to the original, un-tweaked state — including tweaks you applied earlier. Your current files are backed up first, so this can be undone.",
        uk: "Це відновить усі файли моду до оригінального, нетвікнутого стану — включно з твіками, які ти вмикав раніше. Поточні файли спершу зберігаються в бекап, тож дію можна відкотити.")
    static let resetConfirmButton = LocalizedText(en: "Reset everything", uk: "Скинути все")
    static let cancel = LocalizedText(en: "Cancel", uk: "Скасувати")
    static let resetDoneMessage = LocalizedText(
        en: "Reset %d files to vanilla. Backup: %@",
        uk: "Скинуто файлів до ванілі: %d. Бекап: %@")
    static let resetUnavailable = LocalizedText(
        en: "No original files found to reset from. A fresh-install backup or PoP Helper's _backupHelper folder is required.",
        uk: "Не знайдено оригінальних файлів для скидання. Потрібен бекап чистого встановлення або папка _backupHelper від PoP Helper.")
    static let conflictHelp = LocalizedText(
        en: "This file doesn't match the pristine 3.9.5 layout nor a known tweaked form — it was likely edited by another tool. The app won't touch it.",
        uk: "Файл не збігається ні з оригіналом 3.9.5, ні з відомою твікнутою формою — схоже, його змінила інша програма. Додаток його не чіпатиме.")

    static let allTweaks = LocalizedText(en: "All tweaks", uk: "Усі твіки")
    static let categoriesHeader = LocalizedText(en: "Categories", uk: "Категорії")
    static let searchPlaceholder = LocalizedText(en: "Search tweaks", uk: "Пошук твіків")
    static let settings = LocalizedText(en: "Manage", uk: "Керування")
    static let noMatches = LocalizedText(en: "No tweaks match your search.", uk: "Немає твіків за запитом.")
    static let summary = LocalizedText(en: "%d on · %d total", uk: "%d увімкнено · %d усього")
    static let pendingSummary = LocalizedText(en: "%d pending change(s)", uk: "очікує змін: %d")
    static let noPending = LocalizedText(en: "No pending changes", uk: "Немає змін до застосування")

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
