import Foundation
import Testing
@testable import Malmungchi

@Suite("RecordingGrouper")
struct RecordingGrouperTests {
    @Test("서울 시각 기준 날짜로 묶고, 날짜와 녹음 모두 최신순으로 정렬한다")
    func groupsByLocalDay() {
        let lateNight = Fixtures.recording(at: Fixtures.date(2026, 11, 3, 23, 50), duration: 60)
        let morning = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 8, 0), duration: 120)
        let evening = Fixtures.recording(at: Fixtures.date(2026, 11, 4, 21, 0), duration: 30)

        let days = RecordingGrouper.groupByDay([morning, lateNight, evening], calendar: Fixtures.seoulCalendar)

        #expect(days.count == 2)
        #expect(days[0].date == Fixtures.date(2026, 11, 4))
        #expect(days[0].recordings.map(\.id) == [evening.id, morning.id])
        #expect(days[0].totalDuration == 150)
        #expect(days[1].recordings.map(\.id) == [lateNight.id])
    }

    @Test("빈 목록이면 빈 결과")
    func empty() {
        #expect(RecordingGrouper.groupByDay([], calendar: Fixtures.seoulCalendar).isEmpty)
    }
}

@Suite("MarkdownTranscriptFormatter")
struct MarkdownTranscriptFormatterTests {
    @Test(
        "타임스탬프 형식",
        arguments: [
            (0.0, "00:00"),
            (65.4, "01:05"),
            (3599.0, "59:59"),
            (3600.0, "1:00:00"),
            (3725.0, "1:02:05"),
            (-3.0, "00:00"),
        ]
    )
    func timestamp(seconds: Double, expected: String) {
        #expect(MarkdownTranscriptFormatter.timestamp(seconds) == expected)
    }

    @Test("front matter와 구간을 옵시디언 형식으로 쓴다")
    func formatsMarkdown() {
        let recording = Recording(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            createdAt: Fixtures.date(2026, 11, 4, 21, 41),
            fileName: "a.m4a",
            title: "송 대표 미팅",
            duration: 3555.4,
            source: .imported,
            status: .completed
        )
        let transcript = Transcript(
            recordingID: recording.id,
            language: "ko",
            segments: [
                TranscriptSegment(start: 0, end: 3, text: " 안녕하세요 "),
                TranscriptSegment(start: 4, end: 5, text: "   "),
                TranscriptSegment(start: 3725, end: 3730, text: "감사합니다"),
            ],
            createdAt: recording.createdAt
        )

        let markdown = MarkdownTranscriptFormatter(timeZone: Fixtures.seoul).format(transcript, recording: recording)

        #expect(markdown == """
        ---
        id: 00000000-0000-0000-0000-000000000001
        date: 2026-11-04T21:41:00+09:00
        duration: 3555
        source: imported
        language: ko
        ---

        # 송 대표 미팅

        [00:00] 안녕하세요
        [1:02:05] 감사합니다

        """)
    }
}
