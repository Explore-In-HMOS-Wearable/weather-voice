import { WeatherColors, WeatherFonts, WeatherLayout } from '../constants/UIConstants'

@Component
export struct LoadingView {
  build() {
    Column({ space: WeatherLayout.ITEM_SPACING }) {
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
}