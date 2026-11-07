import Foundation

/// 하루치 기록. 2주 차의 "하루 일기" 생성 단위가 된다.
struct RecordingDay: Identifiable, Equatable {
    /// 그 날의 0시
    let date: Date
    /// 최신순
    let recordings: [Recording]

    var id: Date { date }
    var totalDuration: TimeInterval { recordings.reduce(0) { $0 + $1.duration } }
}

enum RecordingGrouper {
    /// 날짜별로 묶는다. 날짜도, 같은 날 안의 녹음도 최신순.
    static func groupByDay(_ recordings: [Recording], calendar: Calendar) -> [RecordingDay] {
        Dictionary(grouping: recordings) { calendar.startOfDay(for: $0.createdAt) }
            .map { day, items in
                RecordingDay(date: day, recordings: items.sorted { $0.createdAt > $1.createdAt })
            }
            .sorted { $0.date > $1.date }
    }
}
