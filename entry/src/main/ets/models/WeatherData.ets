import { WeatherCondition } from './WeatherCondition';

export interface WeatherData {
  current: CurrentWeather;
  forecast: DailyForecast[];
  location: LocationInfo;
  lastUpdated: number;
}

export interface CurrentWeather {
  condition: WeatherCondition;
  temperature: number; //Celsius
  humidity: number; //0-100 percentage
  feelsLike: number;
  windSpeed: number;
  uvIndex: number; //standard 0-11 scale
}

export interface DailyForecast {
  condition: WeatherCondition;
  date: string; //iso date format(yyyy-mm-dd)
  high: number;
  low: number;
  precipitationChance: number; //0-100 percentage
}

export interface HourlyForecast {
  condition: WeatherCondition;
  time: string; //iso date format(yyyy-mm-dd)
  temperature: number;
  precipitationChance: number; //0-100 percentage
}

export interface LocationInfo {
  city: string;
  region: string;
  country?: string;
}
//
// export interface ClothingSuggestion {
//   mainText: string;
//   items: string[];
//   accessories: string[];
//   priority: SuggestionPriority;
//   reasoning: string;
// }
//
// export enum SuggestionPriority {
//   LOW = 'low',
//   NORMAL = 'normal',
//   HIGH = 'high',
// }

export class WeatherDataValidator {
  static isValidTemperature(temp: number): boolean {
    return temp >= -60 && temp <= 60;
  }

  static isValidHumidity(humidity: number): boolean {
    return humidity >= 0 && humidity <= 100;
  }

  static isValidUvIndex(uvIndex: number): boolean {
    return uvIndex >= 0 && uvIndex <= 11;
  }

  static isValidWindSpeed(windSpeed: number): boolean {
    return windSpeed >= 0 && windSpeed <= 300;
  }

  static validateCurrentWeather(weather: CurrentWeather): boolean {
    return WeatherDataValidator.isValidTemperature(weather.temperature) &&
    WeatherDataValidator.isValidTemperature(weather.feelsLike) &&
    WeatherDataValidator.isValidHumidity(weather.humidity) &&
    WeatherDataValidator.isValidUvIndex(weather.uvIndex) &&
    WeatherDataValidator.isValidWindSpeed(weather.windSpeed)
  }
}
