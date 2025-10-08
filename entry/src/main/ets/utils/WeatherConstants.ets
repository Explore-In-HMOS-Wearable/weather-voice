import { WeatherCondition } from '../models/WeatherCondition'
import { LocationInfo } from '../models/WeatherData';
import { secureRandomNumber } from './SecureRandomUtil';


interface WeatherConditionProbability {
  condition: WeatherCondition;
  probability: number;
}

interface SeasonalConditions {
  winter: WeatherConditionProbability[];
  spring: WeatherConditionProbability[];
  summer: WeatherConditionProbability[];
  fall: WeatherConditionProbability[];
}

export class WeatherConstants {
  static readonly SEASONAL_TEMPS: number[] = [
    4, 7, 13, 18, 24, 29, 32, 31, 27, 21, 13, 7  //Jan to Dec
  ];

  static readonly SEASONAL_CONDITIONS: SeasonalConditions = {
    winter: [
      {condition: WeatherCondition.SNOWY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.CLOUDY, probability:0.4} as WeatherConditionProbability,
      {condition: WeatherCondition.PARTY_CLOUDY, probability:0.2} as WeatherConditionProbability,
      {condition: WeatherCondition.SUNNY, probability:0.1} as WeatherConditionProbability,
    ],
    spring: [
      {condition: WeatherCondition.RAINY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.PARTY_CLOUDY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.CLOUDY, probability:0.2} as WeatherConditionProbability,
      {condition: WeatherCondition.SUNNY, probability:0.2} as WeatherConditionProbability,
    ],
    summer: [
      {condition: WeatherCondition.SUNNY, probability:0.5} as WeatherConditionProbability,
      {condition: WeatherCondition.PARTY_CLOUDY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.STORMY, probability:0.1} as WeatherConditionProbability,
      {condition: WeatherCondition.CLOUDY, probability:0.1} as WeatherConditionProbability,
    ],
    fall: [
      {condition: WeatherCondition.CLOUDY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.PARTY_CLOUDY, probability:0.3} as WeatherConditionProbability,
      {condition: WeatherCondition.RAINY, probability:0.2} as WeatherConditionProbability,
      {condition: WeatherCondition.SUNNY, probability:0.2} as WeatherConditionProbability,
    ],
  };

  static readonly MOCK_LOCATIONS: LocationInfo[] = [
    {city: 'Istanbul', region: 'Istanbul', country: 'Turkey'} as LocationInfo,
    {city: 'Ankara', region: 'Ankara', country: 'Turkey'} as LocationInfo,
    {city: 'Bursa', region: 'Bursa', country: 'Turkey'} as LocationInfo,
    {city: 'Beijing', region: 'Beijing', country: 'China'} as LocationInfo,
    {city: 'Shanghai', region: 'Shanghai', country: 'China'} as LocationInfo,
    {city: 'Guangzhou', region: 'Guangdong', country: 'China'} as LocationInfo,
    {city: 'Shenzhen', region: 'Guangdong', country: 'China'} as LocationInfo,
  ];

  static readonly PREF_NAME = 'weather_data';
  static readonly WEATHER_KEY = 'current_weather';
  static readonly LAST_UPDATE_KEY = 'last_update';
  static readonly UPDATE_INTERVAL = 30*60*1000; //30 minutes in milliseconds
  static readonly FORECAST_DAYS = 7;
}

export class WeatherUtils {
  static getCurrentSeason(month: number): 'winter' | 'spring' | 'summer' | 'fall' {
    //These are indexes, so '1' is actually the 2nd month, February. And '11' is 12th month, December.
    if(month >= 11 || month <=1) {
      return 'winter';
    }
    if(month >= 2 || month <=4) {
      return 'spring';
    }
    if(month >= 5 || month <=7) {
      return 'summer';
    }
    return 'fall';
  }

  static randomInRange(min: number, max: number) : number {
    return secureRandomNumber() * (max-min) + min;
  }

  static randomFromArray<T>(array: T[]): T {
    return array[Math.floor(secureRandomNumber() * array.length)];
  }

  static getDateString(daysFromNow:number) : string {
    const date = new Date();
    date.setDate(date.getDate() + daysFromNow);
    return date.toISOString().split('T')[0];
  }

  static getTimeOfDay(): number {
    const date = new Date();
    return date.getHours() + date.getMinutes() / 60;
  }
}