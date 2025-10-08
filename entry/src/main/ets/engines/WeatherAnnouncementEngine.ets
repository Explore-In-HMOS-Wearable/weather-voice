import { getWeatherConditionDisplayName, WeatherCondition } from '../models/WeatherCondition';
import { CurrentWeather, WeatherData } from '../models/WeatherData';
import { secureRandomNumber } from '../utils/SecureRandomUtil';

export class WeatherAnnouncementEngine {
  private greetingGenerator: GreetingGenerator;
  private weatherDescriptor: WeatherDescriptor;
  private temperatureAnnouncer: TemperatureAnnouncer;
  private contextEnhancer: ContextEnhancer;

  constructor() {
    this.greetingGenerator = new GreetingGenerator();
    this.weatherDescriptor = new WeatherDescriptor();
    this.temperatureAnnouncer = new TemperatureAnnouncer();
    this.contextEnhancer = new ContextEnhancer();
  }

  generateAnnouncement(weatherData: WeatherData): string {
    const greeting = this.greetingGenerator.getTimeBasedGreeting();
    const weatherDescription = this.weatherDescriptor.describe(weatherData.current);
    const temperatureInfo = this.temperatureAnnouncer.announce(
      weatherData.current.temperature,
      weatherData.current.feelsLike,
    );
    const contextInfo = this.contextEnhancer.addContext(weatherData);

    return `${greeting} ${weatherDescription} ${temperatureInfo} ${contextInfo}`.trim();
  }

  generateQuickSummary(weatherData: WeatherData): string {
    const condition = getWeatherConditionDisplayName(weatherData.current.condition);
    const temp = Math.round(weatherData.current.temperature);

    return `${condition} and ${temp} degrees.`;
  }

  generateCurrentConditions(current: CurrentWeather): string {
    const weatherDescription = this.weatherDescriptor.describe(current);
    const temperatureInfo =this.temperatureAnnouncer.announce(current.temperature, current.feelsLike);

    return `${weatherDescription} ${temperatureInfo}`.trim();
  }

  generateForecastAnnouncement(weatherData: WeatherData): string {
    if(!weatherData.forecast || weatherData.forecast.length === 0) {
      return 'No forecast available';
    }
    const tomorrow = weatherData.forecast[0];
    const condition = getWeatherConditionDisplayName(tomorrow.condition);
    let announcement = `Tomorrow ${condition}`;
    announcement += `High of ${Math.round(tomorrow.high)} degress, `;
    announcement += `low of ${Math.round(tomorrow.low)} degress.`;

    if(tomorrow.precipitationChance > 30) {
      announcement += ` ${tomorrow.precipitationChance}% chance of precipitation.`;
    }

    return announcement;
  }
}

class GreetingGenerator {
  private readonly morningGreetings = [
    'Good Morning!',
    'Morning!',
    'Hello There!',
    'Good day to you!',
    'Rise and Shine!',
  ];
  private readonly afternoonGreetings = [
    'Good Afternoon!',
    'Afternoon!',
    'Hello!',
    'Good day!',
    'How\'s your day going?',
  ];
  private readonly eveningGreetings = [
    'Good Evening!',
    'Evening!',
    'Hope you had a good day!',
    'Hello there!',
    'End of day weather check!',
  ];

  getTimeBasedGreeting(): string {
    const hour = new Date().getHours();
    if(hour >= 5 && hour < 12) {
      return this.getRandomFromArray(this.morningGreetings);
    } else if(hour >= 12 && hour < 18) {
      return this.getRandomFromArray(this.afternoonGreetings);
    } else {
      return this.getRandomFromArray(this.eveningGreetings);
    }
  }

  private getRandomFromArray(array: string[]) : string {
    return array[Math.floor(secureRandomNumber() * array.length)];
  }
}

class WeatherDescriptor {
  private readonly conditionDescriptions = new Map<WeatherCondition, string[]>([
    [WeatherCondition.SUNNY, [
      'It\'s bright and sunny.',
      'Beautiful sunny weather today.',
      'Sunshine all around!',
      'Perfect sunny conditions.',
    ]],
    [WeatherCondition.PARTY_CLOUDY, [
      'Partly cloudy skies today.',
      'Mix of sun and clouds.',
      'Some clouds, but still nice.',
      'Partly cloudy conditions.',
    ]],
    [WeatherCondition.CLOUDY, [
      'It\'s cloudy outside.',
      'Overcast skies today.',
      'Gray skies overhead.',
      'Cloudy conditions.',
    ]],
    [WeatherCondition.RAINY, [
      'Rain is in the forecast.',
      'It\'s raining outside.',
      'Rainy weather ahead.',
      'Wet conditions today.',
    ]],
    [WeatherCondition.STORMY, [
      'Storms are expected.',
      'Thunderstorms in the area.',
      'Stormy skies ahead.',
      'Stormy weather conditions.',
    ]],
    [WeatherCondition.SNOWY, [
      'Snow is falling.',
      'Snowy conditions outside.',
      'Winter weather alert.',
      'Snow in the forecast.',
    ]],
    [WeatherCondition.FOGGY, [
      'Rain is in the forecast.',
      'It\'s raining outside.',
      'Rainy weather ahead.',
      'Wet conditions today.',
    ]],
  ]);

  describe(current: CurrentWeather): string {
    const descriptions = this.conditionDescriptions.get(current.condition);
    if(!descriptions || descriptions.length === 0) {
      return `${getWeatherConditionDisplayName(current.condition)} conditions.`;
    }
    return descriptions[Math.floor(secureRandomNumber() * descriptions.length)];
  }
}

class TemperatureAnnouncer {
  announce(temperature: number, feelsLike?: number) : string {
    const temp = Math.round(temperature);
    let announcement = `${temp} degrees`;

    if (feelsLike && Math.abs(feelsLike - temperature) >= 3) {
      const feels = Math.round(feelsLike);
      if(feels > temperature) {
        announcement += ` but feels like ${feels}`;
      } else {
        announcement += ` but feels cooler at ${feels}`;
      }
    }

    if (temp >= 30) {
      announcement += ' and quite hot.';
    } else if (temp >= 25) {
      announcement += ' and warm.';
    } else if (temp >= 15) {
      announcement += ' and comfortable.';
    } else if (temp >= 5) {
      announcement += ' and cool.';
    } else if (temp >= -5) {
      announcement += ' and cold.';
    } else {
      announcement += ' and very cold.';
    }

    return announcement;
  }
}

class ContextEnhancer {
  addContext(weatherData: WeatherData): string {
    const current = weatherData.current;
    const contextParts: string[] = [];

    if(current.uvIndex >= 6) {
      contextParts.push('High UV levels today.');
    }

    if(current.humidity >= 80) {
      contextParts.push('Its quite humid.');
    } else if(current.humidity <= 25) {
      contextParts.push('Low humidity, stay hydrated.');
    }

    if(current.windSpeed >= 30) {
      contextParts.push('Very windy conditions.');
    } else if(current.windSpeed >= 15) {
      contextParts.push('Breezy outside.');
    }

    const activitySuggestion = this.getActivitySuggestion(current);
    if(activitySuggestion) {
      contextParts.push(activitySuggestion);
    }

    return contextParts.join(' ');
  }

  private getActivitySuggestion(current: CurrentWeather): string {
    const temp = current.temperature;
    const condition = current.condition;

    if(condition === WeatherCondition.SUNNY && temp >= 20 && temp <= 28) {
      return 'Perfect day for outdoor activities.';
    } else if(condition === WeatherCondition.RAINY) {
      return 'Great day to stay cozy indoors.';
    } else if(temp >= 30) {
      return 'Seek shade and stay hydrated.';
    } else if(temp <= 0) {
      return 'Bundle up if heading outside.';
    } else if(condition === WeatherCondition.PARTY_CLOUDY && temp >= 15) {
      return 'Good day to get some fresh air.';
    }

    return '';
  }
}