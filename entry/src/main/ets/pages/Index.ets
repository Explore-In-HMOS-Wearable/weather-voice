import { CircularBuffer } from 'sherpa_onnx';
import worker, { MessageEvents } from '@ohos.worker';
import { audio } from '@kit.AudioKit';
import { ArcList, ArcListItem, ArcListAttribute, LengthMetrics } from '@kit.ArkUI';
import { WeatherData } from '../models/WeatherData';
import { SimpleWeatherDataService } from '../services/SimpleWeatherDataService';
import { WeatherTextSpeechService } from '../services/WeatherSpeechTextService';
import { getWeatherConditionDisplayName, WeatherCondition } from '../models/WeatherCondition';
import { WeatherColors, WeatherFonts, WeatherLayout } from '../constants/UIConstants';
import { LoadingView } from '../components/LoadingView';
import { WeatherUtils } from '../utils/WeatherConstants';
import { DailyForecastCard } from '../components/DailyForecastCard';

interface WordEntry {
  id: string;
  word: string;
  position: number;
}

@Entry
@Component
struct Index {
  @State weatherData: WeatherData | null = null;
  @State isLoading: boolean = true;
  @State weatherAnnouncement: string = '';
  //TTS related states
  isGenerating: boolean = false;
  initTtsDone: boolean = false;
  speechProgress: number = 0; //For text highlighting, 0-1
  audioPlaybackProgress: number = 0; //For audio playback, 0-1
  currentWordIndex: number = 0; //Current word being spoken in tts
  isPlayingAudio: boolean = false;
  //TTS related private properties
  private totalSamples: number = 0;
  private playedSamples: number = 0;
  private words: string[] = [];
  private wordEntries: WordEntry[] = [];
  private wordIdCounter: number = 0;
  private workerInstance?: worker.ThreadWorker;
  private readonly scriptUrl: string = 'entry/ets/workers/NonStreamingTtsWorker.ets';
  private sampleBuffer: CircularBuffer = new CircularBuffer(16000 * 5);
  private audioRenderer: audio.AudioRenderer | null = null;
  private sampleRate: number = 0;

  private nextWordId(): string {
    const id = `word-${this.wordIdCounter}`;
    this.wordIdCounter += 1;
    return id;
  }

  aboutToAppear(): void {
    this.loadWeatherData();
  }

  build() {
    Column() {
      if (this.isLoading) {
        LoadingView()
      } else {
        this.WeatherView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WeatherColors.BACKGROUND)
  }

  @Builder
  WeatherView() {
    ArcList() {
      ArcListItem() {
        this.WeatherAnnouncementCard()
      }

      ArcListItem() {
        this.CurrentWeatherCard()
      }

      ArcListItem() {
        DailyForecastCard()
      }
    }
    .space(LengthMetrics.px(8))
    .focusable(true)
    .focusOnTouch(true)
    .defaultFocus(true)
    .width('100%')
    .height('100%')
  }

  @Builder
  WeatherAnnouncementCard() {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Image($r('app.media.speak'))
          .width(20)
          .height(20)
          .fillColor(WeatherColors.TEXT_PRIMARY)

        Text('Weather Voice')
          .fontSize(WeatherFonts.TITLE)
          .fontWeight(FontWeight.Medium)
          .fontColor(WeatherColors.TEXT_PRIMARY)
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)

      this.AnimatedTextHighlight()
    }
    .width('100%')
    .padding(WeatherLayout.CARD_PADDING)
    .backgroundColor(WeatherColors.CARD)
    .borderRadius(WeatherLayout.BORDER_RADIUS)
    .alignItems(HorizontalAlign.Start)
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  AnimatedTextHighlight() {
    if (this.words.length > 0) {
      Text() {
        ForEach(this.wordEntries, (entry: WordEntry) => {
          Span(`${entry.word} `)
            .fontColor(entry.position < this.currentWordIndex ? '#ffffd700' : '#ff808080')
            .animation({
              duration: 150,
              curve: Curve.EaseOut
            })
        }, (entry: WordEntry) => entry.id)
      }
      .fontSize(WeatherFonts.BODY)
      .textAlign(TextAlign.Start)
      .width('100%')
      .lineHeight(20)
      .maxLines(8)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
    } else {
      Text(this.weatherAnnouncement || 'Loading...')
        .fontSize(WeatherFonts.BODY)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Start)
        .width('100%')
        .lineHeight(20)
        .maxLines(8)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
  }

  @Builder
  CurrentWeatherCard() {
    Column({ space: 8 }) {
      Text(`${this.weatherData?.location?.city || 'Unknown'}, ${this.weatherData?.location?.region || 'Unknown'}`)
        .fontSize(WeatherFonts.CAPTION)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ bottom: 4 })

      Text(`${this.weatherData?.current?.temperature || '--'}°C`)
        .fontSize(WeatherFonts.TEMPERATURE)
        .fontColor(WeatherColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)

      Row({ space: 8 }) {
        Image(WeatherUtils.getWeatherIcon(this.weatherData?.current?.condition))
          .width(20)
          .height(20)
          .fillColor(WeatherColors.TEXT_PRIMARY)

        Text(getWeatherConditionDisplayName(this.weatherData?.current?.condition || WeatherCondition.PARTY_CLOUDY))
          .fontSize(WeatherFonts.TITLE)
          .fontColor(WeatherColors.TEXT_SECONDARY)
      }
      .justifyContent(FlexAlign.Center)

      if (this.weatherData?.current?.feelsLike &&
        Math.abs(this.weatherData?.current?.temperature - this.weatherData?.current?.feelsLike) > 2) {
        Text(`Feels like ${this.weatherData?.current?.feelsLike}°C`)
          .fontSize(WeatherFonts.CAPTION)
          .fontColor(WeatherColors.TEXT_SECONDARY)
      }

      Row({ space: 16 }) {
        Column({ space: 4 }) {
          Image($r('app.media.humidity'))
            .width(16)
            .height(16)
            .fillColor(WeatherColors.TEXT_PRIMARY)

          Text(`${this.weatherData?.current?.humidity || 0}%`)
            .fontSize(WeatherFonts.CAPTION)
            .fontColor(WeatherColors.TEXT_SECONDARY)
        }
        .margin({ right: 8 })

        Column({ space: 4 }) {
          Image($r('app.media.wind'))
            .width(16)
            .height(16)
            .fillColor(WeatherColors.TEXT_PRIMARY)

          Text(`${this.weatherData?.current?.windSpeed || 0} km/h`)
            .fontSize(WeatherFonts.CAPTION)
            .fontColor(WeatherColors.TEXT_SECONDARY)
        }
        .margin({ right: 8 })

        Column({ space: 4 }) {
          Image($r('app.media.uv_index'))
            .width(16)
            .height(16)
            .fillColor(WeatherColors.TEXT_PRIMARY)

          Text(`${this.weatherData?.current?.uvIndex || 0}`)
            .fontSize(WeatherFonts.CAPTION)
            .fontColor(WeatherColors.TEXT_SECONDARY)
        }
      }
      .justifyContent(FlexAlign.SpaceEvenly)
      .margin({ top: 12 })
    }
    .width('100%')
    .padding(WeatherLayout.CARD_PADDING)
    .backgroundColor(WeatherColors.CARD)
    .borderRadius(WeatherLayout.BORDER_RADIUS)
    .justifyContent(FlexAlign.Center)
  }

  private async loadWeatherData(): Promise<void> {
    try {
      const service = SimpleWeatherDataService.getInstance();
      this.weatherData = await service.getCurrentWeatherData();

      if (this.weatherData) {
        const speechService = WeatherTextSpeechService.getInstance();
        this.weatherAnnouncement = speechService.generateCompleteAnnouncement(this.weatherData);

        //Split into words for highlighting later when running the audio
        this.words = this.weatherAnnouncement.split(' ').filter(word => word.trim() !== '');
        this.wordIdCounter = 0;
        this.wordEntries = [];
        for (let i = 0; i < this.words.length; i++) {
          const entry: WordEntry = {id: this.nextWordId(), word: this.words[i], position: i};
          this.wordEntries.push(entry);
        }

        //Initialize TTS
        this.initTtsWorker();
      }
    } catch (e) {
      //Error handling later here
      this.isLoading = false;
    }
  }

  private initTtsWorker(): void {
    this.workerInstance = new worker.ThreadWorker(this.scriptUrl, {
      name: 'WeatherVoice TTS Worker'
    });

    this.workerInstance.onmessage = (e: MessageEvents) => {
      const msgType = e.data.msgType as string;

      if (msgType === 'init-tts-done') {
        this.sampleRate = e.data.sampleRate as number;
        this.initTtsDone = true;
        this.speechProgress = 0; //Resetting all first
        this.audioPlaybackProgress = 0;
        this.currentWordIndex = 0;
        this.generateWeatherSpeech();
      }

      if (msgType === 'tts-generate-partial') {
        if (!this.isGenerating) {
          return;
        }
        const samples: Float32Array = e.data.samples as Float32Array;
        this.sampleBuffer.push(samples);
        this.setupAudioRenderer();
        //Setting loading false after the generate is started
        //So we wait more on loading screen and less on the main screen
        this.isLoading = false;
      }

      if (msgType === 'tts-generate-done') {
        this.isGenerating = false;
        const samples: Float32Array = e.data.samples as Float32Array;
        this.totalSamples = samples.length;
        this.playedSamples = 0;

        if (this.audioRenderer && this.audioRenderer.state !== audio.AudioState.STATE_RUNNING) {
          this.isPlayingAudio = true;
          this.audioRenderer.start();
        }
      }
    };
    this.workerInstance.postMessage({ msgType: 'init-tts', context: this.getUIContext().getHostContext() });
  }

  private generateWeatherSpeech(): void {
    if (!this.initTtsDone || this.isGenerating || !this.weatherAnnouncement) {
      return;
    }
    this.isGenerating = true;
    this.speechProgress = 0;
    this.audioPlaybackProgress = 0;
    this.currentWordIndex = 0;
    this.isPlayingAudio = true;
    this.totalSamples = 0;
    this.playedSamples = 0;

    if (this.workerInstance) {
      this.workerInstance.postMessage({
        msgType: 'tts-generate',
        text: this.weatherAnnouncement,
        sid: 0,
        speed: 1.0
      });
    }
  }

  private setupAudioRenderer(): void {
    if (this.audioRenderer) {
      return;
    }

    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: this.sampleRate,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    };

    const audioRendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0
    };

    const audioRendererOptions: audio.AudioRendererOptions = {
      streamInfo: audioStreamInfo,
      rendererInfo: audioRendererInfo
    };

    audio.createAudioRenderer(audioRendererOptions, (err, renderer) => {
      if (!err && renderer) {
        this.audioRenderer = renderer;
        this.audioRenderer.on('writeData', this.audioPlayCallback);
      } else {
        //Failed to initialize error here
      }
    });
  }

  private audioPlayCallback = (buffer: ArrayBuffer) => {
    const numSamples = buffer.byteLength / 2;

    if (this.sampleBuffer.size() >= numSamples) {
      const samples: Float32Array = this.sampleBuffer.get(this.sampleBuffer.head(), numSamples);
      const int16Samples = new Int16Array(buffer);

      for (let i = 0; i < numSamples; ++i) {
        let s = samples[i] * 32767;
        s = s > 32767 ? 32767 : s;
        s = s < -32768 ? -32768 : s;
        int16Samples[i] = s;
      }

      this.sampleBuffer.pop(numSamples);

      //Update playback for word highlighting
      if (this.isPlayingAudio && this.totalSamples > 0) {
        this.playedSamples += numSamples;
        const progress = Math.min(this.playedSamples / this.totalSamples, 1.0);
        const wordIndex = Math.floor(progress * this.words.length) + 1;


        this.audioPlaybackProgress = progress;
        this.currentWordIndex = Math.min(wordIndex, this.words.length);

      }
    } else {
      (new Int16Array(buffer)).fill(0);

      if (!this.isGenerating && this.audioRenderer) {
        this.audioRenderer.stop();
        this.isPlayingAudio = false;
      }
    }
  };

}