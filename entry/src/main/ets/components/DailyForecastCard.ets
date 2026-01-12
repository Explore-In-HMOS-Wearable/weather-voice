import { WeatherColors, WeatherFonts, WeatherLayout } from '../constants/UIConstants';
import { getWeatherConditionDisplayName } from '../models/WeatherCondition';
import { DailyForecast, WeatherData } from '../models/WeatherData';
import { WeatherUtils } from '../utils/WeatherConstants';

interface ForecastEntry {
  id: string;
  day: DailyForecast;
  displayIndex: number;
}

@Component
export struct DailyForecastCard {
  @Prop weatherData: WeatherData | null;

  private buildForecastEntries(): ForecastEntry[] {
    const forecast = this.weatherData?.forecast?.slice(0,5);
    if(!forecast) {
      return[];
    }
    const result: ForecastEntry[]=[];
    for(let i = 0; i< forecast.length; i++) {
      const day = forecast[i];
      const entry: ForecastEntry = {
        id: day.date,
        day: day,
        displayIndex: i
      };
      result.push(entry);
    }
    return result;
  }

  build() {
    Column({ space: 12 }) {
      Text('7-Day Forecast')
        .fontSize(WeatherFonts.TITLE)
        .fontColor(WeatherColors.TEXT_PRIMARY)
        .fontWeight(FontWeight.Medium)
        .width('100%')
        .textAlign(TextAlign.Start)

      Column({ space: 8 }) {
        ForEach(this.buildForecastEntries(), (entry: ForecastEntry) => {
          this.ForecastDayItem(entry.day, entry.displayIndex)
        }, (entry: ForecastEntry) => entry.id)
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
    Row() {
      Text(WeatherUtils.formatForecastDay(day.date, index))
        .fontSize(WeatherFonts.BODY)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .width(60)

      Image(WeatherUtils.getWeatherIcon(day.condition))
        .width(16)
        .height(16)
        .fillColor(WeatherColors.TEXT_PRIMARY)


      Text(getWeatherConditionDisplayName(day.condition))
        .fontSize(WeatherFonts.CAPTION)
        .fontColor(WeatherColors.TEXT_SECONDARY)
        .layoutWeight(1)

      Row({ space: 8 }) {
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
}