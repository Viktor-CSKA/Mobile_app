const _monthsShort = [
  'янв',
  'фев',
  'мар',
  'апр',
  'мая',
  'июн',
  'июл',
  'авг',
  'сен',
  'окт',
  'ноя',
  'дек',
];

const _monthsGenitive = [
  'января',
  'февраля',
  'марта',
  'апреля',
  'мая',
  'июня',
  'июля',
  'августа',
  'сентября',
  'октября',
  'ноября',
  'декабря',
];

const _monthsNominative = [
  'Январь',
  'Февраль',
  'Март',
  'Апрель',
  'Май',
  'Июнь',
  'Июль',
  'Август',
  'Сентябрь',
  'Октябрь',
  'Ноябрь',
  'Декабрь',
];

/// Заголовок месяца: `2026-10-05` → `Октябрь 2026`.
String formatMonthYear(DateTime d) =>
    '${_monthsNominative[d.month - 1]} ${d.year}';

/// Дни недели с понедельника.
const weekdaysShortRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// `2026-10-05` → `5 окт`.
String formatDayMonthShort(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]}';

/// `2026-10-05` → `5 октября 2026`.
String formatDateFull(DateTime d) =>
    '${d.day} ${_monthsGenitive[d.month - 1]} ${d.year}';

/// `2026-10-05 18:07` → `5 окт, 18:07`.
String formatDayMonthTime(DateTime d) =>
    '${formatDayMonthShort(d)}, '
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
