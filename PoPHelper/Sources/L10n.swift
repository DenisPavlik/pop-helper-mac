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
    static let statusAppliedExternally = LocalizedText(en: "Already applied", uk: "Вже застосовано", ru: "Уже применено")
    static let appliedExternallyHelp = LocalizedText(
        en: "This spot in your mod is already modified — most likely the original PoP Helper applied this tweak. It's active in-game; PoP Helper Mac just can't toggle this exact variant.",
        uk: "Це місце у вашому моді вже змінене — найімовірніше, оригінальний PoP Helper уже застосував цей твік. Він активний у грі; PoP Helper Mac просто не може керувати саме цим варіантом.",
        ru: "Это место в вашем моде уже изменено — скорее всего, оригинальный PoP Helper уже применил этот твик. Он активен в игре; PoP Helper Mac просто не может управлять именно этим вариантом.")
    static let statusBlocked = LocalizedText(en: "Locked", uk: "Заблоковано", ru: "Заблокировано")
    static let mutualExclusionHelp = LocalizedText(
        en: "Incompatible with “%@” — they edit the same game data, so only one can be on. Clear that checkbox to enable this one.",
        uk: "Несумісно з «%@» — чіпає ті самі дані гри, тож увімкнути можна лише один. Зніми галочку з нього, щоб увімкнути цей.",
        ru: "Несовместимо с «%@» — меняет те же данные игры, поэтому включить можно только один. Снимите галочку с него, чтобы включить этот.")
    static let statusModified = LocalizedText(en: "Pending", uk: "Очікує", ru: "Ожидает")
    static let original = LocalizedText(en: "vanilla", uk: "стандартно", ru: "стандартно")
    static let recommended = LocalizedText(en: "rec.", uk: "рек.", ru: "рек.")
    static let requiresNewGame = LocalizedText(
        en: "Requires a new game — won't change an existing save retroactively (safe to apply).",
        uk: "Потребує нову гру — на наявний сейв заднім числом не вплине (застосувати безпечно).",
        ru: "Требует новой игры — на существующий сейв задним числом не повлияет (применять безопасно).")
    static let newGameBadge = LocalizedText(en: "new game", uk: "нова гра", ru: "новая игра")
    static let recommendedFull = LocalizedText(
        en: "Suggested value — a safe orientation if you don't know the mechanic.",
        uk: "Рекомендоване значення — безпечний орієнтир, якщо не знаєш механіку.",
        ru: "Рекомендуемое значение — безопасный ориентир, если не знаешь механику.")
    static let backups = LocalizedText(en: "Backups", uk: "Бекапи", ru: "Бэкапы")
    static let restoreLatestBackup = LocalizedText(en: "Restore latest backup", uk: "Відновити останній бекап", ru: "Восстановить последний бэкап")
    static let openBackupsFolder = LocalizedText(en: "Open backups folder", uk: "Відкрити папку бекапів", ru: "Открыть папку бэкапов")
    static let noBackups = LocalizedText(en: "No backups yet", uk: "Бекапів ще немає", ru: "Бэкапов пока нет")
    static let restoredMessage = LocalizedText(en: "Restored backup %@", uk: "Відновлено бекап %@", ru: "Восстановлен бэкап %@")
    static let resetToDefaults = LocalizedText(en: "Undo all tweaks", uk: "Скасувати всі твіки", ru: "Отменить все твики")
    static let reverify = LocalizedText(
        en: "Re-verify against game files",
        uk: "Перевірити за файлами гри",
        ru: "Проверить по файлам игры")
    static let resetConfirmTitle = LocalizedText(
        en: "Undo all PoP Helper tweaks?",
        uk: "Скасувати всі твіки PoP Helper?",
        ru: "Отменить все твики PoP Helper?")
    static let resetConfirmMessage = LocalizedText(
        en: "This restores your mod to how it was before PoP Helper first touched it — keeping any other mods you had installed, but removing every tweak. Your current files are backed up first, so this can be undone.",
        uk: "Це поверне твій мод до стану, яким він був до першого запуску PoP Helper — зберігаючи інші встановлені моди, але прибираючи всі твіки. Поточні файли спершу зберігаються в бекап, тож дію можна відкотити.",
        ru: "Это вернёт твой мод к состоянию до первого запуска PoP Helper — сохраняя другие установленные моды, но убирая все твики. Текущие файлы сначала сохраняются в бэкап, так что действие можно откатить.")
    static let resetConfirmButton = LocalizedText(en: "Undo all tweaks", uk: "Скасувати всі твіки", ru: "Отменить все твики")
    static let cancel = LocalizedText(en: "Cancel", uk: "Скасувати", ru: "Отмена")
    static let resetDoneMessage = LocalizedText(
        en: "Restored %d files to your pre-tweak mod. Backup: %@",
        uk: "Відновлено файлів до твого мода без твіків: %d. Бекап: %@",
        ru: "Восстановлено файлов до твоего мода без твиков: %d. Бэкап: %@")
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

    // MARK: Performance (rgl_config.txt)
    static let performanceTitle = LocalizedText(en: "Performance", uk: "Продуктивність", ru: "Производительность")
    static let performanceDesc = LocalizedText(
        en: "These graphics options also live in the game's own Video menu. Here PoP Helper just sets the values that work best on your Mac — in one click.",
        uk: "Ці налаштування графіки є і в самій грі (Options → Video). Тут PoP Helper лише виставляє значення, які найкраще працюють на твоєму Mac — одним кліком.",
        ru: "Эти настройки графики есть и в самой игре (Options → Video). Здесь PoP Helper просто выставляет значения, которые лучше всего работают на твоём Mac — одним кликом.")
    static let yourMac = LocalizedText(en: "Your Mac", uk: "Твій Mac", ru: "Твой Mac")
    static let optimizeButton = LocalizedText(
        en: "Optimize for my Mac", uk: "Оптимізувати під мій Mac", ru: "Оптимизировать под мой Mac")
    static let gameOptimized = LocalizedText(
        en: "Already optimized for your Mac", uk: "Уже оптимізовано під твій Mac", ru: "Уже оптимизировано под твой Mac")
    static let gameConfigMissing = LocalizedText(
        en: "rgl_config.txt not found. Launch Warband once so the game creates it, then come back.",
        uk: "Файл rgl_config.txt не знайдено. Запусти Warband хоча б раз, щоб гра його створила, і повернись.",
        ru: "Файл rgl_config.txt не найден. Запусти Warband хотя бы раз, чтобы игра его создала, и вернись.")
    static let gameOptimizedMessage = LocalizedText(
        en: "Optimized for your Mac. Backup: %@",
        uk: "Оптимізовано під твій Mac. Бекап: %@",
        ru: "Оптимизировано под твой Mac. Бэкап: %@")
    static let whatItChanges = LocalizedText(en: "What it changes", uk: "Що змінює", ru: "Что меняет")
    static let optBattleSize = LocalizedText(
        en: "Battle size → maximum (≈150 soldiers) — fixes the “too few archers” problem.",
        uk: "Розмір битви → максимум (≈150 бійців) — лагодить «мало лучників».",
        ru: "Размер битвы → максимум (≈150 бойцов) — чинит «мало лучников».")
    static let optShadows = LocalizedText(
        en: "Heavy shadows (accurate / environment / on plants) → off — the biggest FPS win.",
        uk: "Важкі тіні (точні / оточення / на рослинах) → вимкнено — найбільший приріст FPS.",
        ru: "Тяжёлые тени (точные / окружения / на растениях) → выключены — самый большой прирост FPS.")
    static let optGrass = LocalizedText(
        en: "Grass density → 25 — lighter battlefields.",
        uk: "Щільність трави → 25 — легші поля бою.",
        ru: "Плотность травы → 25 — более лёгкие поля боя.")
    static let perfNote = LocalizedText(
        en: "Everything else stays as your in-game Video menu has it. More than ~150 soldiers needs an .exe patch (risky — not supported yet).",
        uk: "Решта лишається такою, як у меню Video самої гри. Більше ~150 бійців потребує патчу .exe (ризиковано — поки не підтримується).",
        ru: "Остальное остаётся таким, как в меню Video самой игры. Больше ~150 бойцов требует патча .exe (рискованно — пока не поддерживается).")

    /// Categories mirror the original PoP Helper's tweak tabs (Rumata's app).
    /// Russian labels match the original verbatim (that's what Denys sees in-game).
    static func categoryName(_ category: String) -> LocalizedText {
        switch category {
        case "party": return LocalizedText(en: "Party", uk: "Загони", ru: "Отряд")
        case "tournaments": return LocalizedText(en: "Tournaments", uk: "Турніри", ru: "Турниры")
        case "towns": return LocalizedText(en: "Towns & villages", uk: "Міста/замки/села", ru: "Города/замки/деревни")
        case "prisoners": return LocalizedText(en: "Prisoners", uk: "Захоплення полонених", ru: "Захват пленных")
        case "battle": return LocalizedText(en: "Battle", uk: "Битва", ru: "Битва")
        case "orders": return LocalizedText(en: "Orders & CKO", uk: "Ордени та ВЛО", ru: "Ордена и СКО")
        case "lords": return LocalizedText(en: "Lords", uk: "Лорди", ru: "Лорды")
        case "honor": return LocalizedText(en: "Honor", uk: "Честь", ru: "Честь")
        case "misc": return LocalizedText(en: "Misc", uk: "Різне", ru: "Разное")
        case "spawns": return LocalizedText(en: "Spawns", uk: "Спавни", ru: "Спавны")
        default: return LocalizedText(en: "Other", uk: "Інше", ru: "Прочее")
        }
    }
}
