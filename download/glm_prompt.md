# Текст обращения к GLM-5.2 (для прикрепления к обновлённому PDF)

Файл: RaveClone_Audit_Report.pdf (64 страницы, ~28K токенов)

---

## Готовый промпт (копировать целиком)

```
Привет! Прикрепил обновлённый PDF — это полный аудит RaveClone (клон Rave / 
SyncWatch / Плинк) + готовая премиум дизайн-система.

ОБЪЁМ: 64 страницы, ~28K токенов. Должно влезть в твой контекст целиком.

СТРУКТУРА PDF:
• 00 — Краткое резюме (155 багов: 27 критич / 46 высоких / 43 средних / 37 низких)
• 01 — Топ-5 приоритетов (что фиксить первым делом)
• 02 — СПЕЦ-ЗАДАЧА: не работает анимированный фон (5 причин + drop-in фикс)
• 03 — iOS: 60 багов (C1-C14, H1-H14, M1-M16, L1-L16)
• 04 — Backend: 34 бага (B1-B34)
• 05 — React Native: 61 баг (R1-R61)
• 06 — РЕДИЗАЙН: премиум дизайн-система «Cinema Violet» (НОВЫЙ РАЗДЕЛ)
• 07 — Дорожная карта (9 этапов)

Bug IDs стабильны — ссылайся на них (C1, B3, R11, и т.д.).

═══════════════════════════════════════════════════════════
ЗАДАЧА ПРИОРИТЕТ #1 — РЕДИЗАЙН (раздел 06)
═══════════════════════════════════════════════════════════

Сейчас всё приложение бирюзовое (#00C2FF / #00FF88) — это выглядит дёшево для 
premium watch-party продукта. Конкуренты (Rave, Hearo, Disney+, Apple Music) 
используют тёплые глубокие тона. Я спроектировал новую палитру «Cinema Violet»:
- Primary: фиолетовый #A855F7 (вместо бирюзового)
- Accent: магента #EC4899
- Premium: золото #FBBF24 (НОВЫЙ — только для premium-tier)
- Background: глубокий чёрный с фиолетовым подтоном #08080C

КЛЮЧЕВЫЕ ПРИНЦИПЫ ДИЗАЙНА:
1. Free-юзер — БЕЗ обводки на аватарке (минимум визуального шума)
2. Premium-юзер — анимированное золотое кольцо (8s/оборот, не раздражает)
3. Host в комнате — статичная magenta обводка
4. Admin — статичная фиолетовая обводка (глобально)
5. Приоритет ролей: admin > premium > host > free
6. Premium Subscribe button — gold gradient, чёрный текст (макс контраст)
7. Primary CTA — violet→magenta gradient, белый текст
8. Золото ИСПОЛЬЗУЕТСЯ ТОЛЬКО для premium-сигналов (не для обычных CTA)

В PDF РАЗДЕЛА 06 УЖЕ ГОТОВ КОД (drop-in):
• 6.9  — Color+Theme.swift (полная замена, ~140 строк)
• 6.10 — PremiumAvatar.swift (новый файл, ~120 строк, 4 роли)
• 6.11 — PremiumButtonStyle.swift (5 стилей + modifier helpers)
• 6.12 — AnimatedGradientBackground.swift (обновлённый + LiveBadge/PremiumBadge/HostBadge/AdminBadge)

ПОРЯДОК ДЕЙСТВИЙ (строго по плану миграции 6.13):

ШАГ 1: Заменить Color+Theme.swift целиком (код из 6.9)
       Файл: RaveClone/RaveClone/Extensions/Color+Theme.swift
       После этого все ravePrimary/raveAccent получат новые цвета автоматически.

ШАГ 2: Создать PremiumAvatar.swift (код из 6.10)
       Файл: RaveClone/RaveClone/Views/Components/PremiumAvatar.swift (новый)

ШАГ 3: Обновить AnimatedGradientBackground.swift целиком (код из 6.12)
       Файл: RaveClone/RaveClone/Views/Components/AnimatedGradientBackground.swift
       Включает badges (LiveBadge, PremiumBadge, HostBadge, AdminBadge).
       Заодно фиксит баг из раздела 02 (TimelineView вместо withAnimation).

ШАГ 4: Заменить старые Circle()-аватарки на PremiumAvatar во views:
       - Views/Home/HomeView.swift (header avatar)
       - Views/Room/ParticipantListView.swift (список участников)
       - Views/Room/RoomChatView.swift (chat bubbles)
       - Views/Profile/ProfileView.swift
       - Views/Friends/FriendsView.swift
       - Views/Admin/AdminPanelView.swift
       Для каждого юзера определяй роль через AvatarRole.dominant([.premium, .host])
       на основе user.isPremium и текущего контекста (isHostInRoom).

ШАГ 5: Заменить кнопки:
       - .buttonStyle(PremiumButtonStyle()) → оставить для primary CTA
       - Добавить .premiumSubscribeButton() для PaywallView
       - Добавить .secondaryButton() для Cancel/Back
       - Добавить .ghostButton() для "Forgot password"
       - Добавить .iconButton() для mute/settings/share

ШАГ 6: Добавить PremiumBadge рядом с именем premium-юзера в чате 
       и списке участников.

═══════════════════════════════════════════════════════════
ЗАДАЧА ПРИОРИТЕТ #2 — БАГИ (после редизайна)
═══════════════════════════════════════════════════════════

После завершения редизайна переходи к багам по дорожной карте (раздел 07):
• Этап 1 (realtime unlock): iOS C1 + Backend B1+B2
• Этап 2 (auth security): iOS C2,C3 + RN R2,R3,R4,R5
• Этап 3 (service DI): iOS C4-C8
• Этап 4 (IAP & premium): iOS C9, M5 + B5
• Этап 5 (iOS infra): iOS H3,H4,H5,H8,H10,H13
• Этапы 6-9 — по порядку

═══════════════════════════════════════════════════════════
ПРАВИЛА РАБОТЫ
═══════════════════════════════════════════════════════════

1. Не пытайся делать всё сразу — строго по шагам миграции 6.13
2. Для каждого изменения: называй bug ID / шаг / файл / что меняешь
3. Если нужен контекст из других файлов — проси, я скину
4. iOS-код = основная платформа, RN — экспериментальная ветка
5. Backend деплоится на Railway
6. Если в PDF есть код — используй его 1:1, не выдумывай свой
7. Перед каждым коммитом показывай diff и объясняй, что менялось

Жду:
1. Подтверждения, что прочитал PDF и понял структуру
2. Краткое резюме плана миграции (6 шагов) своими словами
3. Первый коммит — ШАГ 1: замена Color+Theme.swift
```

---

## Короткая версия (если хочется быстрее)

```
Прикрепил PDF (64 стр) — аудит RaveClone + готовая премиум дизайн-система.

СРОЧНО: редизайн по разделу 06. Сейчас всё бирюзовое — дёшево для premium 
продукта. Новая палитра «Cinema Violet»: фиолетовый #A855F7 + золото #FBBF24 
для premium-tier + магента #EC4899.

В PDF уже готов drop-in код:
- 6.9  Color+Theme.swift (замена)
- 6.10 PremiumAvatar.swift (4 роли: free/premium/host/admin)
- 6.11 PremiumButtonStyle.swift (5 стилей кнопок)
- 6.12 AnimatedGradientBackground.swift (обновлённый + badges)

Ключевое правило: у free-юзера НЕТ обводки на аватаре. Premium — gold ring 
animated. Host — magenta static. Admin — violet static.

Сделай ШАГ 1 из плана миграции 6.13: замени Color+Theme.swift. 
Потом по шагам 2-6. После редизайна — баги по дорожной карте раздела 07.

Подтверди, что прочитал, и скинь первый патч.
```

---

## Что GLM-5.2 должен сделать в первом ответе

1. Подтвердить чтение PDF
2. Переформулировать план миграции (6 шагов) своими словами — это проверка, что он "въехал"
3. Выдать первый коммит — ШАГ 1: полная замена `Color+Theme.swift`

Если он пропускает подтверждение и сразу пишет код — попросить его всё-таки сначала резюмировать план. Это важно для последующих шагов, иначе он может начать выдумывать свой подход вместо использования готового кода из PDF.
