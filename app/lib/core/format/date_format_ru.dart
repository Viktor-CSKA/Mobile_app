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

/// `2026-10-05` → `5 окт`.
String formatDayMonthShort(DateTime d) =>
    '${d.day} ${_monthsShort[d.month - 1]}';

/// `2026-10-05` → `5 октября 2026`.
String formatDateFull(DateTime d) =>
    '${d.day} ${_monthsGenitive[d.month - 1]} ${d.year}';
