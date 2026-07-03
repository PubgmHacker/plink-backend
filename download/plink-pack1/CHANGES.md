// Pack 1.1: Обновлённые TTL токенов
//
// Что изменилось:
// 1. Access token: 15 минут → 7 дней (не выкидывает из 6-часового фильма)
// 2. Refresh token: 30 дней → 90 дней (редко просит пароль)
// 3. Signin rate limit: 5/min → 10/5min
// 4. Signup rate limit: 3/hour → 5/20min
// 5. Refresh rate limit: 30/min → 60/min (т.к. каждый запуск приложения)

// Файлы изменены:
// - src/config/index.ts  (TTL через env)
// - src/routes/auth.ts   (новые rate limits)
// - src/utils/tokens.ts  (парсинг TTL строки)

// Можно переопределить в Railway Variables:
//   ACCESS_TOKEN_TTL = 30d   (если хотите ещё дольше)
//   REFRESH_TOKEN_TTL_DAYS = 365  (если хотите год)
