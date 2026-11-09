import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_hbb/raatik/history/history_repository.dart';
import 'package:shamsi_date/shamsi_date.dart';

void main() {
  test('today is the local midnight inclusive through the next midnight', () {
    final now = DateTime(2026, 11, 8, 12, 30);
    final range = localDateRange(HistoryDateFilter.today, now);
    final start = DateTime(2026, 11, 8);
    final next = DateTime(2026, 11, 9);
    expect(range.fromUtc, start.toUtc());
    expect(range.toUtc, next.toUtc());
    expect(start.toUtc().millisecondsSinceEpoch, range.fromUtc!.millisecondsSinceEpoch);
    expect(next.toUtc().millisecondsSinceEpoch, range.toUtc!.millisecondsSinceEpoch);
    expect(start.toUtc().isBefore(range.toUtc!), isTrue);
  });

  test('yesterday crosses a month boundary on the local calendar', () {
    final range = localDateRange(
      HistoryDateFilter.yesterday,
      DateTime(2026, 3, 1, 8),
    );
    expect(range.fromUtc, DateTime(2026, 2, 28).toUtc());
    expect(range.toUtc, DateTime(2026, 3, 1).toUtc());
  });

  test('yesterday crosses a year boundary on the local calendar', () {
    final range = localDateRange(
      HistoryDateFilter.yesterday,
      DateTime(2026, 1, 1, 0, 30),
    );
    expect(range.fromUtc, DateTime(2025, 12, 31).toUtc());
    expect(range.toUtc, DateTime(2026, 1, 1).toUtc());
  });

  test('last seven days includes today and the previous six local days', () {
    final now = DateTime(2026, 11, 8, 23, 59);
    final range = localDateRange(HistoryDateFilter.lastSevenDays, now);
    expect(range.fromUtc, DateTime(2026, 11, 2).toUtc());
    expect(range.toUtc, DateTime(2026, 11, 9).toUtc());
    final firstMorning = DateTime(2026, 11, 2).toUtc();
    final todayLate = DateTime(2026, 11, 8, 23, 59).toUtc();
    final dayBefore = DateTime(2026, 11, 1, 23, 59).toUtc();
    expect(firstMorning.millisecondsSinceEpoch >= range.fromUtc!.millisecondsSinceEpoch, isTrue);
    expect(todayLate.isBefore(range.toUtc!), isTrue);
    expect(dayBefore.isBefore(range.fromUtc!), isTrue);
    final fixedSpan = now.subtract(const Duration(days: 6)).toUtc();
    expect(range.fromUtc, isNot(fixedSpan));
  });

  test('all dates has null bounds', () {
    final range = localDateRange(HistoryDateFilter.all, DateTime(2026, 11, 8));
    expect(range.fromUtc, isNull);
    expect(range.toUtc, isNull);
  });

  test('Asia/Tehran fixture bounds when the OS offset is +03:30', () {
    final offset = DateTime(2026, 11, 8).timeZoneOffset;
    expect(
      offset,
      const Duration(hours: 3, minutes: 30),
      reason: 'history-fixtures.json date_cases are Asia/Tehran',
    );
    final now = DateTime.utc(2026, 11, 8, 8, 30).toLocal();
    final today = localDateRange(HistoryDateFilter.today, now);
    expect(today.fromUtc, DateTime.utc(2026, 11, 7, 20, 30));
    expect(today.toUtc, DateTime.utc(2026, 11, 8, 20, 30));
    final yesterday = localDateRange(HistoryDateFilter.yesterday, now);
    expect(yesterday.fromUtc, DateTime.utc(2026, 11, 6, 20, 30));
    expect(yesterday.toUtc, DateTime.utc(2026, 11, 7, 20, 30));
    final week = localDateRange(HistoryDateFilter.lastSevenDays, now);
    expect(week.fromUtc, DateTime.utc(2026, 11, 1, 20, 30));
    expect(week.toUtc, DateTime.utc(2026, 11, 8, 20, 30));
    final all = localDateRange(HistoryDateFilter.all, now);
    expect(all.fromUtc, isNull);
    expect(all.toUtc, isNull);
  });

  test('shamsi_date fixture 2026-11-08 is 1405/08/17 and English stays Gregorian', () {
    final jalali = Jalali.fromGregorian(Gregorian(2026, 11, 8));
    expect(jalali.year, 1405);
    expect(jalali.month, 8);
    expect(jalali.day, 17);
    final local = DateTime(2026, 11, 8, 9, 30);
    expect(formatHistoryDate(local, jalali: true), '1405/08/17');
    expect(formatHistoryDate(local, jalali: false), '2026/11/08');
    expect(formatHistoryClock(local), '09:30:00');
  });

  test('duration floors elapsed milliseconds and does not subtract the wall clock', () {
    expect(formatHistoryDuration(elapsedMs: 0, status: 'completed'), '00:00:00');
    expect(formatHistoryDuration(elapsedMs: 999, status: 'completed'), '00:00:00');
    expect(formatHistoryDuration(elapsedMs: 1999, status: 'completed'), '00:00:01');
    expect(formatHistoryDuration(elapsedMs: 1050000, status: 'completed'), '00:17:30');
    expect(formatHistoryDuration(elapsedMs: 30000, status: 'interrupted'), 'حداقل 00:00:30');
    expect(formatHistoryDuration(elapsedMs: 90061000, status: 'completed'), '25:01:01');
    expect(
      formatHistoryDuration(elapsedMs: 1050000, status: 'active'),
      'در حال اتصال — 00:17:30',
    );
    final started = DateTime.utc(2026, 11, 8, 6);
    final endedBeforeStart = DateTime.utc(2026, 11, 8, 5);
    expect(
      historyClockChanged(
        startedAtUtcMs: started.millisecondsSinceEpoch,
        endedAtUtcMs: endedBeforeStart.millisecondsSinceEpoch,
      ),
      isTrue,
    );
    expect(
      formatHistoryDuration(elapsedMs: 1050000, status: 'completed'),
      '00:17:30',
    );
    expect(
      historyClockChanged(startedAtUtcMs: 1000, endedAtUtcMs: null),
      isFalse,
    );
  });
}
