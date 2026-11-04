/// Сколько дней до платежа словами: `0` → «сегодня», `-3` → «просрочено на 3 дн.».
String dueLabel(int daysUntil) {
  if (daysUntil < 0) return 'просрочено на ${-daysUntil} дн.';
  if (daysUntil == 0) return 'сегодня';
  if (daysUntil == 1) return 'завтра';
  return 'через $daysUntil дн.';
}
