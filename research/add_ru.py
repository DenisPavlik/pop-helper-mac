#!/usr/bin/env python3
"""Add Russian (ru) translations to every {en, uk} localized-text object in
tweaks.json and packs.json, WITHOUT touching any opcode/code data.

Walks each JSON; for every dict that has BOTH string "en" and "uk" keys, adds
"ru" (if missing) from the RU map keyed on the English source string. No other
field is ever modified.
"""
import json
import os
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(HERE, ".."))
TWEAKS = os.path.join(ROOT, "PoPHelper", "Resources", "tweaks.json")
PACKS = os.path.join(ROOT, "PoPHelper", "Resources", "packs.json")

# English source string -> natural Russian (Mount&Blade / PoP terminology).
RU = {
    "Chance to capture unique spawn leaders": "Шанс пленить вожаков уникальных отрядов",
    "Controls the threshold roll for capturing unique spawn leaders and lords after battle (also covers Eyegrim the Devourer and the Three Seers). Lower it to capture them more often; at -100 they are always captured even if a Noldor lord fought alongside you.": "Управляет пороговым значением для пленения вожаков уникальных отрядов и лордов после битвы (включая Айгрима Пожирателя и Трёх Провидцев). Уменьшите его, чтобы пленять их чаще; при -100 они попадают в плен всегда, даже если рядом сражался нолдорский лорд.",
    "Capture threshold": "Порог пленения",
    "Always captured": "Всегда в плену",
    "Always, unless a Noldor lord is present": "Всегда, если нет нолдорского лорда",
    "Vanilla": "Как в игре",
    "Never captured": "Никогда не в плену",
    "Qualis Gem chance in the Noldor tournament": "Шанс камня Квалис за нолдорский турнир",
    "Chance (in %) that the prize for winning a Noldor tournament is a Qualis Gem. Vanilla is 50% effective (roll under 50 out of 100, threshold value 20 applies to the prize preroll); set it to 100 to always receive a Qualis Gem.": "Шанс (в %), что наградой за победу в нолдорском турнире будет камень Квалис. Установите 100, чтобы всегда получать камень Квалис.",
    "Qualis Gem chance": "Шанс камня Квалис",
    "Always a Qualis Gem": "Всегда камень Квалис",
    "Tournament victory rewards": "Награды за победу в турнире",
    "Sets the renown, town relation, denars and experience you receive for winning a tournament. Experience is hard-capped at 29,999 per award.": "Задаёт славу, отношение города, динары и опыт, которые вы получаете за победу в турнире. Опыт ограничен 29 999 за одну награду.",
    "Renown": "Слава",
    "Relation with the town": "Отношение города",
    "Denars": "Динары",
    "Experience": "Опыт",
    "Renown-based tournament bets": "Турнирные ставки от уровня славы",
    "Tournament bets scale 1:1 with your renown instead of the fixed 5–500 denar options. The betting menu offers 100%, 50%, 20%, 10% and 5% of your renown as the bet amount; payout ratios stay the same.": "Турнирные ставки масштабируются 1:1 с вашей славой вместо фиксированных 5–500 динаров. В меню ставок появятся варианты 100%, 50%, 20%, 10% и 5% от вашей славы; коэффициенты выплат не меняются.",
    "Recruit rescued Noldor prisoners": "Наём освобождённых нолдорских пленных",
    "Lets rescued Noldor prisoners join you (vanilla allows only Noldor Hunters). Each unit rolls random(0–99) + relations/4 against per-tier thresholds (86 Warrior, 93 Ranger, 99 Maiden Ranger, 110 Noble, 117 Twilight Knight), with a penalty for each unit already hired from the same batch. Uses the wiki-recommended values; mutually exclusive with other tweaks that touch the party_add_party_prisoners script.": "Позволяет нанимать освобождённых нолдорских пленных (в игре присоединяются только нолдорские охотники). Для каждого бойца бросается случайное число (0–99) + отношения/4 против порогов по рангу (86 воин, 93 следопыт, 99 дева-следопыт, 110 дворянин, 117 рыцарь сумерек), со штрафом за уже нанятых из той же партии. Использует рекомендованные вики значения; несовместимо с другими твиками скрипта party_add_party_prisoners.",
    "Noldor troops per Qualis Gem": "Количество нолдоров за камень Квалис",
    "Sets how many Noldor troops of each tier Quigfen and Arandur hand over in exchange for a Qualis Gem (with or without Noldor trade goods). Defaults double the vanilla amounts.": "Задаёт, сколько нолдорских бойцов каждого ранга Квигфен и Арандур отдают за камень Квалис (с нолдорскими товарами или без). Стандартные значения вдвое больше игровых.",
    "Quigfen, gem only: Noldor Warriors": "Квигфен, только камень: нолдорские воины",
    "Quigfen, gem only: Noldor Rangers": "Квигфен, только камень: нолдорские следопыты",
    "Quigfen, gem only: Noldor Maiden Rangers": "Квигфен, только камень: нолдорские девы-следопыты",
    "Quigfen, gem only: Noldor Nobles": "Квигфен, только камень: нолдорские дворяне",
    "Quigfen, gem only: Noldor Twilight Knights": "Квигфен, только камень: нолдорские рыцари сумерек",
    "Quigfen, gem + trade goods: Noldor Warriors": "Квигфен, камень и товары: нолдорские воины",
    "Quigfen, gem + trade goods: Noldor Rangers": "Квигфен, камень и товары: нолдорские следопыты",
    "Quigfen, gem + trade goods: Noldor Maiden Rangers": "Квигфен, камень и товары: нолдорские девы-следопыты",
    "Quigfen, gem + trade goods: Noldor Nobles": "Квигфен, камень и товары: нолдорские дворяне",
    "Quigfen, gem + trade goods: Noldor Twilight Knights": "Квигфен, камень и товары: нолдорские рыцари сумерек",
    "Arandur, gem only: Noldor Warriors": "Арандур, только камень: нолдорские воины",
    "Arandur, gem only: Noldor Rangers": "Арандур, только камень: нолдорские следопыты",
    "Arandur, gem only: Noldor Maiden Rangers": "Арандур, только камень: нолдорские девы-следопыты",
    "Arandur, gem only: Noldor Nobles": "Арандур, только камень: нолдорские дворяне",
    "Arandur, gem only: Noldor Twilight Knights": "Арандур, только камень: нолдорские рыцари сумерек",
    "Arandur, gem + trade goods: Noldor Warriors": "Арандур, камень и товары: нолдорские воины",
    "Arandur, gem + trade goods: Noldor Rangers": "Арандур, камень и товары: нолдорские следопыты",
    "Arandur, gem + trade goods: Noldor Maiden Rangers": "Арандур, камень и товары: нолдорские девы-следопыты",
    "Arandur, gem + trade goods: Noldor Nobles": "Арандур, камень и товары: нолдорские дворяне",
    "Arandur, gem + trade goods: Noldor Twilight Knights": "Арандур, камень и товары: нолдорские рыцари сумерек",
    "Disable companion complaints": "Отключить жалобы спутников",
    "Stops companions from complaining about each other after battles and about your actions (raiding villages, robbing caravans, unpaid wages, fleeing, failed quests and so on), including the personality-clash chatter.": "Спутники больше не жалуются друг на друга после битв и на ваши поступки (разорение деревень, грабёж караванов, невыплаченное жалованье, бегство из боя, проваленные задания и т. п.), включая ссоры из-за несовместимых характеров.",
    "Unhappy companions never leave": "Недовольные спутники не уходят",
    "Disables unhappy companions' attempts to quit your party and fixes the low-morale \"parting ways\" dialogue so you can no longer lose a companion to bad morale. On an existing save one already-scheduled leave attempt may still slip through once.": "Отключает попытки недовольных спутников покинуть отряд и исправляет диалог прощания при низком боевом духе, так что вы больше не потеряете спутника из-за настроения. На старом сохранении одна уже запланированная попытка уйти может сработать ещё раз.",
    "Prisoner lords' escape chance": "Шанс побега пленных лордов",
    "Controls how often captive lords escape. Party escape chance is (base − factor × Prisoner Management) / 10 percent, checked every 48 hours; the fief formula uses your steward's skill. Defaults set everything to 0 so lords never escape.": "Управляет тем, как часто пленные лорды сбегают. Шанс побега из отряда — (база − множитель × «Надзор за пленными») / 10 процентов, проверка каждые 48 часов; для владений используется навык управляющего. Стандартные значения 0 — лорды не сбегают никогда.",
    "Party: skill factor": "Отряд: множитель навыка",
    "Party: base escape value": "Отряд: базовое значение побега",
    "Never escape": "Никогда не сбегают",
    "Fief: skill factor": "Владение: множитель навыка",
    "Fief: base escape value": "Владение: базовое значение побега",
    "Battle renown cap": "Предел славы за битву",
    "Raises the cap on renown gained per battle. The stored value must be the square of the desired cap (vanilla 2500 = cap of 50); the actual maximum can run up to 10% above the cap.": "Повышает предел славы, которую можно получить за одну битву. Значение хранится как квадрат желаемого предела (2500 в игре = предел 50); фактический максимум может быть до 10% выше предела.",
    "Renown cap (squared value)": "Предел славы (квадрат значения)",
    "50 — vanilla": "50 — как в игре",
    "100": "100",
    "200": "200",
    "300": "300",
    "100,000 — effectively unlimited": "100 000 — практически без предела",
    "Troop wage formula": "Формула жалованья бойцам",
    "Tunes how weekly troop wages are calculated. The base wage is (level + bonus) squared, divided by the divisor; mounted units are multiplied/divided by the cavalry factors (66% extra by default); mercenaries and companions have their own multipliers; and each Leadership point cuts wages by a percentage. Requires a new week to show in the budget report.": "Настраивает расчёт еженедельного жалованья бойцам. Базовое жалованье — (уровень + бонус) в квадрате, делённое на делитель; для конницы применяются множитель и делитель (по умолчанию +66%); у наёмников и спутников свои множители; каждое очко «Лидерства» снижает жалованье на процент. Изменения появятся в отчёте о бюджете со следующей недели.",
    "Level bonus (added before squaring)": "Бонус к уровню (добавляется перед возведением в квадрат)",
    "Wage divisor": "Делитель жалованья",
    "Mounted multiplier": "Множитель для конницы",
    "Mounted divisor": "Делитель для конницы",
    "Mercenary multiplier": "Множитель для наёмников",
    "Companion multiplier": "Множитель для спутников",
    "Wage reduction per Leadership point (%)": "Снижение жалованья за очко «Лидерства» (%)",
    "Base income (rents) from fiefs": "Базовый доход (рента) с владений",
    "Sets the base weekly rent from villages, castles and towns, plus the final divisor applied to your total income (lower divisor = more money). Also affects the AI's maintainable garrison size. Takes effect from the week after next.": "Задаёт базовую еженедельную ренту с деревень, замков и городов, а также итоговый делитель всего вашего дохода (меньше делитель = больше денег). Также влияет на размер гарнизонов, которые может содержать ИИ. Действует с недели, что наступит через одну.",
    "Village rent": "Рента с деревни",
    "Castle rent": "Рента с замка",
    "Town rent": "Рента с города",
    "Total income divisor": "Делитель общего дохода",
    "Enterprise values": "Параметры предприятий",
    "Changes the four values of every enterprise: weekly inputs purchased, weekly outputs produced, weekly labor/upkeep cost, and the build (buying) price. Outputs are the main profit driver. Requires a new game to take effect.": "Меняет четыре параметра каждого предприятия: еженедельную закупку сырья (входы), еженедельное производство (выходы), еженедельные расходы на труд/содержание и цену постройки. Выходы — главный источник прибыли. Требует новой игры.",
    "Mill & Bakery: inputs/week": "Мельница и пекарня: входы/неделя",
    "Mill & Bakery: outputs/week": "Мельница и пекарня: выходы/неделя",
    "Mill & Bakery: labor/upkeep": "Мельница и пекарня: труд/содержание",
    "Mill & Bakery: build price": "Мельница и пекарня: цена постройки",
    "Brewery: inputs/week": "Пивоварня: входы/неделя",
    "Brewery: outputs/week": "Пивоварня: выходы/неделя",
    "Brewery: labor/upkeep": "Пивоварня: труд/содержание",
    "Brewery: build price": "Пивоварня: цена постройки",
    "Wine Press: inputs/week": "Винный пресс: входы/неделя",
    "Wine Press: outputs/week": "Винный пресс: выходы/неделя",
    "Wine Press: labor/upkeep": "Винный пресс: труд/содержание",
    "Wine Press: build price": "Винный пресс: цена постройки",
    "Tannery: inputs/week": "Кожевня: входы/неделя",
    "Tannery: outputs/week": "Кожевня: выходы/неделя",
    "Tannery: labor/upkeep": "Кожевня: труд/содержание",
    "Tannery: build price": "Кожевня: цена постройки",
    "Wool Cloth Weavery: inputs/week": "Шерстоткацкая: входы/неделя",
    "Wool Cloth Weavery: outputs/week": "Шерстоткацкая: выходы/неделя",
    "Wool Cloth Weavery: labor/upkeep": "Шерстоткацкая: труд/содержание",
    "Wool Cloth Weavery: build price": "Шерстоткацкая: цена постройки",
    "Linen Weavery: inputs/week": "Льноткацкая: входы/неделя",
    "Linen Weavery: outputs/week": "Льноткацкая: выходы/неделя",
    "Linen Weavery: labor/upkeep": "Льноткацкая: труд/содержание",
    "Linen Weavery: build price": "Льноткацкая: цена постройки",
    "Ironworks: inputs/week": "Литейная: входы/неделя",
    "Ironworks: outputs/week": "Литейная: выходы/неделя",
    "Ironworks: labor/upkeep": "Литейная: труд/содержание",
    "Ironworks: build price": "Литейная: цена постройки",
    "Oil Press: inputs/week": "Маслобойня: входы/неделя",
    "Oil Press: outputs/week": "Маслобойня: выходы/неделя",
    "Oil Press: labor/upkeep": "Маслобойня: труд/содержание",
    "Oil Press: build price": "Маслобойня: цена постройки",
    "Velvet Weavery & Dyeworks: inputs/week": "Бархатоткацкая и красильня: входы/неделя",
    "Velvet Weavery & Dyeworks: outputs/week": "Бархатоткацкая и красильня: выходы/неделя",
    "Velvet Weavery & Dyeworks: labor/upkeep": "Бархатоткацкая и красильня: труд/содержание",
    "Velvet Weavery & Dyeworks: build price": "Бархатоткацкая и красильня: цена постройки",
    "More loot from battles": "Больше добычи с битв",
    "Lowers the divisor in the loot-probability formula so you receive more loot overall after battles (vanilla 8; lower = more). Also lets you reduce the companions' loot share (3 by default; set to 1 to treat them as regular troops, or 0 to cut them out entirely).": "Уменьшает делитель в формуле вероятности добычи, так что после битв вы получаете больше трофеев (в игре 8; меньше = больше). Также позволяет снизить долю добычи спутников (по умолчанию 3; 1 — как у обычных бойцов, 0 — вовсе без доли).",
    "Loot probability divisor": "Делитель вероятности добычи",
    "About double loot": "Примерно вдвое больше",
    "Maximum loot": "Максимум добычи",
    "Companion loot share": "Доля добычи спутников",
    "Same as regular troops": "Как у обычных бойцов",
    "No share": "Без доли",
    "Guarantee KO chapters at game start": "Гарантированные капитулы орденов на старте",
    "Raises the spawn chance of the starting Knighthood Order chapters to 100% so the listed orders are guaranteed in their home fiefs on a new game. Where two orders compete for one fief (Avendor: Ebony Gauntlet vs Raven Spear; Ethos: Radiant Cross vs Immortals), setting the primary to 100 leaves the secondary at 0%. Requires a new game.": "Повышает шанс появления стартовых капитулов рыцарских орденов до 100%, так что перечисленные ордены гарантированно появятся в своих родных владениях в новой игре. Там, где за одно владение спорят два ордена (Авендор: Эбеновая Перчатка против Воронье Копьё; Этос: Сияющий Крест против Бессмертных), установка 100% для основного оставляет второму 0%. Требует новой игры.",
    "Silvermist Rangers (Senderfall)": "Сребротуманные следопыты (Сендерфолл)",
    "Ebony Gauntlet (Avendor)": "Эбеновая Перчатка (Авендор)",
    "Raven Spear (Avendor, secondary)": "Воронье Копьё (Авендор, второй)",
    "Radiant Cross (Ethos)": "Сияющий Крест (Этос)",
    "Immortals (Ethos, secondary)": "Бессмертные (Этос, второй)",
    "Order of the Falcon (Falcondark)": "Орден Сокола (Фалькондарк)",
    "Windriders (Nal Tar)": "Наездники Ветра (Нал Тар)",
    "Order of the Dragon (Ravenstern)": "Орден Дракона (Равенстерн)",
    "Order of the Lion (Marleons)": "Орден Льва (Марлеонс)",
    "Garrison size of walled fiefs": "Размер гарнизона укреплённых владений",
    "Controls how many times the kingdom reinforcement script is called for each walled fief at game start, which determines its garrison size. Vanilla: castles 18, cities 40, capital towns 48. Actual reinforcements per call scale with your character level. Requires a new game.": "Управляет тем, сколько раз на старте игры вызывается скрипт королевских подкреплений для каждого укреплённого владения, что определяет размер его гарнизона. В игре: замки 18, города 40, столицы 48. Фактическое число подкреплений за вызов зависит от уровня вашего персонажа. Требует новой игры.",
    "Castle reinforcement calls": "Вызовы подкреплений для замка",
    "City reinforcement calls": "Вызовы подкреплений для города",
    "Capital town reinforcement calls": "Вызовы подкреплений для столицы",
    "KO garrison reinforcement rate and limit": "Скорость и предел пополнения гарнизонов орденов",
    "Free Knighthood Order reinforcements added to garrisons that host a chapter. Sets the spawn chance for KO sergeants (vanilla 39, AI uses 89) and knights (vanilla 4, AI uses 10), and the per-garrison limits below which more are added (sergeants 50, knights 30). Actual maximum is always +3 above the limit; max rate is 100.": "Бесплатные подкрепления рыцарских орденов, добавляемые к гарнизонам с капитулом ордена. Задаёт шанс появления сержантов ордена (в игре 39, ИИ использует 89) и рыцарей (в игре 4, ИИ — 10), а также пределы на гарнизон, ниже которых добавляются новые (сержанты 50, рыцари 30). Фактический максимум всегда на +3 больше предела; максимальная скорость — 100.",
    "Sergeant spawn chance": "Шанс появления сержантов",
    "Pre-3.9 rate (same as AI)": "До 3.9 (как у ИИ)",
    "Knight spawn chance": "Шанс появления рыцарей",
    "Same as AI": "Как у ИИ",
    "Sergeant garrison limit": "Предел сержантов в гарнизоне",
    "Knight garrison limit": "Предел рыцарей в гарнизоне",
    "Relation change when distributing fiefs": "Изменение отношения за раздачу владений",
    "Sets the relation you gain with a vassal who receives a fief, and the min/max relation change with the other lords (the actual maximum is one lower than the set value; the exact result depends on personalities and mutual relations).": "Задаёт, сколько отношения вы получаете с вассалом, получившим владение, и минимальное/максимальное изменение отношения с другими лордами (фактический максимум на единицу меньше заданного значения; точный результат зависит от характеров и взаимоотношений лордов).",
    "Relation gain with the receiver": "Прирост отношения с получателем",
    "Min relation change with other lords": "Мин. изменение отношения с другими лордами",
    "Max relation change with other lords (+1)": "Макс. изменение отношения с другими лордами (+1)",
    "Relation hits with fiefless and defeated vassals": "Потеря отношения с безземельными и побеждёнными вассалами",
    "Controls the relation penalties applied repeatedly to certain vassal personalities: -1 each time such a vassal is defeated in battle, and -2/-1 for not owning a fief. Set them to 0 to remove the drip. Note: this also applies between kings and their own vassals.": "Управляет штрафами отношения, что раз за разом применяются к вассалам определённых характеров: -1 каждый раз, когда такого вассала побеждают в битве, и -2/-1 за отсутствие владения. Установите 0, чтобы убрать постепенную потерю. Внимание: это действует и между королями и их вассалами.",
    "Penalty on being defeated": "Штраф за поражение в битве",
    "Penalty for no fief (cunning/pitiless/etc.)": "Штраф за отсутствие владения (хитрые/безжалостные и т. п.)",
    "Penalty for no fief (martial)": "Штраф за отсутствие владения (воинственные)",
    "Party size formula": "Формула размера отряда",
    "Sets how your party size is calculated: a base size, plus a bonus for each Leadership point, plus a bonus for each Charisma point, plus one extra slot for every N renown (lower N = more troops from renown).": "Задаёт, как вычисляется размер вашего отряда: базовый размер, плюс бонус за каждое очко «Лидерства», плюс бонус за каждое очко «Харизмы», плюс один дополнительный слот за каждые N славы (меньше N = больше бойцов за славу).",
    "Base party size": "Базовый размер отряда",
    "Per Leadership point": "За очко «Лидерства»",
    "Per Charisma point": "За очко «Харизмы»",
    "Renown needed per extra slot": "Славы на дополнительный слот",
    "KO induction prestige cost range": "Диапазон престижа за вступление в орден",
    "Sets the base (x1.0 multiplier) minimum and maximum prestige cost to induct a unit into a Knighthood Order, scaled by your Honor rating. Vanilla knights 10-46 and sergeants 6-36 (the actual maximum is one lower than the set value). Order-specific multipliers (1.0x to 1.5x) still apply on top.": "Задаёт базовый (множитель x1.0) минимальный и максимальный престиж для вступления бойца в рыцарский орден, масштабируемый по вашей «Чести». В игре рыцари 10-46, сержанты 6-36 (фактический максимум на единицу меньше заданного значения). Поверх этого действуют множители отдельных орденов (от 1.0x до 1.5x).",
    "Knight: min prestige": "Рыцарь: мин. престиж",
    "Knight: max prestige (+1)": "Рыцарь: макс. престиж (+1)",
    "Sergeant: min prestige": "Сержант: мин. престиж",
    "Sergeant: max prestige (+1)": "Сержант: макс. престиж (+1)",
    "CKO equipping time and cost": "Время и стоимость снаряжения СРО",
    "Tunes how long your Custom Knighthood Order knights and sergeants take to get new equipment and how much it costs. Higher equipping-time factor shortens upgrade times; lower cost factor makes upgrades cheaper (both scale non-linearly). Do not apply while equipping is in progress.": "Настраивает, сколько времени рыцари и сержанты вашего Собственного рыцарского ордена (СРО) тратят на получение нового снаряжения и сколько это стоит. Больший множитель времени сокращает время обновления; меньший множитель стоимости удешевляет обновления (оба масштабируются нелинейно). Не применяйте во время снаряжения.",
    "Equipping-time factor (higher = faster)": "Множитель времени снаряжения (больше = быстрее)",
    "~7x faster": "~7x быстрее",
    "Near-instant": "Почти мгновенно",
    "Equipping-cost factor (lower = cheaper)": "Множитель стоимости снаряжения (меньше = дешевле)",
    "~1/19 cost": "~1/19 стоимости",
    "Near-minimum cost": "Почти минимальная стоимость",
    "Tavern mercenary hiring cost": "Стоимость найма наёмников в тавернах",
    "Tunes the price to hire a mercenary in taverns. The cost per troop is ((level + addend)^2 + offset) / divisor, multiplied by the mounted factor for cavalry. Lower it to make tavern mercenaries cheaper.": "Настраивает цену найма наёмника в тавернах. Стоимость за бойца — ((уровень + слагаемое)^2 + смещение) / делитель, умноженная на множитель для конницы. Уменьшите, чтобы наёмники в тавернах стоили дешевле.",
    "Level addend": "Слагаемое к уровню",
    "Cost offset": "Смещение стоимости",
    "Cost divisor": "Делитель стоимости",
    "Prisoner recruitment factors": "Факторы найма пленных",
    "Tunes recruiting from prisoners: the level limit for hiring rescued prisoners into your party (and the AI's), the hours required between recruitment attempts, and the escape chance of recruited prisoner troops (formula: base% - Leadership x perPoint%).": "Настраивает наём из пленных: предел уровня для найма освобождённых пленных в ваш отряд (и для ИИ), число часов между попытками найма и шанс побега нанятых из пленных бойцов (формула: база% - «Лидерство» x заОчко%).",
    "Rescued-prisoner level limit (1-61)": "Предел уровня освобождённых пленных (1-61)",
    "Hours between recruit attempts": "Часов между попытками найма",
    "Escape chance base (%)": "База шанса побега (%)",
    "Escape reduction per Leadership point (%)": "Снижение побега за очко «Лидерства» (%)",
    "Tournament elimination factor (rounds)": "Множитель выбывания турнира (раунды)",
    "Sets the factor by which the remaining tournament participants are reduced after each round you win. Vanilla is 2 (half are eliminated each round, giving 6 rounds for 64 participants). A higher factor removes more per round and shortens the tournament; a factor of 1 makes every tournament last a single round.": "Задаёт множитель, на который уменьшается число участников турнира после каждого выигранного раунда. В игре это 2 (каждый раунд выбывает половина, для 64 участников выходит 6 раундов). Больший множитель убирает больше за раунд и сокращает турнир; множитель 1 делает турнир одним раундом.",
    "Elimination factor": "Множитель выбывания",
    "Single round": "Один раунд",
    "Tournament frequency and duration": "Частота и длительность турниров",
    "Controls how often tournaments are held and how long they last. The threshold is the number of active tournaments below which the game tries to add more; the chance is the per-24-hour percentage to add a new tournament to a random town; the minimum and maximum bound the days a tournament stays available (vanilla lasts between the minimum and the maximum minus one).": "Управляет тем, как часто проводятся турниры и сколько они длятся. Порог — число активных турниров, ниже которого игра пытается добавить новые; шанс — процент за сутки добавить новый турнир в случайный город; минимум и максимум ограничивают число дней, в течение которых турнир доступен (в игре — от минимума до максимума минус один).",
    "Active-tournament threshold": "Порог активных турниров",
    "Daily add chance (%)": "Ежедневный шанс добавить (%)",
    "Minimum days": "Минимум дней",
    "Maximum days (exclusive)": "Максимум дней (не включая)",
    "Noldor tournament wins for Mystical Rune Plate": "Побед в нолдорском турнире для Мистической рунной кирасы",
    "Sets how many Noldor tournament wins are required before Aeldarian will reward you with the Mystical Rune Plate. Vanilla requires 10 wins; lower it to receive the armor sooner.": "Задаёт, сколько побед в нолдорском турнире нужно, чтобы Аэлдариан наградил вас Мистической рунной кирасой. В игре нужно 10 побед; уменьшите, чтобы получить броню раньше.",
    "Wins required": "Нужно побед",
    "1 win": "1 победа",
    "Arena fight victory prize": "Награда за победу на арене",
    "Sets the denar prize for winning the whole arena training fight (vanilla 2000). Covers all three places in the dialogue where the full-victory sum is stored, so the reward stays consistent.": "Задаёт награду в динарах за победу во всём тренировочном бою на арене (в игре 2000). Охватывает все три места в диалоге, где хранится сумма за полную победу, так что награда остаётся согласованной.",
    "Victory prize (denars)": "Награда за победу (динары)",
    "Faction relation caps": "Пределы отношения фракций",
    "Some factions refuse to let your relation rise above (or fall below) a fixed cap, re-checked every 168 hours. This sets each cap individually: Rogue Knights, Heretics, Jatu, Snake Cult, Adventurer Companies, Mystmountain Tribes, D'Shar Raiders and Singalians. Raise them to befriend factions you normally cannot.": "Некоторые фракции не дают вашему отношению подняться выше (или упасть ниже) фиксированного предела, что проверяется каждые 168 часов. Это задаёт каждый предел отдельно: рыцари-разбойники, еретики, джату, культ Змеи, отряды искателей приключений, племена Туманных гор, рейдеры Д'Шар и сингалийцы. Повысьте их, чтобы подружиться с фракциями, с которыми обычно не получается.",
    "Rogue Knights cap": "Предел рыцарей-разбойников",
    "Heretics cap": "Предел еретиков",
    "Jatu cap": "Предел джату",
    "Snake Cult cap": "Предел культа Змеи",
    "Adventurer Companies cap": "Предел отрядов искателей приключений",
    "Mystmountain Tribes cap": "Предел племён Туманных гор",
    "D'Shar Raiders cap": "Предел рейдеров Д'Шар",
    "Singalians cap": "Предел сингалийцев",
    "Long Bow buff": "Усиление длинного лука",
    "Makes the Long Bow more competent by adjusting its price, accuracy and shot speed. Vanilla values are 183 denars, 86 accuracy and 65 shot speed.": "Делает длинный лук полезнее, меняя его цену, точность и скорость выстрела. Игровые значения — 183 динара, точность 86 и скорость выстрела 65.",
    "Price (denars)": "Цена (динары)",
    "Accuracy": "Точность",
    "Shot speed": "Скорость выстрела",
    "Runed Bastard Sword power restore": "Восстановление силы рунного бастарда",
    "Restores the Runed Bastard Sword towards its pre-3.9 strength by raising its cost and speed. Vanilla values are 4213 denars and 110 speed.": "Возвращает рунному бастарду силу, которую он имел до версии 3.9, повышая его стоимость и скорость. Игровые значения — 4213 динара и скорость 110.",
    "Cost (denars)": "Стоимость (динары)",
    "Speed rating": "Скорость",
    "Sapphire/Ruby/Emerald Rune Plate armor buff": "Усиление брони Сапфировой/Рубиновой/Изумрудной рунных кирас",
    "Adds +2 to the head, body and leg armor rating of the Sapphire, Ruby and Emerald Rune Plates (and their caped versions) so they are more worth their Qualis-Gem price compared to a Lordly Noldor Ancient Plate.": "Добавляет +2 к защите головы, тела и ног для Сапфировой, Рубиновой и Изумрудной рунных кирас (и их версий с плащом), чтобы они лучше оправдывали свою цену в камнях Квалис по сравнению с благородной нолдорской древней кирасой.",
    "Soldier rank for \"capture prisoners\" quest": "Ранг бойцов для задания «захватить пленных»",
    "Sets the troop-tier range the game picks from for the lord quest to capture a certain amount of enemy prisoners. Vanilla picks tiers 2 to 5 (45 = tier 5 maximum, 42 = tier 2 minimum). Lower both to allow easier, lower-tier prisoners.": "Задаёт диапазон рангов бойцов, из которого игра выбирает цель для лордского задания захватить определённое число вражеских пленных. В игре выбираются ранги от 2 до 5 (45 = максимум 5-й ранг, 42 = минимум 2-й ранг). Уменьшите оба, чтобы разрешить более простых пленных низшего ранга.",
    "Upper tier code": "Код верхнего ранга",
    "Lower tier code": "Код нижнего ранга",
    "Right to rule lost on aborted \"Resolve dispute\"": "Потеря права на престол за провал «Уладить спор»",
    "Sets how much right to rule you lose when the \"Resolve dispute\" quest is aborted or expires. Vanilla is -2 (applied for both the abort and the expiration case). Set to 0 to lose nothing.": "Задаёт, сколько права на престол вы теряете, когда задание «Уладить спор» отменяется или истекает. В игре это -2 (применяется и при отмене, и при просрочке). Поставьте 0, чтобы не терять ничего.",
    "Right to rule change": "Изменение права на престол",
    "No loss": "Без потери",
    "Knighthood Order renown quest cooldown": "Перезарядка задания на славу рыцарского ордена",
    "Controls the cooldown of the repeatable renown quest given by Knighthood Orders. Set both values to 0 to make the quest instantly repeatable. Vanilla values are 24 and 15.": "Управляет перезарядкой повторяемого задания на славу, которое выдают рыцарские ордены. Поставьте оба значения на 0, чтобы задание можно было повторять мгновенно. Игровые значения — 24 и 15.",
    "Cooldown value A": "Значение перезарядки A",
    "Cooldown value B": "Значение перезарядки B",
    "Noble troop recruitment cost": "Стоимость найма дворянских бойцов",
    "Sets the crown cost to accept a Noble into your court through the War Room. Vanilla is 500 per Noble for the single-recruit option (and 5000 for the bulk \"10x\" option, which must stay tenfold the single price).": "Задаёт стоимость в коронах за принятие дворянина в ваш двор через Военную залу. В игре это 500 за одного дворянина для одиночного варианта (и 5000 для оптового варианта «x10», который должен оставаться вдесятеро больше одиночной цены).",
    "Cost per Noble": "Цена за дворянина",
    "Cost for 10 Nobles": "Цена за 10 дворян",
    "Minimum flee delay in battle": "Минимальная задержка перед бегством в битве",
    "Sets the minimum number of seconds that must pass in a battle before routing enemies are allowed to flee. Lower values let beaten enemies break and run sooner; the value is applied to both the decide_run_away_or_not and formation_decide_run_away_or_not scripts (vanilla 180, Native 45).": "Задаёт минимальное число секунд боя, которые должны пройти, прежде чем разбитые враги смогут броситься в бегство. Меньшие значения позволяют побеждённым врагам бежать раньше; значение применяется к скриптам decide_run_away_or_not и formation_decide_run_away_or_not (180 в игре, 45 в Native).",
    "Minimum seconds before fleeing": "Минимум секунд до бегства",
    "Native": "Как в Native",
    "Always join any side in battles": "Всегда присоединяться к любой стороне в битве",
    "Removes the relation requirements that normally block you from helping one side of a field battle, so you can join either side regardless of standing. The two relation gates (-50) are widened to -100 and the upper bounds (80) raised to 101.": "Убирает требования к отношениям, что обычно не дают помочь одной из сторон полевой битвы, так что вы можете присоединиться к любой стороне независимо от отношения. Два порога отношений (-50) расширены до -100, а верхние границы (80) подняты до 101.",
    "Disable night ambushes": "Отключить ночные засады",
    "Completely disables Scorpion Assassin night ambushes by adding an always-false condition to the start of the cf_enter_center_location_bandit_check script, so the ambush check never fires.": "Полностью отключает ночные засады скорпионов-убийц, добавляя всегда-ложное условие в начало скрипта cf_enter_center_location_bandit_check, так что проверка засады никогда не срабатывает.",
    "Patrol radius": "Радиус патрулирования",
    "Sets the patrolling radius of militia patrols, Errant Knights, independent KO patrols and Stronghold KO patrols. The value times 6 is the in-game distance (vanilla 5 = 30 units, roughly Sarleon-to-Singal); 1 is the minimum.": "Задаёт радиус патрулирования для ополченских патрулей, странствующих рыцарей, независимых патрулей рыцарских орденов и патрулей твердыни ордена. Значение умножается на 6, чтобы дать игровое расстояние (5 в игре = 30 единиц, примерно от Сарлеона до Сингала); минимум — 1.",
    "Militia patrol radius": "Радиус ополченского патруля",
    "Knighthood Order patrol radius": "Радиус патруля рыцарского ордена",
    "Stronghold KO patrol radius": "Радиус патруля твердыни ордена",
    "Deserter party size": "Размер отрядов дезертиров",
    "Controls how many units spawn in deserter parties. The count is a random number between the minimum and (per-level + player level x multiplier - 1). Vanilla: min 10, per-level base 11, multiplier 2 (so at level 10 the range is 10-30).": "Управляет тем, сколько бойцов появляется в отрядах дезертиров. Число — случайное между минимумом и (база + уровень игрока x множитель - 1). В игре: минимум 10, база 11, множитель 2 (на 10-м уровне диапазон 10-30).",
    "Per player level multiplier": "Множитель за уровень игрока",
    "Per-level base": "База за уровень",
    "Minimum size": "Минимальный размер",
    "Party-size growth rate by player level": "Темп роста отрядов от уровня игрока",
    "Sets the player-level multiplier in update_party_creation_random_limits, which scales how much bigger map parties (bandits, unique spawns, etc.) grow as you level up. Higher values mean tougher spawns (vanilla 4, Native 3).": "Задаёт множитель уровня игрока в update_party_creation_random_limits, который определяет, насколько крупнее становятся отряды на карте (бандиты, уникальные спавны и т. п.) по мере вашего роста. Большие значения дают более сложные спавны (4 в игре, 3 в Native).",
    "Level multiplier": "Множитель уровня",
    "Maximum parties on the world map": "Максимум отрядов на карте мира",
    "Sets the maximum number of each kind of spawned party allowed on the world map at once: Red Brotherhood, Singalian Slavers, Azi Dahaka Death Cult, deserters, Vanskerry Raiders, signature unique-spawn patrols (Eyegrim, Dread Legion, Wolfbode, Three Seers, Rasmus), outlaw bands, AI-created militia patrols, and the combined per-kingdom militia patrol total.": "Задаёт максимальное число каждого типа отрядов, что могут одновременно существовать на карте мира: Красное Братство, сингалийские работорговцы, культ смерти Ази Дахака, дезертиры, ванскеррийские рейдеры, патрули уникальных спавнов (Айгрим, Легион Ужаса, Вольфбоде, Три Провидца, Расмус), шайки разбойников, ополченские патрули от ИИ и суммарный предел ополченских патрулей на королевство.",
    "Red Brotherhood parties": "Отряды Красного Братства",
    "Singalian Slavers": "Сингалийские работорговцы",
    "Azi Dahaka Death Cult Marauders": "Мародёры культа Ази Дахака",
    "Deserter parties": "Отряды дезертиров",
    "Vanskerry Raiders": "Ванскеррийские рейдеры",
    "Unique-spawn signature patrols (each)": "Патрули уникальных спавнов (каждого)",
    "Outlaw Bands": "Шайки разбойников",
    "AI-created militia patrols": "Ополченские патрули от ИИ",
    "Total militia patrols per kingdom": "Всего ополченских патрулей на королевство",
    "Ransom amounts for captured lords": "Размер выкупа за пленных лордов",
    "Tunes the ransom offered for captured lords and kings in calculate_ransom_amount_for_troop, plus how often offers arrive. The minimum ransom is base + leader bonus + (town x6 + castle x2 + village x1) x fief value + renown x renownFactor; the maximum is minimum x3/2. Lower the rounding divisor (100) to boost offers.": "Настраивает выкуп за пленных лордов и королей в calculate_ransom_amount_for_troop, а также частоту предложений. Минимальный выкуп = база + бонус за лидера + (город x6 + замок x2 + деревня x1) x ценность владения + слава x множитель; максимум = минимум x3/2. Уменьшите делитель округления (100), чтобы повысить предложения.",
    "Hours between ransom offers": "Часов между предложениями выкупа",
    "Base ransom amount": "Базовый размер выкупа",
    "Faction leader bonus": "Бонус за лидера фракции",
    "Per-fief value multiplier": "Множитель ценности владения",
    "Renown multiplier": "Множитель славы",
    "Rounding divisor (lower = bigger ransoms)": "Делитель округления (меньше = больше выкуп)",
    "Prisoner recruitment cooldown": "Перезарядка найма пленных",
    "Sets the number of hours you must wait between attempts to recruit prisoners from the camp menu (vanilla 24).": "Задаёт число часов ожидания между попытками нанять пленных через меню лагеря (24 в игре).",
    "Hours between attempts": "Часов между попытками",
    "Prisoner capacity scales with party size": "Вместимость пленных зависит от размера отряда",
    "Overhauls how many prisoners you can hold so it scales with your party size (Viking Conquest style) instead of a flat value. At 0 Prisoner Management you need 5 soldiers per prisoner; this ratio drops by 0.3 per skill point, reaching 2 soldiers per prisoner at 10 PM. Incompatible with the tweak that makes companions contribute their Prisoner Management skill.": "Переделывает вместимость пленных так, что она зависит от размера вашего отряда (как в Viking Conquest), а не от фиксированного числа. При 0 «Надзора за пленными» нужно 5 солдат на пленного; это соотношение снижается на 0.3 за очко навыка, достигая 2 солдат на пленного при 10. Несовместимо с твиком, что позволяет спутникам добавлять свой «Надзор за пленными».",
    "Prisoner troops never escape over time": "Пленные бойцы не сбегают со временем",
    "Stops ordinary prisoner troops held in your fiefs from gradually escaping over time. Removes the escape operation from the 168-hour prison trigger and decrements its operation counter accordingly.": "Останавливает постепенный побег обычных пленных бойцов из ваших владений. Убирает операцию побега из 168-часового триггера тюрьмы и соответственно уменьшает счётчик операций.",
    "Companions spreading the word about you": "Спутники рассказывают о вас",
    "Adjusts the reward when a companion who left to spread the word about you returns: how much Right to Rule you gain, and how many days they are away before returning.": "Настраивает награду за возвращение спутника, который ушёл рассказывать о вас: сколько «Права на престол» вы получаете и сколько дней он отсутствует до возвращения.",
    "Right to Rule gained": "Полученное «Право на престол»",
    "Days before companion returns": "Дней до возвращения спутника",
    "Besiege friendly castles and towns": "Осада дружественных замков и городов",
    "Enables the cheat-menu option to besiege friendly castles and towns (the \"honest\" variant, which sets your relation with the target faction to a negative value so the siege state persists and war can be declared). Replaces the mno_cheat_town_start_siege menu entry.": "Включает опцию меню читов для осады дружественных замков и городов («честный» вариант, что устанавливает ваше отношение к целевой фракции на отрицательное значение, чтобы состояние осады сохранялось и можно было объявить войну). Заменяет пункт меню mno_cheat_town_start_siege.",
    "Relation set after the attempt": "Отношение после попытки",
    "Militia patrol troop limit": "Предел бойцов в ополченском патруле",
    "By default you cannot give troops to a village militia patrol once it reaches 100 men. This raises that cap so you can reinforce your patrols with larger garrisons.": "По умолчанию вы не можете передать бойцов в деревенский ополченский патруль, как только он достигнет 100 человек. Этот твик повышает предел, чтобы вы могли усиливать патрули большими гарнизонами.",
    "Patrol troop limit": "Предел бойцов в патруле",
    "Spawn sighting report cost": "Цена отчёта о наблюдении отрядов",
    "Sets the gold cost of buying a sighting report telling you where unique spawns are located. Vanilla is 2000 denars; lower it for cheaper intel.": "Задаёт цену в золоте за отчёт о наблюдении, показывающий расположение уникальных отрядов. В игре — 2000 динаров; уменьшите для более дешёвой разведки.",
    "Sighting report cost": "Цена отчёта",
    "KO patrol cap and spawn chance": "Предел и шанс появления патрулей орденов",
    "Knighthood Order patrols spawn on their own around castles and towns that host a chapter. This raises the maximum number allowed on the map and the per-check spawn chance, so KO patrols become more common (helping you befriend orders like the Eventide).": "Патрули рыцарских орденов появляются сами вокруг замков и городов, где есть их капитул. Этот твик повышает максимальное число таких патрулей на карте и шанс их появления, так что они становятся чаще (в том числе легче подружиться с орденами).",
    "Max KO patrols on the map": "Максимум патрулей орденов на карте",
    "Spawn chance (%) per check": "Шанс появления (%) за проверку",
    "Co-op patrol: min knights": "Совместный патруль: мин. рыцарей",
    "Co-op patrol: max knights": "Совместный патруль: макс. рыцарей",
    "Co-op patrol: min sergeants": "Совместный патруль: мин. сержантов",
    "Co-op patrol: max sergeants": "Совместный патруль: макс. сержантов",
    "Solo patrol: min knights": "Одиночный патруль: мин. рыцарей",
    "Solo patrol: max knights": "Одиночный патруль: макс. рыцарей",
    "KO/CKO knight quality upgrade cost": "Стоимость повышения качества рыцарей орденов/СРО",
    "Controls the prestige and gold cost of upgrading the quality of Knighthood Order and Custom Knighthood Order knights. The prestige cost starts at 30 and scales by the multiplier/divisor (3/2 = 1.5x each step); the gold cost starts at 10000 and is multiplied each step. Defaults make upgrades cheaper.": "Управляет стоимостью (престиж и золото) повышения качества рыцарей рыцарских орденов и собственного рыцарского ордена. Престиж начинается с 30 и растёт по множителю/делителю (3/2 = ×1.5 за шаг); золото начинается с 10000 и умножается каждый шаг. Стандартные значения удешевляют улучшения.",
    "Starting prestige cost": "Начальная стоимость в престиже",
    "Starting gold cost": "Начальная стоимость в золоте",
    "Prestige multiplier": "Множитель престижа",
    "Prestige divisor": "Делитель престижа",
    "Gold multiplier per step": "Множитель золота за шаг",
    "Kings create KO chapters more often": "Короли чаще основывают капитулы орденов",
    "Increases the chance of kings founding new Knighthood Order chapters in their walled fiefs and removes the vanilla requirements (1 in-game year played and player above level 30). With the default chance most missing orders should have a chapter within ~500 in-game days (kings never found the Order of the Griffon).": "Повышает шанс основания королями новых капитулов рыцарских орденов в их укреплённых владениях и убирает игровые требования (1 игровой год и уровень игрока выше 30). При стандартном шансе большинство отсутствующих орденов получат капитул примерно за 500 игровых дней (орден Грифона короли не основывают никогда).",
    "CKO training frequency": "Частота тренировок собственного ордена",
    "Sets how often (in hours) Custom Knighthood Order training sessions occur. Each session gives your CKO knights and sergeants a chance to gain stats, skills and proficiencies. Lower it to train faster. Do not change this while training is in progress.": "Задаёт, как часто (в часах) проходят тренировки собственного рыцарского ордена. За каждую тренировку ваши рыцари и сержанты имеют шанс повысить характеристики, навыки и владение оружием. Уменьшите, чтобы тренировать быстрее. Не меняйте во время активной тренировки.",
    "Hours between training sessions": "Часов между тренировками",
    "Relation needed for Calanon's CKO unlocks": "Отношение для разблокировок СРО у Каланона",
    "Sets the Noldor relation threshold required to unlock Calanon's Custom Knighthood Order equipment options. Vanilla requires 70; lower it to unlock the Noldor merchant's offerings sooner.": "Задаёт порог отношения нолдоров, нужный, чтобы разблокировать снаряжение собственного рыцарского ордена у Каланона. В игре нужно 70; уменьшите, чтобы открыть предложения нолдорского торговца раньше.",
    "Required Noldor relation": "Нужное отношение нолдоров",
    "Honor loss for refusing a ransom offer": "Потеря чести за отказ от выкупа лорда",
    "Sets the honor penalty you take when you refuse a ransom offer for a captured lord. Vanilla is -5; set it to 0 to remove the penalty entirely.": "Задаёт штраф к чести за отказ от предложения выкупа пленного лорда. В игре — -5; установите 0, чтобы убрать штраф полностью.",
    "Honor penalty": "Штраф к чести",
    "Honor loss for hostile actions to a village": "Потеря чести за враждебные действия против деревни",
    "Sets the honor penalties for razing a village, stealing cattle and stealing supplies. Defaults set all three to 0 so you keep your honor while raiding.": "Задаёт штрафы к чести за разорение деревни, кражу скота и кражу припасов. Стандартные значения обнуляют все три, так что вы сохраняете честь во время набегов.",
    "Razing a village": "Разорение деревни",
    "Stealing cattle": "Кража скота",
    "Stealing supplies": "Кража припасов",
    "Renown decay": "Угасание славы",
    "Every two weeks your renown is reduced by current renown divided by this divisor (vanilla 200 = 0.5%). Raise it (e.g. 99999) to effectively eliminate renown decay.": "Каждые две недели ваша слава уменьшается на текущую славу, делённую на этот делитель (в игре 200 = 0.5%). Увеличьте его (напр. 99999), чтобы практически убрать угасание славы.",
    "Renown decay divisor": "Делитель угасания славы",
    "Vanilla (0.5%)": "Как в игре (0.5%)",
    "No decay": "Без угасания",
    "Relation change for helping/fighting a faction": "Изменение отношения за помощь/бой против фракции",
    "Sets the maximum relation swing with factions after a battle (affects both gains and losses), and the immediate relation penalty a king/queen takes with the faction they sided against. Vanilla is 4 and -10 respectively.": "Задаёт максимальное изменение отношения с фракциями после битвы (влияет и на прирост, и на потери) и мгновенный штраф отношения, который король/королева получает с фракцией, против которой выступил. В игре — 4 и -10 соответственно.",
    "Max relation change after battle": "Макс. изменение отношения после битвы",
    "King/queen faction penalty": "Штраф фракции для короля/королевы",
    "Price of buying peace": "Цена покупки мира",
    "Sets the cost multiplier for buying peace from a faction. Vanilla is 50; reducing it (e.g. to 5) cuts the price proportionally, and 0 makes peace free.": "Задаёт множитель стоимости покупки мира у фракции. В игре — 50; уменьшение (напр. до 5) пропорционально снижает цену, а 0 делает мир бесплатным.",
    "Peace cost multiplier": "Множитель стоимости мира",
    "Penalty for rejecting a vassalage invitation": "Штраф за отказ от приглашения в вассалы",
    "Sets the relation penalties for declining an invitation to become a vassal: the change with the king and with the king's whole faction. Defaults remove both penalties.": "Задаёт штрафы отношения за отказ стать вассалом: изменение с королём и со всей королевской фракцией. Стандартные значения убирают оба штрафа.",
    "Relation with the king": "Отношение с королём",
    "Relation with the king's faction": "Отношение с фракцией короля",
    "Village relation from Schools": "Отношение деревни от школ",
    "Sets how many relation points a built School gives you with its village each cycle (weekly in PoP). Raise it to befriend your villages faster.": "Задаёт, сколько очков отношения построенная школа даёт вам с её деревней за цикл (еженедельно в PoP). Увеличьте, чтобы быстрее завоёвывать расположение деревень.",
    "Relation points per cycle": "Очков отношения за цикл",
    "Lady gift system for repairing relations": "Система подарков от дам для исправления отношения",
    "Tunes the gift system that ladies offer to repair relations with enemy lords: the relation cap below which gifts are allowed, how much relation each of the three gift tiers grants, and their prices. Defaults raise the cap to 100 and the relation gains, and reduce the prices.": "Настраивает систему подарков, которую дамы предлагают для исправления отношения с вражескими лордами: предел отношения, ниже которого разрешены подарки, сколько отношения даёт каждый из трёх уровней подарка и их цены. Стандартные значения повышают предел до 100 и прирост отношения и снижают цены.",
    "Relation cap to allow gifts": "Предел отношения для подарков",
    "Tier 1 (cheap) gift relation": "Отношение за подарок 1 уровня (дешёвый)",
    "Tier 2 (mid) gift relation": "Отношение за подарок 2 уровня (средний)",
    "Tier 3 (expensive) gift relation": "Отношение за подарок 3 уровня (дорогой)",
    "Tier 1 gift price": "Цена подарка 1 уровня",
    "Tier 2 gift price": "Цена подарка 2 уровня",
    "Tier 3 gift price": "Цена подарка 3 уровня",
    "Morale penalty when out of food": "Штраф к боевому духу за нехватку еды",
    "Sets the party morale penalty applied periodically when you run out of food. Vanilla is -3; set it to 0 to eliminate the penalty.": "Задаёт штраф к боевому духу отряда, периодически накладываемый, когда у вас заканчивается еда. В игре — -3; установите 0, чтобы убрать штраф.",
    "Morale penalty": "Штраф к боевому духу",
    "Base party morale": "Базовый боевой дух отряда",
    "Tunes party morale: the morale penalty per hero/companion unit, the Leadership morale bonus while you are king/queen, and the Leadership morale bonus while you are not. Defaults remove the hero penalty for steadier morale.": "Настраивает боевой дух отряда: штраф за каждого героя/спутника, бонус духа за «Лидерство», когда вы король/королева, и бонус, когда нет. Стандартные значения убирают штраф за героев для более стабильного духа.",
    "Penalty per hero unit": "Штраф за каждого героя",
    "Leadership bonus as king/queen": "Бонус за «Лидерство» как король/королева",
    "Leadership bonus when not king/queen": "Бонус за «Лидерство», когда не король/королева",
    "Starting honor bonus from character creation": "Стартовый бонус чести за создание персонажа",
    "Sets the honor you gain from the Stage 1 'minor noble' background and from each Stage 4 'letter that changed your life' choice (depending on your Stage 1 pick: minor noble, merchant ship captain, former knight, retired adventurer, wandering nomad clan leader, respectable physician). Raise these for a more honorable start.": "Задаёт честь, которую вы получаете за происхождение «мелкий дворянин» на этапе 1 и за каждый выбор на этапе 4 «письмо, изменившее вашу жизнь» (в зависимости от выбора на этапе 1: мелкий дворянин, капитан торгового судна, бывший рыцарь, отставной искатель приключений, вождь кочевников, уважаемый лекарь). Повысьте для более честного старта.",
    "Stage 1: minor noble": "Этап 1: мелкий дворянин",
    "Stage 4: letter (was minor noble)": "Этап 4: письмо (был мелким дворянином)",
    "Stage 4: letter (was merchant ship captain)": "Этап 4: письмо (был капитаном торгового судна)",
    "Stage 4: former knight (part 1)": "Этап 4: бывший рыцарь (часть 1)",
    "Stage 4: former knight (part 2)": "Этап 4: бывший рыцарь (часть 2)",
    "Stage 4: retired adventurer": "Этап 4: отставной искатель приключений",
    "Stage 4: wandering nomad clan leader": "Этап 4: вождь кочевников",
    "Stage 4: respectable physician": "Этап 4: уважаемый лекарь",
    "Party size that makes villagers fight back": "Размер отряда, при котором крестьяне дают отпор",
    "Villagers fight back during a raid only if your party has this many people or fewer (vanilla 25). Raise it so villagers resist even larger parties.": "Крестьяне дают отпор во время набега, только если в вашем отряде столько бойцов или меньше (в игре 25). Повысьте, чтобы крестьяне сопротивлялись даже большим отрядам.",
    "Max party size for resistance": "Макс. размер отряда для сопротивления",
    "Command allied units without being marshal": "Командование союзниками без звания маршала",
    "Removes the requirement to be the marshal before you can command allied units in battle. Set to 0 to always be in command of allies regardless of who is marshal.": "Убирает требование быть маршалом, чтобы командовать союзными отрядами в битве. Установите 0, чтобы всегда управлять союзниками независимо от того, кто маршал.",
    "Require marshal status": "Требовать статус маршала",
    "Vanilla (must be marshal)": "Как в игре (нужно быть маршалом)",
    "Always command allies": "Всегда командовать союзниками",
    "Wine price for town relation": "Цена вина для отношения с городом",
    "Changes the price of buying drinks for the town in a tavern, which raises your relation with the town. Lower it to make boosting town relation cheaper.": "Меняет цену угощения горожан напитками в таверне, что повышает ваше отношение с городом. Уменьшите, чтобы дешевле улучшать отношение.",
    "Drinks price (denars)": "Цена напитков (динары)",
    "Prosperity loss when a fief is conquered": "Потеря процветания при захвате владения",
    "Sets how much prosperity a town or castle loses when it is conquered, both when the AI takes it and when you participate in the siege. Raise toward 0 to reduce the loss.": "Задаёт, сколько процветания теряет город или замок при захвате — и когда его берёт ИИ, и когда вы участвуете в осаде. Поднимите ближе к 0, чтобы уменьшить потерю.",
    "Loss when AI conquers": "Потеря при захвате ИИ",
    "Loss when you participate": "Потеря при вашем участии",
    "Prosperity from selling goods to villages": "Процветание от продажи товаров деревням",
    "Tunes the prosperity a village gains when you sell trade goods to its elder: the minimum gold the elder must hold, and the gold spent per +1 prosperity. Lower both to gain prosperity more easily.": "Настраивает процветание, которое получает деревня, когда вы продаёте товары её старосте: минимум золота у старосты и золото, нужное на +1 процветания. Уменьшите оба, чтобы легче повышать процветание.",
    "Elder's minimum gold": "Минимум золота старосты",
    "Gold per +1 prosperity": "Золота за +1 процветания",
    "Village bandit infestations": "Заражение деревень бандитами",
    "Changes the per-cycle chance of a village becoming infested with bandits and the prosperity lost every cycle while infested. Set the chance to 0 to eliminate infestations; raise the loss toward 0 to soften them.": "Меняет шанс за цикл, что деревня заразится бандитами, и потерю процветания за каждый цикл заражения. Установите шанс 0, чтобы убрать заражение; поднимите потерю к 0, чтобы смягчить.",
    "Infestation chance (%)": "Шанс заражения (%)",
    "Prosperity loss per cycle": "Потеря процветания за цикл",
    "Keep high-level garrison troops on assignment": "Сохранять высокоуровневые войска гарнизона при назначении",
    "Raises the level above which garrison troops are disbanded when a fief is assigned to you or your husband (31 by default). Higher value keeps more elite troops.": "Повышает уровень, выше которого войска гарнизона распускаются при назначении владения вам или вашему мужу (по умолчанию 31). Большее значение сохраняет больше элитных войск.",
    "Disband level threshold": "Порог уровня роспуска",
    "Chance of original-faction recruits in villages": "Шанс рекрутов родной фракции в деревнях",
    "Sets the chance that a conquered village offers recruits of its original faction. Default is a 20% chance (value 80). Set to 0 to guarantee it, or 100 to remove it.": "Задаёт шанс, что захваченная деревня предлагает рекрутов своей изначальной фракции. По умолчанию 20% (значение 80). 0 — гарантировать, 100 — убрать.",
    "Roll threshold": "Порог броска",
    "Always offered": "Всегда предлагается",
    "Never offered": "Никогда не предлагается",
    "Amount and tier of village recruits": "Количество и ранг деревенских рекрутов",
    "Controls how many recruits villages offer per tier. The game multiplies available troops by a numerator and divides by (denominator + tier). Raise the numerator or lower the denominator to get more recruits.": "Управляет тем, сколько рекрутов предлагают деревни по рангу. Игра умножает доступные войска на числитель и делит на (знаменатель + ранг). Увеличьте числитель или уменьшите знаменатель для большего числа рекрутов.",
    "Numerator (multiplier)": "Числитель (множитель)",
    "Denominator base": "База знаменателя",
    "Watch Tower effects in villages": "Эффекты сторожевых башен в деревнях",
    "Tunes village Watch Towers: the raid-slowdown modifier (a reciprocal time multiplier, 2/3 by default = +50% raid time) and the enemy spotting-range multiplier. Lower the modifier or raise the spotting multiplier for stronger towers.": "Настраивает деревенские сторожевые башни: модификатор замедления грабежа (обратный множитель времени, по умолчанию 2/3 = +50% времени) и множитель дальности обнаружения врагов. Уменьшите модификатор или поднимите множитель для более сильных башен.",
    "Raid modifier numerator": "Числитель модификатора грабежа",
    "Raid modifier denominator": "Знаменатель модификатора грабежа",
    "Spotting range multiplier": "Множитель дальности обнаружения",
    "Forced new-quest timer": "Таймер принудительного нового задания",
    "Sets the timer (in hours) after which kings, lords, ladies and village elders are forced to offer a new quest. Lower it to be offered quests more often.": "Задаёт таймер (в часах), после которого короли, лорды, дамы и деревенские старосты вынуждены предложить новое задание. Уменьшите, чтобы задания предлагали чаще.",
    "Hours between offers": "Часов между предложениями",
    "Chances when asking companions for troops": "Шансы при просьбе войск у спутников",
    "Tunes the quality roll when you ask a companion for more soldiers. The 'none' threshold is the chance of getting nothing; the 'low' and 'medium' thresholds split basic/medium/best tiers. Set the 'none' threshold to 0 to always get troops.": "Настраивает бросок качества, когда вы просите у спутника больше солдат. Порог «ничего» — шанс не получить ничего; пороги «низкий» и «средний» разделяют базовый/средний/лучший ранги. Установите порог «ничего» на 0, чтобы всегда получать войска.",
    "No-troops threshold": "Порог «без войск»",
    "Basic/medium threshold": "Порог базовые/средние",
    "Medium/best threshold": "Порог средние/лучшие",
    "Troop chances when companions return from gathering RTR": "Шансы войск при возвращении спутников со сбора ПНП",
    "Tunes the troops a companion brings back from gathering right to rule. For each player-level range you set the upper level bound and the chances (out of 100) for medium and elite troops; basic troops are always granted.": "Настраивает войска, которые спутник приносит со сбора права на престол. Для каждого диапазона уровня игрока вы задаёте верхнюю границу уровня и шансы (из 100) на средние и элитные войска; базовые предоставляются всегда.",
    "Range 1 upper level": "Верхний уровень диапазона 1",
    "Range 1 medium chance": "Шанс средних в диапазоне 1",
    "Range 1 elite chance": "Шанс элитных в диапазоне 1",
    "Range 2 upper level": "Верхний уровень диапазона 2",
    "Range 2 medium chance": "Шанс средних в диапазоне 2",
    "Range 2 elite chance": "Шанс элитных в диапазоне 2",
    "Range 3 upper level": "Верхний уровень диапазона 3",
    "Range 3 elite chance": "Шанс элитных в диапазоне 3",
    "Book reading time": "Время чтения книги",
    "Changes the divisor of a base value of 1000 that determines how many hours it takes to read a book (1000/7 = 143 hours by default). A higher divisor means faster reading.": "Меняет делитель базового значения 1000, что определяет, сколько часов занимает чтение книги (по умолчанию 1000/7 = 143 часа). Больший делитель — более быстрое чтение.",
    "Reading-time divisor": "Делитель времени чтения",
    "Noldor relation from books": "Отношение с Нолдорами от книг",
    "Sets how much Noldor relation you gain from reading the three Noldor lore books (Codex of the Righteous Ranger, Stolen Notes of Luciana of Ethos, The Ebon Libram of Laria). 10 each by default.": "Задаёт, сколько отношения с Нолдорами вы получаете за прочтение трёх книг о Нолдорах (Кодекс Праведного Следопыта, Похищенные записки Лучианы из Этоса, Чёрный Либрам Ларии). По умолчанию по 10.",
    "Relation points per book": "Очков отношения за книгу",
    "Skill bonuses from carried books": "Бонусы навыков от носимых книг",
    "Sets the temporary skill bonus granted while these three books are in your inventory: Wound Treatment (Herbal Remedies), Trainer (Life of the Legionnaire) and Surgery (Field Surgeon's Handbook). Raise for stronger bonuses.": "Задаёт временный бонус навыка, пока эти три книги в вашем инвентаре: Лечение ран (Травяные средства), Тренер (Жизнь легионера) и Хирургия (Справочник полевого хирурга). Поднимите для более сильных бонусов.",
    "Wound Treatment bonus": "Бонус лечения ран",
    "Trainer bonus": "Бонус тренера",
    "Surgery bonus": "Бонус хирургии",
    "Resting speed multiplier": "Множитель скорости отдыха",
    "Sets how fast time passes while resting compared to travelling, across all resting spots (settlements, manor villages and camping). Higher passes time faster, but very high values can cause stutters.": "Задаёт, насколько быстрее идёт время во время отдыха по сравнению с путешествием, для всех мест отдыха (поселения, деревни с поместьем и лагерь). Выше — быстрее, но очень высокие значения могут вызывать подтормаживания.",
    "Speed multiplier": "Множитель скорости",
    "Donating money to townsfolk": "Пожертвования горожанам",
    "Always shows the option to help the poor when talking to townsfolk, and sets the amount of denars you give them. The amount is also the minimum gold you must have for the option to appear.": "Всегда показывает вариант помочь беднякам в разговоре с горожанами и задаёт сумму динаров, которую вы даёте. Эта сумма также является минимумом золота, нужным для появления варианта.",
    "Donation amount (denars)": "Сумма пожертвования (динары)",
    "Alternative female faces": "Улучшенные женские лица",
    "Prettier female face meshes and textures (PoP Helper's faces1).": "Более красивые меши и текстуры женских лиц (faces1 из PoP Helper).",
    "Crosshair": "Прицел",
    "Replace the aiming crosshair — choose a style.": "Замена прицела при стрельбе — выберите стиль.",
    "Crosshair 1": "Прицел 1",
    "Crosshair 2": "Прицел 2",
    "Crosshair 3": "Прицел 3",
    "Crosshair 4": "Прицел 4",
    "Crosshair 5": "Прицел 5",
    "Crosshair 6": "Прицел 6",
    "Crosshair 7": "Прицел 7",
    "Crosshair 8": "Прицел 8",
    "Crosshair 9": "Прицел 9",
    "Crosshair 10": "Прицел 10",
    "Crosshair 11": "Прицел 11",
    "Crosshair 12": "Прицел 12",
    "Crosshair 13": "Прицел 13",
    "Crosshair 14": "Прицел 14",
    "Crosshair 15": "Прицел 15",
    "Crosshair 16": "Прицел 16",
    "Crosshair 17": "Прицел 17",
    "Crosshair 18": "Прицел 18",
    "Crosshair 19": "Прицел 19",
    "Crosshair 20": "Прицел 20",
    "UI skin": "Скин интерфейса",
    "Dezlaros UI pack — reskin the in-game panels.": "UI-пак Dezlaros — меняет вид игровых панелей.",
    "Game of Thrones": "Game of Thrones",
    "Knightly": "Knightly",
    "Native Gold": "Native Gold",
    "Native Green": "Native Green",
    "Native Purple": "Native Purple",
    "Native Red": "Native Red",
    "Native Silver": "Native Silver",
    "Native Yellow": "Native Yellow",
    "Vaegir": "Vaegir",
    "Vaegir Gold": "Vaegir Gold",
    "Arena Overhaul": "Обновлённые арены",
    "Reworked tournament arena scenes.": "Переработанные сцены турнирных арен.",
    "Font": "Шрифт",
    "Alternative in-game font.": "Альтернативный игровой шрифт.",
    "Old Qualis Gem look": "Старый вид камня Квалис",
    "Restore the old Qualis Gem appearance.": "Вернуть старый вид камня Квалис.",
    "Collision fixes": "Исправления коллизий",
    "Mesh collision fixes (PoP Helper's colfix).": "Исправления коллизий мешей (colfix из PoP Helper).",
}


def walk(o, stats, missing):
    if isinstance(o, dict):
        if isinstance(o.get("en"), str) and isinstance(o.get("uk"), str):
            stats["total"] += 1
            if not o.get("ru"):
                en = o["en"]
                if en in RU:
                    o["ru"] = RU[en]
                    stats["added"] += 1
                else:
                    missing.append(en)
        for v in o.values():
            walk(v, stats, missing)
    elif isinstance(o, list):
        for v in o:
            walk(v, stats, missing)


def collect_codes(o, codes):
    """Collect all original/replacement/from/to opcode strings for byte-compare."""
    if isinstance(o, dict):
        for k in ("original", "replacement", "from", "to"):
            if isinstance(o.get(k), str):
                codes.append((k, o[k]))
        for v in o.values():
            collect_codes(v, codes)
    elif isinstance(o, list):
        for v in o:
            collect_codes(v, codes)


def process(path):
    with open(path, encoding="utf-8") as f:
        db = json.load(f)
    stats = {"total": 0, "added": 0}
    missing = []
    walk(db, stats, missing)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(db, f, ensure_ascii=False, indent=2)
        f.write("\n")
    return stats, missing


def git_head_json(rel):
    out = subprocess.run(
        ["git", "show", f"HEAD:{rel}"],
        cwd=ROOT, capture_output=True, text=True)
    if out.returncode != 0:
        return None  # file not committed yet
    return json.loads(out.stdout)


def main():
    files = [
        (TWEAKS, "PoPHelper/Resources/tweaks.json"),
        (PACKS, "PoPHelper/Resources/packs.json"),
    ]
    # Snapshot HEAD codes BEFORE writing (in case nothing committed -> snapshot now)
    head_codes = {}
    for path, rel in files:
        head = git_head_json(rel)
        if head is not None:
            c = []
            collect_codes(head, c)
            head_codes[rel] = c

    ok = True
    for path, rel in files:
        stats, missing = process(path)
        print(f"{rel}: {stats['added']} ru added / {stats['total']} localized objects")
        if missing:
            ok = False
            print(f"  MISSING ru for {len(missing)} string(s):")
            for m in missing:
                print(f"    - {m!r}")

    # Reload and verify every localized object has non-empty ru
    print("\nVerification pass:")
    for path, rel in files:
        with open(path, encoding="utf-8") as f:
            db = json.load(f)
        empties = []

        def check(o):
            if isinstance(o, dict):
                if isinstance(o.get("en"), str) and isinstance(o.get("uk"), str):
                    if not (isinstance(o.get("ru"), str) and o["ru"].strip()):
                        empties.append(o.get("en"))
                for v in o.values():
                    check(v)
            elif isinstance(o, list):
                for v in o:
                    check(v)
        check(db)
        if empties:
            ok = False
            print(f"  {rel}: {len(empties)} object(s) missing ru: {empties}")
        else:
            print(f"  {rel}: all localized objects have non-empty ru")

        # Byte-identical code check vs HEAD
        if rel in head_codes:
            now = []
            collect_codes(db, now)
            if now == head_codes[rel]:
                print(f"  {rel}: opcode strings BYTE-IDENTICAL to HEAD "
                      f"({len(now)} code strings)")
            else:
                ok = False
                print(f"  {rel}: OPCODE MISMATCH vs HEAD!")
                hc = dict(enumerate(head_codes[rel]))
                for i, (a, b) in enumerate(zip(head_codes[rel], now)):
                    if a != b:
                        print(f"    idx {i}: {a!r} -> {b!r}")
                if len(head_codes[rel]) != len(now):
                    print(f"    count {len(head_codes[rel])} -> {len(now)}")
        else:
            print(f"  {rel}: not in HEAD (new file); skipping code byte-compare")

    if not ok:
        sys.exit(1)
    print("\nADD_RU: all good")


if __name__ == "__main__":
    main()
