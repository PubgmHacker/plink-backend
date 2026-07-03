# Текст обращения к GLM-5.2 (для прикрепления к обновлённому PDF v2)

Файл: RaveClone_Audit_Report.pdf (69 страниц, ~31K токенов)

---

## Готовый промпт (копировать целиком)

```
Привет! Прикрепил обновлённый PDF v2 — полный аудит RaveClone (клон Rave / 
SyncWatch / Плинк) + переработанная премиум дизайн-система «Cinema Violet v2».

ОБЪЁМ: 69 страниц, ~31K токенов. Должно влезть в контекст целиком.

СТРУКТУРА PDF:
• 00 — Краткое резюме (155 багов: 27 критич / 46 высоких / 43 средних / 37 низких)
• 01 — Топ-5 приоритетов
• 02 — СПЕЦ-ЗАДАЧА: не работает анимированный фон (5 причин + drop-in фикс)
• 03 — iOS: 60 багов (C1-C14, H1-H14, M1-M16, L1-L16)
• 04 — Backend: 34 бага (B1-B34)
• 05 — React Native: 61 баг (R1-R61)
• 06 — РЕДИЗАЙН: премиум дизайн-система «Cinema Violet v2» (НОВЫЙ, ОСНОВНОЙ)
• 07 — Дорожная карта (9 этапов)

═══════════════════════════════════════════════════════════
ГЛАВНАЯ ЗАДАЧА — РЕДИЗАЙН (раздел 06)
═══════════════════════════════════════════════════════════

Я полностью переработал дизайн-систему. ВАЖНО: версия v2 ОЧЕНЬ отличается от 
того, что я обсуждал раньше. КЛЮЧЕВЫЕ ПРИНЦИПЫ:

1. УБРАТЬ ЗОЛОТО. Никаких #FBBF24, #FCD34D, #D97706. Золото = клише.
2. Premium = переименован в "Плинк+" (Plink+, НЕ Premium)
3. Плинк+ палитра = violet #A855F7 + magenta #EC4899 + fuchsia #D946EF
4. Admin = ЧИСТЫЙ КРАСНЫЙ #FF1744 (не фиолетовый!)
5. ПОСТОЯННАЯ АНИМАЦИЯ обводки аватара (вращение 360° за 4s, никогда не 
   останавливается)
6. ПЕРЕЛИВАЮЩИЙСЯ НИК — анимированный hue rotation 360° за 3s через spectrum 
   цветов (violet→magenta→fuchsia для Плинк+, red→light red→deep red для админа)
7. Free-юзер — БЕЗ обводки, БЕЗ анимации (минимум визуального шума)
8. Host — статичная магента (временная роль, не анимировать)
9. Приоритет ролей: admin > plink > host > free
10. Subscribe button — gradient + animated shimmer overlay (белая полоса света 
    каждые 2s)
11. Фон — violet+magenta+fuchsia orbs через TimelineView (БЕЗ золота)

ГОТОВЫЙ DROP-IN КОД В PDF:
• 6.10 — Color+Theme.swift (полная замена, убраны все ravePremium* gold цвета, 
         добавлены ravePlink* и raveAdmin*)
• 6.11 — PremiumAvatar.swift (4 роли, ПОСТОЯННАЯ анимация через rotationEffect)
• 6.12 — AnimatedNickText.swift (НОВЫЙ файл — переливающиеся ники через 
         hueRotation)
• 6.13 — PremiumButtonStyle.swift (5 стилей + PlinkSubscribeButtonStyle с 
         animated shimmer)
• 6.14 — AnimatedGradientBackground.swift (обновлённый + PlinkBadge/AdminBadge 
         с shimmer)

ПОРЯДОК ДЕЙСТВИЙ (строго по плану миграции 6.15, 7 шагов):

ШАГ 1: Заменить Color+Theme.swift целиком (код 6.10)
       Файл: RaveClone/RaveClone/Extensions/Color+Theme.swift
       Удаляет все ravePremium* (gold), добавляет ravePlink*, raveAdmin*.
       Все старые ссылки на ravePrimary автоматически получают violet.

ШАГ 2: Создать PremiumAvatar.swift (код 6.11)
       Файл: RaveClone/RaveClone/Views/Components/PremiumAvatar.swift (новый)
       4 роли: free/plink/host/admin. ПОСТОЯННАЯ анимация для plink и admin 
       через rotationEffect 360° / 4s.

ШАГ 3: Создать AnimatedNickText.swift (код 6.12)
       Файл: RaveClone/RaveClone/Views/Components/AnimatedNickText.swift (новый)
       Переливающиеся ники через LinearGradient + hueRotation.
       4 стиля: free/plink/host/admin.

ШАГ 4: Обновить AnimatedGradientBackground.swift целиком (код 6.14)
       Файл: RaveClone/RaveClone/Views/Components/AnimatedGradientBackground.swift
       Фон становится violet+magenta+fuchsia (БЕЗ золота).
       Добавлены PlinkBadge, AdminBadge с animated shimmer.
       Заодно фиксит баг из раздела 02 (TimelineView вместо withAnimation).

ШАГ 5: Заменить PremiumButtonStyle.swift (код 6.13)
       Файл: RaveClone/RaveClone/Views/Components/PremiumButtonStyle.swift
       PlinkSubscribeButtonStyle с animated shimmer overlay.

ШАГ 6: Заменить старые Circle()-аватарки на PremiumAvatar + ники на 
       AnimatedNickText во views:
       - Views/Home/HomeView.swift (header avatar)
       - Views/Room/ParticipantListView.swift (список участников)
       - Views/Room/RoomChatView.swift (chat bubbles)
       - Views/Profile/ProfileView.swift
       - Views/Friends/FriendsView.swift
       - Views/Admin/AdminPanelView.swift
       Для каждого юзера определяй роль через AvatarRole.dominant([.plink, .host]) 
       на основе user.isPremium и текущего контекста (isHostInRoom).

ШАГ 7: Добавить PlinkBadge и AdminBadge в чат и список участников.

═══════════════════════════════════════════════════════════
КРИТИЧЕСКИЕ ПРАВИЛА (НЕ НАРУШАТЬ)
═══════════════════════════════════════════════════════════

1. БИРЮЗОВЫЙ ЗАПРЕЩЁН. Никаких #00C2FF, #00FFCC, #00FF88.
2. ЗОЛОТО ЗАПРЕЩЕНО. Никаких #FBBF24, #FCD34D, #D97706.
3. Premium → Плинк+ везде (код, UI тексты, badges).
4. ПОСТОЯННАЯ анимация кольца Плинк+ и админа (никогда не останавливается).
5. ПОСТОЯННАЯ анимация переливания ника Плинк+ и админа.
6. Free — без анимаций, без обводки, без glow.
7. Host — статичная магента (НЕ анимировать).
8. Если у юзера несколько ролей — приоритет admin > plink > host > free.

═══════════════════════════════════════════════════════════
ПОСЛЕ РЕДИЗАЙНА — БАГИ
═══════════════════════════════════════════════════════════

После завершения редизайна переходи к багам по дорожной карте (раздел 07):
• Этап 1 (realtime unlock): iOS C1 + Backend B1+B2
• Этап 2 (auth security): iOS C2,C3 + RN R2,R3,R4,R5
• Этап 3 (service DI): iOS C4-C8
• Этап 4 (IAP & Плинк+): iOS C9, M5 + B5
• Этап 5 (iOS infra): iOS H3,H4,H5,H8,H10,H13
• Этапы 6-9 — по порядку

═══════════════════════════════════════════════════════════
ПРАВИЛА РАБОТЫ
═══════════════════════════════════════════════════════════

1. Не пытайся делать всё сразу — строго по 7 шагам миграции 6.15
2. Для каждого изменения: называй шаг / файл / что меняешь
3. Если нужен контекст из других файлов — проси, я скину
4. iOS-код = основная платформа, RN — экспериментальная ветка
5. Backend деплоится на Railway
6. Если в PDF есть код — используй его 1:1, не выдумывай свой
7. Reduce Motion accessibility: при включённом Reduce Motion анимации 
   отключаются, остаётся статичный gradient (см. чек-лист 6.17)

ЖДУ:
1. Подтверждения, что прочитал PDF v2 и понял структуру
2. Краткое резюме ключевых отличий v2 от v1 (убрать золото, premium=Плинк+, 
   admin=красный, постоянная анимация, переливающийся ник)
3. Первый коммит — ШАГ 1: замена Color+Theme.swift
```

---

## Короткая версия (если хочется быстрее)

```
Прикрепил PDF v2 (69 стр) — аудит RaveClone + переработанная премиум 
дизайн-система «Cinema Violet v2».

ОСНОВНОЕ: раздел 06 — редизайн. Ключевые отличия от v1:
1. УБРАТЬ ЗОЛОТО (никаких #FBBF24 и подобных)
2. Premium → Плинк+ (violet #A855F7 + magenta #EC4899 + fuchsia #D946EF)
3. Admin = КРАСНЫЙ #FF1744 (не фиолетовый!)
4. ПОСТОЯННАЯ анимация обводки аватара (rotation 360° / 4s, не останавливается)
5. ПЕРЕЛИВАЮЩИЙСЯ НИК (hueRotation 360° / 3s через spectrum)
6. Free — без обводки/анимации. Host — статичная магента.

В PDF готов drop-in код:
- 6.10 Color+Theme.swift (замена, без золота)
- 6.11 PremiumAvatar.swift (постоянная анимация rotation)
- 6.12 AnimatedNickText.swift (переливающиеся ники через hueRotation)
- 6.13 PremiumButtonStyle.swift (5 стилей + Плинк+ shimmer button)
- 6.14 AnimatedGradientBackground.swift (violet+magenta фон + badges)

Сделай ШАГ 1 из плана миграции 6.15: замени Color+Theme.swift.
Потом по шагам 2-7. После редизайна — баги по дорожной карте раздела 07.

Подтверди, что прочитал, и скинь первый патч.
```

---

## Что GLM-5.2 должен сделать в первом ответе

1. Подтвердить чтение PDF v2
2. Переформулировать ключевые отличия v2 от v1 своими словами:
   - Убрано золото
   - Premium → Плинк+
   - Admin = красный (не фиолетовый)
   - Постоянная анимация обводки
   - Переливающийся ник через hueRotation
3. Выдать первый коммит — ШАГ 1: полная замена `Color+Theme.swift`

Если GLM-5.2 пропускает подтверждение и сразу пишет код — попросить его всё-таки сначала резюмировать отличия. Это критично, потому что если он использует старый v1-код (с золотом), придётся переделывать.
