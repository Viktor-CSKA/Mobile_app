import 'payment_schedule.dart';

/// Готовый шаблон платежа: заполняет форму «Новый платёж». Цены намеренно
/// не указаны: тарифы меняются, сумму вводит пользователь.
class PaymentTemplate {
  const PaymentTemplate(
    this.name,
    this.categoryName, {
    this.periodMonths = 1,
    this.variableAmount = false,
    this.remindDaysBefore = 1,
    this.dayOfMonth,
    this.yearlyMonth,
    this.yearlyDay,
    this.popular = false,
  });

  final String name;

  /// Название категории из стандартного набора (связь по названию, а не по
  /// номеру: после восстановления из копии номера могут отличаться).
  final String categoryName;
  final int periodMonths;

  /// Сумма каждый раз разная (коммунальные услуги).
  final bool variableAmount;
  final int remindDaysBefore;

  /// Обычный день платежа в месяце (например, ЖКУ — до 10-го числа).
  final int? dayOfMonth;

  /// Ежегодный срок оплаты (налоги — 1 декабря).
  final int? yearlyMonth;
  final int? yearlyDay;

  /// Показывать в быстром выборе над формой.
  final bool popular;
}

/// Подходящая дата ближайшего платежа для шаблона или null, если у шаблона
/// нет привычного срока (тогда остаётся сегодняшняя дата).
DateTime? suggestedDue(PaymentTemplate t, DateTime today) {
  final now = dateOnly(today);
  final month = t.yearlyMonth;
  final day = t.yearlyDay;
  if (month != null && day != null) {
    var candidate = DateTime(now.year, month, day);
    if (candidate.isBefore(now)) candidate = DateTime(now.year + 1, month, day);
    return candidate;
  }
  final dom = t.dayOfMonth;
  if (dom != null) {
    var candidate = dueDateInMonth(now.year, now.month, dom);
    if (candidate.isBefore(now)) {
      final next = DateTime(now.year, now.month + 1);
      candidate = dueDateInMonth(next.year, next.month, dom);
    }
    return candidate;
  }
  return null;
}

/// Номер категории шаблона среди [categories] (пары «номер, название»);
/// null, если такой категории нет.
int? categoryIdFor(
  PaymentTemplate t,
  Iterable<({int id, String name})> categories,
) {
  for (final c in categories) {
    if (c.name == t.categoryName) return c.id;
  }
  return null;
}

String _norm(String s) => s.toLowerCase().replaceAll('ё', 'е').trim();

/// Шаблоны, подходящие под запрос: по названию или категории, без учёта
/// регистра и различия «е/ё». Пустой запрос возвращает всё.
List<PaymentTemplate> searchTemplates(String query) {
  final q = _norm(query);
  if (q.isEmpty) return paymentTemplates;
  return [
    for (final t in paymentTemplates)
      if (_norm(t.name).contains(q) || _norm(t.categoryName).contains(q)) t,
  ];
}

/// Быстрый выбор над формой.
List<PaymentTemplate> get popularTemplates => [
  for (final t in paymentTemplates)
    if (t.popular) t,
];

const _utilities = 'ЖКХ';
const _credit = 'Кредиты и ипотека';
const _installments = 'Рассрочки';
const _subs = 'Подписки';
const _telecom = 'Связь и интернет';
const _taxes = 'Налоги и штрафы';
const _insurance = 'Страховка';
const _other = 'Прочее';

/// Каталог шаблонов, сгруппирован по категориям в порядке показа.
const paymentTemplates = <PaymentTemplate>[
  // ЖКХ: сумма меняется, счёт обычно до 10-го числа.
  PaymentTemplate(
    'Электричество',
    _utilities,
    variableAmount: true,
    dayOfMonth: 10,
    popular: true,
  ),
  PaymentTemplate(
    'Водоснабжение',
    _utilities,
    variableAmount: true,
    dayOfMonth: 10,
  ),
  PaymentTemplate('Газ', _utilities, variableAmount: true, dayOfMonth: 10),
  PaymentTemplate(
    'Отопление',
    _utilities,
    variableAmount: true,
    dayOfMonth: 10,
  ),
  PaymentTemplate(
    'Квартплата (ЖКУ)',
    _utilities,
    variableAmount: true,
    dayOfMonth: 10,
    popular: true,
  ),
  PaymentTemplate('Капитальный ремонт', _utilities, dayOfMonth: 10),
  PaymentTemplate('Вывоз мусора', _utilities, dayOfMonth: 10),
  PaymentTemplate('Домофон', _utilities, dayOfMonth: 10),

  PaymentTemplate('Кредит', _credit, popular: true),
  PaymentTemplate('Ипотека', _credit, popular: true),
  PaymentTemplate('Автокредит', _credit),
  PaymentTemplate('Кредитная карта', _credit),

  PaymentTemplate('Долями', _installments),
  PaymentTemplate('Плайт', _installments),
  PaymentTemplate('Яндекс Сплит', _installments),
  PaymentTemplate('Рассрочка в магазине', _installments),

  PaymentTemplate('Яндекс Плюс', _subs, popular: true),
  PaymentTemplate('Кинопоиск', _subs),
  PaymentTemplate('Okko', _subs),
  PaymentTemplate('Wink', _subs),
  PaymentTemplate('ivi', _subs),
  PaymentTemplate('START', _subs),
  PaymentTemplate('PREMIER', _subs),
  PaymentTemplate('VK Музыка', _subs),
  PaymentTemplate('Звук', _subs),
  PaymentTemplate('СберПрайм', _subs),
  PaymentTemplate('МТС Premium', _subs),
  PaymentTemplate('Telegram Premium', _subs),
  PaymentTemplate('Яндекс 360', _subs),
  PaymentTemplate('Облачное хранилище', _subs),

  PaymentTemplate('Мобильная связь', _telecom, popular: true),
  PaymentTemplate('Домашний интернет', _telecom, popular: true),
  PaymentTemplate('Телевидение', _telecom),

  // Налоги на имущество физлиц платят до 1 декабря раз в год.
  PaymentTemplate(
    'Налог на имущество',
    _taxes,
    periodMonths: 12,
    remindDaysBefore: 7,
    yearlyMonth: 12,
    yearlyDay: 1,
  ),
  PaymentTemplate(
    'Транспортный налог',
    _taxes,
    periodMonths: 12,
    remindDaysBefore: 7,
    yearlyMonth: 12,
    yearlyDay: 1,
  ),
  PaymentTemplate(
    'Земельный налог',
    _taxes,
    periodMonths: 12,
    remindDaysBefore: 7,
    yearlyMonth: 12,
    yearlyDay: 1,
  ),

  PaymentTemplate('ОСАГО', _insurance, periodMonths: 12, remindDaysBefore: 7),
  PaymentTemplate('КАСКО', _insurance, periodMonths: 12, remindDaysBefore: 7),
  PaymentTemplate(
    'Страхование ипотеки',
    _insurance,
    periodMonths: 12,
    remindDaysBefore: 7,
  ),
  PaymentTemplate(
    'Страхование квартиры',
    _insurance,
    periodMonths: 12,
    remindDaysBefore: 7,
  ),

  PaymentTemplate('Аренда жилья', _other),
  PaymentTemplate('Детский сад', _other),
  PaymentTemplate('Кружки и секции', _other),
  PaymentTemplate('Спортзал', _other),
  PaymentTemplate('Парковка', _other),
];
