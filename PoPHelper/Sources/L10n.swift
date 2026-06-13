import Foundation

/// UI strings. Tweak names/descriptions are localized in tweaks.json / packs.json;
/// this covers everything else. Each string carries en / uk / ru.
enum L10n {
    static let appTitle = LocalizedText(en: "PoP Helper", uk: "PoP Helper", ru: "PoP Helper")
    static let modFolder = LocalizedText(en: "Mod folder", uk: "Папка мода", ru: "Папка мода")
    static let chooseFolder = LocalizedText(en: "Choose…", uk: "Вибрати…", ru: "Выбрать…")
    static let modFolderMissing = LocalizedText(
        en: "Mod folder not found. Choose the Prophesy of Pendor module folder.",
        uk: "Папку мода не знайдено. Вибери папку модуля Prophesy of Pendor.",
        ru: "Папка мода не найдена. Выбери папку модуля Prophesy of Pendor.")
    static let applyChanges = LocalizedText(en: "Apply changes", uk: "Застосувати зміни", ru: "Применить изменения")
    static let discard = LocalizedText(en: "Discard", uk: "Скасувати", ru: "Отменить")
    static let appliedMessage = LocalizedText(
        en: "Applied %d change(s). Backup: %@",
        uk: "Застосовано змін: %d. Бекап: %@",
        ru: "Применено изменений: %d. Бэкап: %@")
    static let statusApplied = LocalizedText(en: "Applied", uk: "Застосовано", ru: "Применено")
    static let statusNotApplied = LocalizedText(en: "Off", uk: "Вимкнено", ru: "Выключено")
    static let statusConflict = LocalizedText(en: "Conflict", uk: "Конфлікт", ru: "Конфликт")
    static let statusModified = LocalizedText(en: "Pending", uk: "Очікує", ru: "Ожидает")
    static let original = LocalizedText(en: "vanilla", uk: "стандартно", ru: "стандартно")
    static let backups = LocalizedText(en: "Backups", uk: "Бекапи", ru: "Бэкапы")
    static let restoreLatestBackup = LocalizedText(en: "Restore latest backup", uk: "Відновити останній бекап", ru: "Восстановить последний бэкап")
    static let openBackupsFolder = LocalizedText(en: "Open backups folder", uk: "Відкрити папку бекапів", ru: "Открыть папку бэкапов")
    static let noBackups = LocalizedText(en: "No backups yet", uk: "Бекапів ще немає", ru: "Бэкапов пока нет")
    static let restoredMessage = LocalizedText(en: "Restored backup %@", uk: "Відновлено бекап %@", ru: "Восстановлен бэкап %@")
    static let resetToDefaults = LocalizedText(en: "Reset to defaults", uk: "Скинути до дефолту", ru: "Сбросить до дефолта")
    static let resetConfirmTitle = LocalizedText(
        en: "Reset all tweaks to vanilla 3.9.5?",
        uk: "Скинути всі твіки до ванільної 3.9.5?",
        ru: "Сбросить все твики до ванильной 3.9.5?")
    static let resetConfirmMessage = LocalizedText(
        en: "This restores every module file to the original, un-tweaked state — including tweaks you applied earlier. Your current files are backed up first, so this can be undone.",
        uk: "Це відновить усі файли моду до оригінального, нетвікнутого стану — включно з твіками, які ти вмикав раніше. Поточні файли спершу зберігаються в бекап, тож дію можна відкотити.",
        ru: "Это вернёт все файлы мода в оригинальное, нетвикнутое состояние — включая твики, которые ты включал раньше. Текущие файлы сначала сохраняются в бэкап, так что действие можно откатить.")
    static let resetConfirmButton = LocalizedText(en: "Reset everything", uk: "Скинути все", ru: "Сбросить всё")
    static let cancel = LocalizedText(en: "Cancel", uk: "Скасувати", ru: "Отмена")
    static let resetDoneMessage = LocalizedText(
        en: "Reset %d files to vanilla. Backup: %@",
        uk: "Скинуто файлів до ванілі: %d. Бекап: %@",
        ru: "Сброшено файлов до ванили: %d. Бэкап: %@")
    static let resetUnavailable = LocalizedText(
        en: "No original files found to reset from. A fresh-install backup or PoP Helper's _backupHelper folder is required.",
        uk: "Не знайдено оригінальних файлів для скидання. Потрібен бекап чистого встановлення або папка _backupHelper від PoP Helper.",
        ru: "Не найдены оригинальные файлы для сброса. Нужен бэкап чистой установки или папка _backupHelper от PoP Helper.")
    static let conflictHelp = LocalizedText(
        en: "This file doesn't match the pristine 3.9.5 layout nor a known tweaked form — it was likely edited by another tool. The app won't touch it.",
        uk: "Файл не збігається ні з оригіналом 3.9.5, ні з відомою твікнутою формою — схоже, його змінила інша програма. Додаток його не чіпатиме.",
        ru: "Файл не совпадает ни с оригиналом 3.9.5, ни с известной твикнутой формой — похоже, его изменила другая программа. Приложение его не тронет.")

    static let allTweaks = LocalizedText(en: "All tweaks", uk: "Усі твіки", ru: "Все твики")
    static let cosmetics = LocalizedText(en: "Cosmetics", uk: "Косметика", ru: "Косметика")
    static let cosmeticsDesc = LocalizedText(
        en: "Visual add-on packs from PoP Helper (faces, crosshair, UI, fonts…). Installing copies files into the mod; your originals are backed up.",
        uk: "Візуальні паки з PoP Helper (обличчя, приціл, інтерфейс, шрифти…). Установка копіює файли в мод; твої оригінали зберігаються в бекап.",
        ru: "Визуальные паки из PoP Helper (лица, прицел, интерфейс, шрифты…). Установка копирует файлы в мод; твои оригиналы сохраняются в бэкап.")
    static let install = LocalizedText(en: "Install", uk: "Встановити", ru: "Установить")
    static let remove = LocalizedText(en: "Remove", uk: "Видалити", ru: "Удалить")
    static let installed = LocalizedText(en: "Installed", uk: "Встановлено", ru: "Установлено")
    static let chooseStyle = LocalizedText(en: "Style", uk: "Варіант", ru: "Вариант")
    static let packUnavailable = LocalizedText(
        en: "Pack files not found in the local library.",
        uk: "Файли пака не знайдено в локальній бібліотеці.",
        ru: "Файлы пака не найдены в локальной библиотеке.")
    static let packInstalled = LocalizedText(en: "Installed pack: %@", uk: "Встановлено пак: %@", ru: "Установлен пак: %@")
    static let packRemoved = LocalizedText(en: "Removed pack: %@", uk: "Видалено пак: %@", ru: "Удалён пак: %@")
    static let categoriesHeader = LocalizedText(en: "Categories", uk: "Категорії", ru: "Категории")
    static let searchPlaceholder = LocalizedText(en: "Search tweaks", uk: "Пошук твіків", ru: "Поиск твиков")
    static let settings = LocalizedText(en: "Manage", uk: "Керування", ru: "Управление")
    static let noMatches = LocalizedText(en: "No tweaks match your search.", uk: "Немає твіків за запитом.", ru: "Нет твиков по запросу.")
    static let summary = LocalizedText(en: "%d on · %d total", uk: "%d увімкнено · %d усього", ru: "%d включено · %d всего")
    static let pendingSummary = LocalizedText(en: "%d pending change(s)", uk: "очікує змін: %d", ru: "ожидает изменений: %d")
    static let noPending = LocalizedText(en: "No pending changes", uk: "Немає змін до застосування", ru: "Нет изменений к применению")
    static let settingsTitle = LocalizedText(en: "Settings", uk: "Налаштування", ru: "Настройки")
    static let appearance = LocalizedText(en: "Appearance", uk: "Вигляд", ru: "Вид")
    static let textSize = LocalizedText(en: "Text size", uk: "Розмір тексту", ru: "Размер текста")
    static let language = LocalizedText(en: "Language", uk: "Мова", ru: "Язык")
    static let preview = LocalizedText(en: "Preview", uk: "Перегляд", ru: "Предпросмотр")
    static let textSizePreview = LocalizedText(
        en: "The quick brown fox — sample heading",
        uk: "Зразок заголовка — як виглядає текст",
        ru: "Образец заголовка — как выглядит текст")

    static func categoryName(_ category: String) -> LocalizedText {
        switch category {
        case "spawns": return LocalizedText(en: "Spawns & parties", uk: "Спавни та загони", ru: "Спавны и отряды")
        case "parties": return LocalizedText(en: "Parties", uk: "Загони", ru: "Отряды")
        case "world": return LocalizedText(en: "World map", uk: "Світ і мапа", ru: "Мир и карта")
        case "battle": return LocalizedText(en: "Battle", uk: "Битви", ru: "Битвы")
        case "troops": return LocalizedText(en: "Troops", uk: "Війська", ru: "Войска")
        case "tournaments": return LocalizedText(en: "Tournaments", uk: "Турніри", ru: "Турниры")
        case "noldor": return LocalizedText(en: "Noldor", uk: "Нолдори", ru: "Нолдоры")
        case "companions": return LocalizedText(en: "Companions", uk: "Компаньйони", ru: "Компаньоны")
        case "prisoners": return LocalizedText(en: "Prisoners", uk: "Полонені", ru: "Пленные")
        case "kingdom": return LocalizedText(en: "Kingdom & orders", uk: "Королівство й ордени", ru: "Королевство и ордены")
        case "economy": return LocalizedText(en: "Economy", uk: "Економіка", ru: "Экономика")
        case "items": return LocalizedText(en: "Items", uk: "Предмети", ru: "Предметы")
        case "quests": return LocalizedText(en: "Quests", uk: "Квести", ru: "Квесты")
        case "cheats": return LocalizedText(en: "Cheats & QoL", uk: "Чити та зручність", ru: "Читы и удобство")
        default: return LocalizedText(en: "Other", uk: "Інше", ru: "Прочее")
        }
    }
}
