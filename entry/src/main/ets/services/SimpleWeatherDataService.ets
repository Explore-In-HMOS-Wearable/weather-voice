import { WeatherCondition } from '../models/WeatherCondition'
import { CurrentWeather, DailyForecast, LocationInfo, WeatherData } from '../models/WeatherData';
import { secureRandomNumber } from '../utils/SecureRandomUtil';
import { WeatherConstants, WeatherUtils } from '../utils/WeatherConstants';

interface WeatherConditionProbability {
  condition: WeatherCondition;
  probability: number;
}

export class SimpleWeatherDataService {
  private static instance: SimpleWeatherDataService;
  private currentLocation: LocationInfo;
  private weatherData: WeatherData;

  private constructor() {
    this.currentLocation = WeatherUtils.randomFromArray(WeatherConstants.MOCK_LOCATIONS);
    this.weatherData = this.generateWeatherData();
  }

  static getInstance(): SimpleWeatherDataService {
    if (!SimpleWeatherDataService.instance) {
      SimpleWeatherDataService.instance = new SimpleWeatherDataService();
    }
    return SimpleWeatherDataService.instance;
  }

  async getCurrentWeatherData(): Promise<WeatherData> {
    return this.weatherData;
  }

  async refreshWeatherData(): Promise<WeatherData> {
    this.weatherData = this.generateWeatherData();
    return this.weatherData;
  }

  setLocation(location: LocationInfo): void {
    this.currentLocation = location;
    this.weatherData = this.generateWeatherData();
  }

  getAvailableLocations(): LocationInfo[] {
    const result: LocationInfo[] = [];
    for (let i = 0; i < WeatherConstants.MOCK_LOCATIONS.length; i++) {
      result.push(WeatherConstants.MOCK_LOCATIONS[i]);
    }
    return result;
  }

  private generateWeatherData(): WeatherData {
    const current = this.generateCurrentWeather();
    const forecast = this.generateForecast();

    return {
      current,
      forecast,
      location: this.currentLocation,
      lastUpdated: Date.now(),
    }
  }

  private generateCurrentWeather(): CurrentWeather {
    const now = new Date();
    const month = now.getMonth();
    const timeOfDay = WeatherUtils.getTimeOfDay();
    const baseTemp: number = WeatherConstants.SEASONAL_TEMPS[month] as number;

    //random temp generation
    const dailyVariation = Math.sin((timeOfDay / 24) * 2 * Math.PI) * 10;
    const randomVariation = WeatherUtils.randomInRange(-5, 5);
    const temperature = Math.round(baseTemp + dailyVariation + randomVariation);

    //weather condition generation
    const season = WeatherUtils.getCurrentSeason(month);
    const condition = this.generateWeatherCondition(temperature, season);

    //other stuff generation
    const humidity = this.generateHumidity(condition);
    const windSpeed = this.generateWindSpeed(condition);
    const uvIndex = this.generateUvIndex(condition, timeOfDay);
    const feelsLike = this.calculateFeelsLike(temperature, humidity, windSpeed);

    return {
      condition,
      temperature,
      humidity,
      feelsLike,
      windSpeed,
      uvIndex,
    };
  }

  private generateWeatherCondition(temperature: number, season: string): WeatherCondition {
    let seasonalConditions: WeatherConditionProbability[] = [];

    if (season === 'winter') {
      seasonalConditions = WeatherConstants.SEASONAL_CONDITIONS.winter;
    } else if (season === 'spring') {
      seasonalConditions = WeatherConstants.SEASONAL_CONDITIONS.spring;
    } else if (season === 'summer') {
      seasonalConditions = WeatherConstants.SEASONAL_CONDITIONS.summer;
    } else if (season === 'fall') {
      seasonalConditions = WeatherConstants.SEASONAL_CONDITIONS.fall;
    } else {
      seasonalConditions = WeatherConstants.SEASONAL_CONDITIONS.summer; //Default
    }

    let adjustedConditions: WeatherConditionProbability[] = [];

    for (let i = 0; i < seasonalConditions.length; i++) {
      const newCondition: WeatherConditionProbability = {
        condition: seasonalConditions[i].condition,
        probability: seasonalConditions[i].probability,
      };
      adjustedConditions.push(newCondition);
    }

    if (temperature > 29) {
      for (let i = 0; i < adjustedConditions.length; i++) {
        if (adjustedConditions[i].condition === WeatherCondition.SUNNY) {
          adjustedConditions[i].probability *= 2;
        } else {
          adjustedConditions[i].probability *= 0.5;
        }
      }
    }

    if (temperature < 2) {
      for (let i = 0; i < adjustedConditions.length; i++) {
        if (adjustedConditions[i].condition === WeatherCondition.SNOWY ||
          adjustedConditions[i].condition === WeatherCondition.CLOUDY) {
          adjustedConditions[i].probability *= 1.5;
        } else {
          adjustedConditions[i].probability *= 0.7;
        }
      }
    }

    const totalProbability = adjustedConditions
      .reduce((sum: number, item: WeatherConditionProbability) => sum + item.probability, 0);
    const random = secureRandomNumber() * totalProbability;
    let currentSum = 0;
    for (const item of adjustedConditions) {
      currentSum += item.probability;
      if (random <= currentSum) {
        return item.condition;
      }
    }

    return WeatherCondition.PARTY_CLOUDY; //Default failsafe
  }

  private generateHumidity(condition: WeatherCondition): number {
    switch (condition) {
      case WeatherCondition.RAINY:
      case WeatherCondition.STORMY:
        return Math.round(WeatherUtils.randomInRange(70, 95));
      case WeatherCondition.FOGGY:
        return Math.round(WeatherUtils.randomInRange(85, 100));
      case WeatherCondition.SUNNY:
        return Math.round(WeatherUtils.randomInRange(30, 60));
      default:
        return Math.round(WeatherUtils.randomInRange(40, 80));
    }
  }

  private generateWindSpeed(condition: WeatherCondition): number {
    switch (condition) {
      case WeatherCondition.STORMY:
        return Math.round(WeatherUtils.randomInRange(20, 40));
      case WeatherCondition.RAINY:
        return Math.round(WeatherUtils.randomInRange(10, 25));
      case WeatherCondition.SUNNY:
        return Math.round(WeatherUtils.randomInRange(3, 12));
      default:
        return Math.round(WeatherUtils.randomInRange(5, 15));
    }
  }

  private generateUvIndex(condition: WeatherCondition, timeOfDay: number): number {
    const timeMultiplier = Math.max(0, Math.sin((timeOfDay - 6) / 12 * Math.PI));
    let baseUv = 5;
    switch (condition) {
      case WeatherCondition.SUNNY:
        baseUv = 8;
        break;
      case WeatherCondition.PARTY_CLOUDY:
        baseUv = 6;
        break;
      case WeatherCondition.CLOUDY:
      case WeatherCondition.RAINY:
      case WeatherCondition.STORMY:
        baseUv = 3;
      default:
        baseUv = 5;
        break;
    }
    return Math.round(baseUv * timeMultiplier);
  }

  private calculateFeelsLike(temperature: number, humidity: number, windSpeed: number): number {
    if (temperature >= 27) {
      const heatIndex = temperature + (humidity / 100) * 5;
      return Math.round(heatIndex);
    }
    if (temperature <= 10 && windSpeed > 5) {
      const windChill = temperature - (windSpeed * 4);
      return Math.round(windChill);
    }
    return temperature;
  }

  private generateForecast(): DailyForecast[] {
    const forecast: DailyForecast[] = [];
    const currentMonth = new Date().getMonth();
    const season = WeatherUtils.getCurrentSeason(currentMonth);

    for (let i = 0; i < WeatherConstants.FORECAST_DAYS; i++) {
      const baseTemp: number = WeatherConstants.SEASONAL_TEMPS[currentMonth] as number;

      //daily randomness
      const variation = WeatherUtils.randomInRange(-4, 4);
      const dayHigh = Math.round(baseTemp + variation + WeatherUtils.randomInRange(3, 8));
      const dayLow = Math.round(dayHigh - WeatherUtils.randomInRange(6, 12));

      const condition = this.generateWeatherCondition(dayHigh, season);
      const precipitationChance = this.getPrecipitationChance(condition);

      const dailyForecast: DailyForecast = {
        date: WeatherUtils.getDateString(i),
        high: dayHigh,
        low: dayLow,
        condition,
        precipitationChance: precipitationChance,
      };
      forecast.push(dailyForecast);
    }
    return forecast;
  }

  private getPrecipitationChance(condition: WeatherCondition): number {
    switch (condition) {
      case WeatherCondition.RAINY:
        return Math.round(WeatherUtils.randomInRange(60, 90));
      case WeatherCondition.STORMY:
        return Math.round(WeatherUtils.randomInRange(80, 100));
      case WeatherCondition.SNOWY:
        return Math.round(WeatherUtils.randomInRange(70, 95));
      case WeatherCondition.CLOUDY:
        return Math.round(WeatherUtils.randomInRange(20, 40));
      case WeatherCondition.PARTY_CLOUDY:
        return Math.round(WeatherUtils.randomInRange(10, 30));
      case WeatherCondition.SUNNY:
        return Math.round(WeatherUtils.randomInRange(0, 15));
      default:
        return Math.round(WeatherUtils.randomInRange(0, 15));
    }
  }
}