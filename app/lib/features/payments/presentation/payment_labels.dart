/// Периоды повтора, доступные в форме: месяцы → подпись.
const periodOptions = <int, String>{
  1: 'Каждый месяц',
  2: 'Раз в 2 месяца',
  3: 'Раз в квартал',
  6: 'Раз в полгода',
  12: 'Раз в год',
};

String periodLabel(int months) => periodOptions[months] ?? 'Раз в $months мес.';

/// За сколько дней напоминать: дни → подпись.
const remindOptions = <int, String>{
  0: 'В день платежа',
  1: 'За 1 день',
  3: 'За 3 дня',
  7: 'За неделю',
};

String remindLabel(int days) => remindOptions[days] ?? 'За $days дн.';
