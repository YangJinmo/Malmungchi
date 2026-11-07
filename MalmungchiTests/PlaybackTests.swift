import Foundation
import Testing
@testable import Malmungchi

@Suite("Transcript.segmentIndex")
struct SegmentIndexTests {
    private let transcript = Transcript(
        recordingID: UUID(),
        language: "ko",
        segments: [
            TranscriptSegment(start: 2, end: 5, text: "첫 문장"),
            TranscriptSegment(start: 5, end: 9, text: "둘째 문장"),
            TranscriptSegment(start: 12, end: 15, text: "셋째 문장"),
        ],
        createdAt: .now
    )

    @Test(
        "재생 위치에 맞는 구간을 고른다",
        arguments: [
            (0.0, nil),
            (2.0, 0),
            (4.9, 0),
            (5.0, 1),
            (10.0, 1),
            (12.0, 2),
            (999.0, 2),
        ] as [(Double, Int?)]
    )
    func index(time: Double, expected: Int?) {
        #expect(transcript.segmentIndex(at: time) == expected)
    }

    @Test("구간이 없으면 nil")
    func empty() {
        let empty = Transcript(recordingID: UUID(), language: "ko", segments: [], createdAt: .now)
        #expect(empty.segmentIndex(at: 3) == nil)
    }
}

@MainActor
@Suite("RecordingDetailViewModel 재생")
struct RecordingDetailPlaybackTests {
    private struct SUT {
        let viewModel: RecordingDetailViewModel
        let player: FakeAudioPlayer
        let storage: FakeAudioStorage
        let recording: Recording
    }

    private func makeSUT(withTranscript: Bool = true) throws -> SUT {
        let recording = Fixtures.recording(at: Fixtures.date(2026, 11, 5, 9), duration: 100, status: .completed)
        let recordings = InMemoryRecordingRepository([recording])
        let transcripts = InMemoryTranscriptRepository()
        if withTranscript {
            try transcripts.save(
                Transcript(
                    recordingID: recording.id,
                    language: "ko",
                    segments: [
                        TranscriptSegment(start: 0, end: 10, text: "안녕하세요"),
                        TranscriptSegment(start: 10, end: 20, text: "반갑습니다"),
                    ],
                    createdAt: .now
                ),
                for: recording
            )
        }
        let storage = FakeAudioStorage()
        let player = FakeAudioPlayer()
        let viewModel = RecordingDetailViewModel(
            recording: recording,
            recordings: recordings,
            fetchTranscript: FetchTranscriptUseCase(transcripts: transcripts),
            transcribeRecording: TranscribeRecordingUseCase(
                recordings: recordings,
                transcripts: transcripts,
                storage: storage,
                transcriber: FakeTranscriber(result: .success(Fixtures.sampleOutput))
            ),
            storage: storage,
            player: player
        )
        viewModel.load()
        return SUT(viewModel: viewModel, player: player, storage: storage, recording: recording)
    }

    @Test("처음 재생할 때만 파일을 불러오고, 실제 길이로 바꾼다")
    func loadsOnceOnFirstPlay() throws {
        let sut = try makeSUT()
        sut.player.durationToReport = 123

        #expect(sut.viewModel.playbackDuration == 100)
        sut.viewModel.togglePlayback()
        sut.viewModel.togglePlayback()
        sut.viewModel.togglePlayback()

        #expect(sut.player.loadedURLs == [sut.storage.url(for: sut.recording.fileName)])
        #expect(sut.viewModel.isPlaying)
        #expect(sut.viewModel.playbackDuration == 123)
    }

    @Test("재생 전에는 현재 구간이 없다")
    func noCurrentSegmentBeforePlaying() throws {
        let sut = try makeSUT()
        #expect(sut.viewModel.currentSegmentIndex == nil)
    }

    @Test("문장을 누르면 그 시작 위치부터 재생하고 현재 구간이 된다")
    func playFromSegment() throws {
        let sut = try makeSUT()
        let second = try #require(sut.viewModel.transcript?.segments[1])

        sut.viewModel.play(from: second)

        #expect(sut.player.currentTime == 10)
        #expect(sut.viewModel.playbackTime == 10)
        #expect(sut.viewModel.isPlaying)
        #expect(sut.viewModel.currentSegmentIndex == 1)
    }

    @Test("15초 이동은 0과 전체 길이 사이로 제한된다")
    func skipIsClamped() throws {
        let sut = try makeSUT()
        sut.player.durationToReport = 30

        sut.viewModel.skip(by: -15)
        #expect(sut.viewModel.playbackTime == 0)

        sut.viewModel.skip(by: 15)
        sut.viewModel.skip(by: 15)
        sut.viewModel.skip(by: 15)
        #expect(sut.viewModel.playbackTime == 30)
    }

    @Test("끝까지 재생되면 처음으로 돌아가고 멈춘다")
    func finishResets() async throws {
        let sut = try makeSUT()
        sut.viewModel.seek(to: 50)
        sut.viewModel.play()

        sut.viewModel.handlePlaybackFinished()

        #expect(!sut.viewModel.isPlaying)
        #expect(sut.viewModel.playbackTime == 0)
    }

    @Test("화면을 떠나면 재생을 멈춘다")
    func stopOnDisappear() throws {
        let sut = try makeSUT()
        sut.viewModel.play()

        sut.viewModel.stopPlayback()

        #expect(!sut.viewModel.isPlaying)
        #expect(!sut.player.isPlaying)
    }

    @Test("파일을 불러오지 못하면 에러를 보여주고 재생하지 않는다")
    func loadFailure() throws {
        let sut = try makeSUT()
        sut.player.loadError = StubError()

        sut.viewModel.play()

        #expect(!sut.viewModel.isPlaying)
        #expect(sut.viewModel.errorMessage == "녹음 파일을 재생할 수 없어요: stub failure")
    }
}
