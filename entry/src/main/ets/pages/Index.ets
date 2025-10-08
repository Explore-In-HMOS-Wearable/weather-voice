import { CircularBuffer } from 'sherpa_onnx';
import worker, { MessageEvents } from '@ohos.worker';
import { audio } from '@kit.AudioKit';
import systemTime from '@ohos.systemTime';
import { ArcList, ArcListItem, ArcListAttribute, LengthMetrics } from '@kit.ArkUI';
import { DailyForecast, WeatherData } from '../models/WeatherData';
import { SimpleWeatherDataService } from '../services/SimpleWeatherDataService';
import { WeatherTextSpeechService } from '../services/WeatherSpeechTextService';
import { WeatherColors, WeatherFonts, WeatherLayout } from 'common';
import { getWeatherConditionDisplayName, WeatherCondition } from '../models/WeatherCondition';

@Entry
@Component
struct Index {
  @State weatherData: WeatherData | null = null;
  @State isLoading: boolean = true;
  @State weatherAnnouncement: string = '';

  //TTS related states
  @State isGenerating: boolean = false;
  @State initTtsDone: boolean = false;
  @State speechProgress: number = 0; //For text highlighting, 0-1
  @State audioPlaybackProgress: number = 0; //For audio playback, 0-1
  @State currentWordIndex: number = 0; //Current word being spoken in tts
  @State isPlayingAudio: boolean = false;

  //TTS related private properties
  private totalSamples: number = 0;
  private playedSamples: number = 0;
  private words: string[] = [];
  private workerInstance?: worker.ThreadWorker;
  private readonly scriptUrl: string = 'entry/ets/workers/NonStreamingTtsWorker.ets';
  private sampleBuffer: CircularBuffer = new CircularBuffer(16000 * 5);
  private audioRenderer: audio.AudioRenderer | null = null;
  private sampleRate: number = 0;

  aboutToAppear(): void {
    this.loadWeatherData();
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

    this.workerInstance.onmessage = (e:MessageEvents) => {
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

        if(this.audioRenderer && this.audioRenderer.state !== audio.AudioState.STATE_RUNNING) {
          this.isPlayingAudio = true;
          this.audioRenderer.start();
        }
      }
    };
    this.workerInstance.postMessage({msgType: 'init-tts', context: getContext()});
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

    systemTime.getRealTime((err) => {
      if(!err && this.workerInstance) {
        this.workerInstance.postMessage({
          msgType: 'tts-generate',
          text: this.weatherAnnouncement,
          sid: 0,
          speed: 1.0,
        });
      }
    });
  }

  private setupAudioRenderer(): void {
    if(this.audioRenderer) {
      return;
    }

    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: this.sampleRate,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW,
    };

    const audioRendererInfo: audio.AudioRendererInfo = {
      usage: audio.StreamUsage.STREAM_USAGE_MUSIC,
      rendererFlags: 0,
    };

    const audioRendererOptions: audio.AudioRendererOptions = {
      streamInfo: audioStreamInfo,
      rendererInfo: audioRendererInfo,
    };

    audio.createAudioRenderer(audioRendererOptions, (err, renderer) => {
      if(!err && renderer) {
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
      if(this.isPlayingAudio && this.totalSamples > 0) {
        this.playedSamples += numSamples;
        const progress = Math.min(this.playedSamples / this.totalSamples, 1.0);
        const wordIndex = Math.floor(progress * this.words.length) + 1;
        animateTo({
          duration: 100,
          curve: Curve.Linear,
        }, ()=>{
          this.audioPlaybackProgress = progress;
          this.currentWordIndex = Math.min(wordIndex, this.words.length);
        });
      }
    } else {
      (new Int16Array(buffer)).fill(0);

      if (!this.isGenerating && this.audioRenderer) {
        this.audioRenderer.stop();
        this.isPlayingAudio = false;
      }
    }
  };

  build() {
    Column() {
      if(this.isLoading){
        this.LoadingView()
      } else {
        this.WeatherView()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(WeatherColors.BACKGROUND)
  }

  @Builder
  LoadingView() {
    Column({space: WeatherLayout.ITEM_SPACING}){
      Image($r('app.media.partly_cloudy'))
        .width(48)
        .height(48)
        .fillColor(WeatherColors.TEXT_PRIMARY)

      Text('Loading Weather...')
        .fontSize(WeatherFonts.BODY)
        .fontColor(WeatherColors.TEXT_PRIMARY)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  WeatherView(){
    ArcList() {
      ArcListItem(){
        this.WeatherAnnouncementCard()
      }
      ArcListItem(){
        this.CurrentWeatherCard()
      }
      ArcListItem(){
        this.DailyForecastCard()
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
    Column({space: 12}) {
      Row({space: 8}) {
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
    if(this.words.length > 0) {
      Text() {
        ForEach(this.words, (word: string, index: number)=> {
          Span(`${word} `)
            .fontColor(index < this.currentWordIndex ? '#ffffd700' : '#ff808080')
            .animation({
              duration: 150,
              curve: Curve.EaseOut
            })
        }, (index:number)=>`word-${index}`)
      }
      .fontSize(WeatherFonts.BODY)
      .textAlign(TextAlign.Start)
      .width('100%')
      .lineHeight(20)
      .maxLines(8)
      .textOverflow({overflow: TextOverflow.Ellipsis})
    } else {
      Text(this.weatherAnnouncement || 'Loading...')
        .fontSize(WeatherFonts.BODY)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .textAlign(TextAlign.Start)
        .width('100%')
        .lineHeight(20)
        .maxLines(8)
        .textOverflow({overflow: TextOverflow.Ellipsis})
    }
  }

  @Builder
  CurrentWeatherCard() {
    Column({space: 8}){
      Text(`${this.weatherData?.location?.city || 'Unknown'}, ${this.weatherData?.location?.region || 'Unknown'}`)
        .fontSize(WeatherFonts.CAPTION)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({bottom: 4})

      Text(`${this.weatherData?.current?.temperature || '--'}°C`)
        .fontSize(WeatherFonts.TEMPERATURE)
        .fontColor(WeatherColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Bold)
        .textAlign(TextAlign.Center)

      Row({space: 8}) {
        Image(this.getWeatherIcon(this.weatherData?.current?.condition))
          .width(20)
          .height(20)
          .fillColor(WeatherColors.TEXT_PRIMARY)

        Text(getWeatherConditionDisplayName(this.weatherData?.current?.condition || WeatherCondition.PARTY_CLOUDY))
          .fontSize(WeatherFonts.TITLE)
          .fontColor(WeatherColors.TEXT_SECONDARY)
      }
      .justifyContent(FlexAlign.Center)

      if(this.weatherData?.current?.feelsLike &&
      Math.abs(this.weatherData?.current?.temperature - this.weatherData?.current?.feelsLike) > 2) {
        Text(`Feels like ${this.weatherData?.current?.feelsLike}°C`)
          .fontSize(WeatherFonts.CAPTION)
          .fontColor(WeatherColors.TEXT_SECONDARY)
      }

      Row({space: 16}) {
        Column({space: 4}) {
          Image($r('app.media.humidity'))
            .width(16)
            .height(16)
            .fillColor(WeatherColors.TEXT_PRIMARY)

          Text(`${this.weatherData?.current?.humidity || 0}%`)
            .fontSize(WeatherFonts.CAPTION)
            .fontColor(WeatherColors.TEXT_SECONDARY)
        }
        .margin({right: 8})

        Column({space: 4}) {
          Image($r('app.media.wind'))
            .width(16)
            .height(16)
            .fillColor(WeatherColors.TEXT_PRIMARY)

          Text(`${this.weatherData?.current?.windSpeed || 0} km/h`)
            .fontSize(WeatherFonts.CAPTION)
            .fontColor(WeatherColors.TEXT_SECONDARY)
        }
        .margin({right: 8})

        Column({space: 4}) {
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
      .margin({top: 12})
    }
    .width('100%')
    .padding(WeatherLayout.CARD_PADDING)
    .backgroundColor(WeatherColors.CARD)
    .borderRadius(WeatherLayout.BORDER_RADIUS)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  DailyForecastCard() {
    Column({space: 12}) {
      Text('7-Day Forecast')
        .fontSize(WeatherFonts.TITLE)
        .fontColor(WeatherColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Start)

      Column({space: 8}) {
        ForEach(this.weatherData?.forecast.slice(0,5) || [], (day: DailyForecast, index: number) =>{
          this.ForecastDayItem(day,index)
        }, (index:number)=>`word-${index}`)
      }
    }
    .width('100%')
    .padding(WeatherLayout.CARD_PADDING)
    .backgroundColor(WeatherColors.CARD)
    .borderRadius(WeatherLayout.BORDER_RADIUS)
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  ForecastDayItem(day: DailyForecast, index: number) {
    Row(){
      Text(this.formatForecastDay(day.date, index))
        .fontSize(WeatherFonts.BODY)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .width(60)

      Image(this.getWeatherIcon(day.condition))
        .width(16)
        .height(16)
        .fillColor(WeatherColors.TEXT_PRIMARY)


      Text(getWeatherConditionDisplayName(day.condition))
        .fontSize(WeatherFonts.CAPTION)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .layoutWeight(1)

      Row({space: 8}){
        Text(`${day.high}°`)
          .fontSize(WeatherFonts.CAPTION)
          .fontColor(WeatherColors.TEXT_PRIMARY)
          .fontWeight(FontWeight.Medium)

        Text(`${day.low}°`)
          .fontSize(WeatherFonts.CAPTION)
          .fontColor(WeatherColors.TEXT_SECONDARY)
      }
    }
    .width('100%')
    .height(24)
    .justifyContent(FlexAlign.SpaceBetween)
  }


  private getWeatherIcon(condition?: WeatherCondition): Resource {
    switch (condition) {
      case WeatherCondition.SUNNY:
        return $r('app.media.sunny');
      case WeatherCondition.PARTY_CLOUDY:
        return $r('app.media.partly_cloudy');
      case WeatherCondition.CLOUDY:
        return $r('app.media.cloudy');
      case WeatherCondition.RAINY:
        return $r('app.media.rainy');
      case WeatherCondition.STORMY:
        return $r('app.media.stormy');
      case WeatherCondition.SNOWY:
        return $r('app.media.snowy');
      case WeatherCondition.FOGGY:
        return $r('app.media.foggy');
      default:
        return $r('app.media.partly_cloudy');
    }
  }

  private formatForecastDay(date: string, index: number) {
    if(index === 0) {
      return 'Today';
    }
    if(index === 1) {
      return 'Tomorrow';
    }
    const dateObj = new Date(date);
    const days = ['Sun', 'Mon', 'Tue', 'Web', 'Thu', 'Fri', 'Sat'];
    return days[dateObj.getDay()];
  }

}