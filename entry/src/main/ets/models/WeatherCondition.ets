export enum WeatherCondition {
  SUNNY = 'sunny',
  PARTY_CLOUDY = 'partly_cloudy',
  CLOUDY = 'cloudy',
  RAINY = 'rainy',
  STORMY = 'stormy',
  SNOWY = 'snowy',
  FOGGY = 'foggy',
  WINDY = 'windy',
}

export function getWeatherConditionDisplayName(condition: WeatherCondition): string {
  switch (condition) {
    case WeatherCondition.SUNNY:
      return 'Sunny';
    case WeatherCondition.PARTY_CLOUDY:
      return 'Partly Cloudy';
    case WeatherCondition.CLOUDY:
      return 'Cloudy';
    case WeatherCondition.RAINY:
      return 'Rainy';
    case WeatherCondition.STORMY:
      return 'Stormy';
    case WeatherCondition.SNOWY:
      return 'Snowy';
    case WeatherCondition.FOGGY:
      return 'Foggy';
    case WeatherCondition.WINDY:
      return 'Windy';
    default:
      return 'Unknown';
  }
}